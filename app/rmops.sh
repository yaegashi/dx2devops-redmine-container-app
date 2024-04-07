#!/bin/bash

set -e

NL=$'\n'
QUIET=0

eval $(azd env get-values)

msg() {
	echo ">>> $*" >&2
}

confirm() {
	case "$QUIET" in
		1) return
	esac
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

cmd_run() {
	if test $# -eq 0; then
		msg 'Reading script from stdin...'
		read -r -d '' SCRIPT
	else
		msg 'Reading script from arguments...'
		SCRIPT="$*"
	fi
	confirm
	start_job "$SCRIPT"
}

cmd_rmops_dbinit() {
	msg 'Running Azure CLI...'
	SHARED_STORAGE_ACCOUNT_NAME=$(az group show -g $SHARED_RESOURCE_GROUP_NAME --query tags.STORAGE_ACCOUNT_NAME -o tsv)
	EXPIRY=$(date -u -d '5 minutes' '+%Y-%m-%dT%H:%MZ')
	SAS=$(az storage container generate-sas --only-show-errors --account-name $SHARED_STORAGE_ACCOUNT_NAME --name secrets --permissions r --expiry $EXPIRY --https-only --output tsv)
	URL="https://${SHARED_STORAGE_ACCOUNT_NAME}.blob.core.windows.net/secrets"

	read -r -d '' SCRIPT <<-'EOF' || true
	DB_ADMIN_USER=$(curl -s "$URL/DB_ADMIN_USER?$SAS")
	DB_ADMIN_PASS=$(curl -s "$URL/DB_ADMIN_PASS?$SAS")
	rmops dbinit "$DB_ADMIN_USER" "$DB_ADMIN_PASS"
	EOF

	msg 'Running rmops dbinit'
	confirm	

	msg 'Starting the job...'
	JOB_NAME=$(az containerapp job show -g $AZURE_RESOURCE_GROUP_NAME -n $AZURE_CONTAINER_APPS_JOB_NAME --query properties.template |
		jq --arg s "$SCRIPT" '.containers[0].command = ["/bin/bash", "-e", "-c", $s]' |
		jq --arg n URL --arg v "$URL" '.containers[0].env += [{"name": $n, "value": $v}]' |
		jq --arg n SAS --arg v "$SAS" '.containers[0].env += [{"name": $n, "value": $v}]' |
		az containerapp job start -g $AZURE_RESOURCE_GROUP_NAME -n $AZURE_CONTAINER_APPS_JOB_NAME --yaml /dev/stdin --query name -o tsv)
	show_job $JOB_NAME
}

cmd_rmops_setup() {
	read -r -d '' SCRIPT <<-EOF || true
	rmops setup
	tail -1 /home/site/wwwroot/etc/password.txt
	EOF
	msg 'Running rmops setup'
	confirm
	start_job "$SCRIPT"
}

cmd_rmops_passwd() {
	if test "$1" = ''; then
		msg 'Specify login to reset password for'
		exit 1
	fi
	read -r -d '' SCRIPT <<-EOF || true
	rmops passwd $1
	tail -1 /home/site/wwwroot/etc/password.txt
	EOF
	msg "Resetting password for $1"
	confirm
	start_job "$SCRIPT"
}

cmd_update_auth() {
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

cmd_update_image() {
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

cmd_download() {
	msg 'Running Azure CLI...'
	az storage file download --only-show-errors --account-name $AZURE_STORAGE_ACCOUNT_NAME -s data -p "$1" >/dev/null
}

cmd_show() {
	msg 'Running Azure CLI...'
	az containerapp show -g $AZURE_RESOURCE_GROUP_NAME -n $AZURE_CONTAINER_APPS_APP_NAME
}

cmd_logs() {
	msg 'Following logs...'
	az containerapp logs show -g $AZURE_RESOURCE_GROUP_NAME -n $AZURE_CONTAINER_APPS_APP_NAME --format text --follow
}

cmd_restart() {
	rev=$(az containerapp show -g $AZURE_RESOURCE_GROUP_NAME -n $AZURE_CONTAINER_APPS_APP_NAME --query properties.latestRevisionName -o tsv)
	msg "Restarting revision $rev..."
	confirm
	az containerapp revision restart -g $AZURE_RESOURCE_GROUP_NAME -n $AZURE_CONTAINER_APPS_APP_NAME --revision $rev -o tsv
}

cmd_portal() {
	msg 'Opening Azure Portal'
	URL="https://portal.azure.com/#@${AZURE_TENANT_ID}/resource/subscriptions/${AZURE_SUBSCRIPTION_ID}/resourceGroups/${AZURE_RESOURCE_GROUP_NAME}/providers/Microsoft.App/containerApps/${AZURE_CONTAINER_APPS_APP_NAME}"
	xdg-open "$URL"
}

cmd_open() {
	msg 'Running Azure CLI...'
	URL="https://$(az containerapp show -g $AZURE_RESOURCE_GROUP_NAME -n $AZURE_CONTAINER_APPS_APP_NAME --query properties.configuration.ingress.fqdn -o tsv)${APP_ROOT_PATH}"
	msg "Opening $URL"
	xdg-open "$URL"
}

case "$1" in
	--quiet|-q)
		shift
		QUIET=1
		;;
esac

case "$1" in
	run)
		shift
		cmd_run "$@"
		;;
	rmops-dbinit|setup)
		shift
		cmd_rmops_dbinit "$@"
		;;
	rmops-setup|setup)
		shift
		cmd_rmops_setup "$@"
		;;
	rmops-passwd|passwd)
		shift
		cmd_rmops_passwd "$@"
		;;
	update-auth|auth)
		shift
		cmd_update_auth "$@"
		;;
	update-image)
		shift
		cmd_update_image "$@"
		;;
	download)
		shift
		cmd_download "$@"
		;;
	show)
		shift
		cmd_show "$@"
		;;
	logs)
		shift
		cmd_logs "$@"
		;;
	restart)
		shift
		cmd_restart "$@"
		;;
	portal)
		shift
		cmd_portal "$@"
		;;
	open)
		shift
		cmd_open "$@"
		;;
	*)
		msg "Usage: $0 [-q|--quiet] <command> [args...]"
		msg "Commands:"
		msg "  run [script]         - Run script in container"
		msg "  rmops-dbinit         - Run rmops dbinit in container"
		msg "  rmops-setup          - Run rmops setup in container"
		msg "  rmops-passwd <login> - Run rmops passwd <login> in container"
		msg "  update-auth          - Update redirect URIs in ME-ID app"
		msg "  update-image         - Update container image"
		msg "  download             - Download file in data share"
		msg "  show                 - Show app with Azure CLI"
		msg "  logs                 - Show app logs with Azure CLI"
		msg "  restart              - Restart app's running revision"
		msg "  portal               - Open app in Azure Portal"
		msg "  open                 - Open app in browser"
		exit 1
		;;
esac
