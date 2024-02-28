#!/bin/bash

set -e

NL=$'\n'

eval $(azd env get-values)

msg() {
	echo ">>> $*" >&2
}

confirm() {
	read -p ">>> Continue? [y/N] " -n 1 -r >&2
	echo >&2
	case "$REPLY" in
		[yY]) return
	esac
	exit 1
}

show_job() {
	msg "Visit the following URL to monitor the job:${NL}https://portal.azure.com/#@${AZURE_TENANT_ID}/resource/subscriptions/${AZURE_SUBSCRIPTION_ID}/resourceGroups/${AZURE_RESOURCE_GROUP_NAME}/providers/Microsoft.App/jobs/${AZURE_CONTAINER_APPS_JOB_NAME}/executionHistory$NL"
	msg "Run the following command to show the job:${NL}az containerapp job execution show --subscription ${AZURE_SUBSCRIPTION_ID} -g ${AZURE_RESOURCE_GROUP_NAME} -n ${AZURE_CONTAINER_APPS_JOB_NAME} --job-execution-name ${1}$NL"
	msg "Run the following command to show the logs:${NL}az monitor log-analytics query --subscription ${AZURE_SUBSCRIPTION_ID} --workspace ${AZURE_LOG_ANALYTICS_WORKSPACE_CUSTOMER_ID} --analytics-query 'ContainerAppConsoleLogs_CL | where ContainerGroupName_s startswith \"$1\"' --query [].Log_s -o tsv$NL"
}

start_job() {
	msg 'Starting the job...'
	JOB_NAME=$(az containerapp job show -g $AZURE_RESOURCE_GROUP_NAME -n $AZURE_CONTAINER_APPS_JOB_NAME --query properties.template |
		jq --arg s "$1" '.containers[0].command = ["/bin/bash", "-e", "-c", $s]' |
		az containerapp job start -g $AZURE_RESOURCE_GROUP_NAME -n $AZURE_CONTAINER_APPS_JOB_NAME --yaml /dev/stdin --query name -o tsv)
	show_job $JOB_NAME
}

run_run() {
	if test $# -eq 0; then
		msg 'Reading script from stdin...'
		read -r -d '' SCRIPT
	else
		msg 'Reading script from arguments...'
		SCRIPT="$*"
	fi
	start_job "$SCRIPT"
}

run_dbinit() {
	SHARED_STORAGE_ACCOUNT_NAME=$(az group show -g $SHARED_RESOURCE_GROUP_NAME --query tags.STORAGE_ACCOUNT_NAME -o tsv)
	EXPIRY=$(date -u -d '5 minutes' '+%Y-%m-%dT%H:%MZ')
	SAS=$(az storage container generate-sas --account-name $SHARED_STORAGE_ACCOUNT_NAME --name secrets --permissions r --expiry $EXPIRY --https-only --output tsv)
	URL="https://${SHARED_STORAGE_ACCOUNT_NAME}.blob.core.windows.net/secrets"

	read -r -d '' SCRIPT <<-'EOF' || true
	DB_ADMIN_USER=$(curl -s "$URL/DB_ADMIN_USER?$SAS")
	DB_ADMIN_PASS=$(curl -s "$URL/DB_ADMIN_PASS?$SAS")
	rmops dbinit "$DB_ADMIN_USER" "$DB_ADMIN_PASS"
	tail -1 /home/site/wwwroot/etc/password.txt
	EOF

	msg 'Starting the job...'
	JOB_NAME=$(az containerapp job show -g $AZURE_RESOURCE_GROUP_NAME -n $AZURE_CONTAINER_APPS_JOB_NAME --query properties.template |
		jq --arg s "$SCRIPT" '.containers[0].command = ["/bin/bash", "-e", "-c", $s]' |
		jq --arg n URL --arg v "$URL" '.containers[0].env += [{"name": $n, "value": $v}]' |
		jq --arg n SAS --arg v "$SAS" '.containers[0].env += [{"name": $n, "value": $v}]' |
		az containerapp job start -g $AZURE_RESOURCE_GROUP_NAME -n $AZURE_CONTAINER_APPS_JOB_NAME --yaml /dev/stdin --query name -o tsv)
	show_job $JOB_NAME
}

run_setup() {
	read -r -d '' SCRIPT <<-EOF || true
	rmops setup
	tail -1 /home/site/wwwroot/etc/password.txt
	EOF
	start_job "$SCRIPT"
}

run_passwd() {
	if test "$1" = ''; then
		msg 'Specify login to reset password for'
		exit 1
	fi
	read -r -d '' SCRIPT <<-EOF || true
	rmops passwd $1
	tail -1 /home/site/wwwroot/etc/password.txt
	EOF
	start_job "$SCRIPT"
}

run_restart() {
	rev=$(az containerapp show -g $AZURE_RESOURCE_GROUP_NAME -n $AZURE_CONTAINER_APPS_APP_NAME --query properties.latestRevisionName -o tsv)
	msg "Restarting revision $rev..."
	az containerapp revision restart -g $AZURE_RESOURCE_GROUP_NAME -n $AZURE_CONTAINER_APPS_APP_NAME --revision $rev -o tsv
}

