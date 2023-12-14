# Ticket Warehouse CDK Application

This repository contains the AWS CDK (Cloud Development Kit) application for managing the Ticket Warehouse infrastructure, which includes pipeline and application stacks for multiple environments: staging, production, and development.

## Overview

The CDK application is structured into two main types of stacks:

1. **Pipeline Stacks:** These stacks define the CI/CD pipelines that orchestrate the deployment process for the Ticket Warehouse application across different AWS accounts and environments.
2. **Application Stacks:** These stacks contain the actual AWS resources (like Lambda functions, DynamoDB tables, etc.) that make up the Ticket Warehouse application.

## Accounts

- **Deploy Account:** - Used for orchestrating deployments.
- **Staging Account:** - Staging environment resources.
- **Production Account:** - Production environment resources.
- **Development Account:** - Development environment resources.

## Stacks

### Pipeline Stacks

- `ticket-warehouse-pipeline-staging`
- `ticket-warehouse-pipeline-production`
- `ticket-warehouse-pipeline-development`

These stacks set up the CI/CD pipeline which automates the deployment process. They typically only need to be deployed once.

### Application Stacks

- `ticket-warehouse-pipeline-staging/staging/ticket-warehouse`
- `ticket-warehouse-pipeline-production/production/ticket-warehouse`
- `ticket-warehouse-pipeline-development/development/ticket-warehouse`

These stacks contain the resources that constitute the Ticket Warehouse application for their respective environments.

## Prerequisites

Before deploying any stack, you must have:

- AWS CLI installed and configured.
- AWS CDK installed.
- Proper IAM permissions to create and manage the required AWS resources.

## Deployment Instructions

To deploy any of these stacks, you need the appropriate credentials. You can configure these credentials in the AWS CLI or pass them at deployment time using the `--profile` flag.

### Deploying Application Stacks

For example, to deploy the development application stack, make sure you have the development account credentials set up, then run:

```
cdk deploy ticket-warehouse-pipeline-development/development/ticket-warehouse
```

Alternatively, if you're using named profiles for AWS CLI, you can deploy using the profile flag:

```
cdk deploy ticket-warehouse-pipeline-development/development/ticket-warehouse --profile development-profile
```

### Deploying Pipeline Stacks

To deploy the development pipeline stack, you would need the Deploy account credentials. Once set, run:

```
cdk deploy ticket-warehouse-pipeline-development
```

Or with the profile flag:

```
cdk deploy ticket-warehouse-pipeline-development --profile deploy-account-profile
```