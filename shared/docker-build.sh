#!/bin/bash

set -e

eval $(azd env get-values)

: ${REDMINE_REPOSITORY=https://github.com/redmica/redmica}
: ${REDMINE_REF=v2.4.1}

if ! test -d redmine/redmine; then
    git clone $REDMINE_REPOSITORY -b $REDMINE_REF redmine/redmine
fi

TAG=$(date --utc +%Y%m%dT%H%M%SZ)

az acr login --subscription ${AZURE_SUBSCRIPTION_ID} --name ${AZURE_CONTAINER_REGISTRY_NAME}

docker build redmine -t ${AZURE_CONTAINER_REGISTRY_IMAGE}:${TAG}

docker push ${AZURE_CONTAINER_REGISTRY_IMAGE}:${TAG}

az group update -n ${AZURE_RESOURCE_GROUP_NAME} --set tags.CONTAINER_REGISTRY_TAG=${TAG}

azd env set AZURE_CONTAINER_REGISTRY_TAG ${TAG}