run_logs() {
	msg 'Following logs...'
	az containerapp logs show -g $AZURE_RESOURCE_GROUP_NAME -n $AZURE_CONTAINER_APPS_APP_NAME --format text --follow
}

run_portal() {
	msg 'Opening Azure Portal'
	URL="https://portal.azure.com/#@${AZURE_TENANT_ID}/resource/subscriptions/${AZURE_SUBSCRIPTION_ID}/resourceGroups/${AZURE_RESOURCE_GROUP_NAME}/providers/Microsoft.App/containerApps/${AZURE_CONTAINER_APPS_APP_NAME}"
	xdg-open "$URL"
}

run_open() {
	msg 'Running Azure CLI...'
	URL="https://$(az containerapp show -g $AZURE_RESOURCE_GROUP_NAME -n $AZURE_CONTAINER_APPS_APP_NAME --query properties.configuration.ingress.fqdn -o tsv)${APP_ROOT_PATH}"
	msg "Opening $URL"
	xdg-open "$URL"
}

run_show() {
	msg 'Running Azure CLI...'
	az containerapp show -g $AZURE_RESOURCE_GROUP_NAME -n $AZURE_CONTAINER_APPS_APP_NAME
}

run_update_auth() {
	msg 'Running Azure CLI...'
	MS_CLIENT_ID=$(az containerapp auth microsoft show -g $AZURE_RESOURCE_GROUP_NAME -n $AZURE_CONTAINER_APPS_APP_NAME --query registration.clientId -o tsv)
	FQDN=$(az containerapp show -g $AZURE_RESOURCE_GROUP_NAME -n $AZURE_CONTAINER_APPS_APP_NAME --query properties.configuration.ingress.fqdn -o tsv)
	URI="https://${FQDN}/.auth/login/aad/callback"
	URIS=$(az ad app show --id $MS_CLIENT_ID --query web.redirectUris -o tsv)
	URIS=$(echo "${URI}${NL}${URIS}" | sort | uniq)
	msg "App Client ID:     ${MS_CLIENT_ID}"
	msg "App Redirect URI:  ${URI}"
	msg "Azure Portal link: https://portal.azure.com/#@${AZURE_TENANT_ID}/view/Microsoft_AAD_RegisteredApps/ApplicationMenuBlade/~/Authentication/appId/${MS_CLIENT_ID}"
	msg "Updating new Redirect URIs:${NL}${URIS}"
	confirm
	az ad app update --id $MS_CLIENT_ID --web-redirect-uris ${URIS}
	msg 'Done'
}

run_update_image() {
	msg 'Running Azure CLI...'
	CONTAINER_REGISTRY_IMAGE=$(az group show -g $SHARED_RESOURCE_GROUP_NAME --query tags.CONTAINER_REGISTRY_IMAGE -o tsv)
	CONTAINER_REGISTRY_TAG=$(az group show -g $SHARED_RESOURCE_GROUP_NAME --query tags.CONTAINER_REGISTRY_TAG -o tsv)
	IMAGE="${CONTAINER_REGISTRY_IMAGE}:${CONTAINER_REGISTRY_TAG}"
	msg "Updating new container image: $IMAGE"
	confirm
	rev=$(az containerapp show -g $AZURE_RESOURCE_GROUP_NAME -n $AZURE_CONTAINER_APPS_APP_NAME |
		jq --arg i "$IMAGE" '.properties.template.containers |= map(if .name == "redmine" or .name == "sidekiq" then .image = $i else . end)' |
		az containerapp update -g $AZURE_RESOURCE_GROUP_NAME -n $AZURE_CONTAINER_APPS_APP_NAME --yaml /dev/stdin --query properties.latestRevisionName -o tsv)
	msg 'Done'
}

case "$1" in
	run)
		shift
		run_run "$@"
		;;
	dbinit)
		shift
		run_dbinit "$@"
		;;
	setup)
		shift
		run_setup "$@"
		;;
	passwd)
		shift
		run_passwd "$@"
		;;
	restart)
		shift
		run_restart "$@"
		;;
	logs)
		shift
		run_logs "$@"
		;;
	portal)
		shift
		run_portal "$@"
		;;
	open)
		shift
		run_open "$@"
		;;
	show)
		shift
		run_show "$@"
		;;
	update-auth|auth)
		shift
		run_update_auth "$@"
		;;
	update-image)
		shift
		run_update_image "$@"
		;;
	*)
		msg "Usage:"
		msg "$0 run [script]"
		msg "$0 dbinit"
		msg "$0 setup"
		msg "$0 passwd <login>"
		msg "$0 restart"
		msg "$0 logs"
		msg "$0 portal"
		msg "$0 open"
		msg "$0 show"
		msg "$0 update-auth"
		msg "$0 update-image"
		exit 1
		;;
esac
