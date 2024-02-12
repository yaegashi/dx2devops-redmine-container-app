# Redmine on Azure Container Apps

## Introduction

DX2 DevOps solution for [Redmine] or [RedMica] on [Azure Container Apps].

- containers
  - [redmine](containers/redmine) ... Redmine/RedMica container
- azd ([Azure Developer CLI])
  - [shared](azd/shared) ... Shared resources: Azure Database for MySQL/PostgreSQL (flexible server), Azure Container Registry, etc.
  - [app](azd/app) ... App resources: Azure Container App, Storage Account, etc.

[Redmine]: https://github.com/redmine/redmine
[RedMica]: https://github.com/redmica/redmica
[Azure Container Apps]: https://learn.microsoft.com/en-us/azure/container-apps/overview
[Azure Developer CLI]: https://learn.microsoft.com/en-us/azure/developer/azure-developer-cli/overview

## Architecture

### Solution overview

> ![](doc/assets/solution-diagram.png)

### Authentication overview

> ![](doc/assets/auth-diagram.png)
