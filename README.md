# Ticket Warehouse

A serverless data lake for warehousing Ticketsauce API data and analyzing it.

Leverages AWS Lambda and Glue for ETL, AWS Athena for querying the data, and Quicksight for BI.  Also uses Lambda functions to generate and schedule custom reports.

Uses AWS CDK/CloudFormation for IaC.

## Setup

### Step 1: Set up Quicksight in the AWS account.

You might want to connect this to Active Directory for SSO or something for user management, but it needs to be done separately and manually.

### Step 2: Use CDK/CloudFormation to create the serverles resources

    `cdk bootstrap`
    `cdk deploy`


### Step 3: Use the CLI management script to create Quicksight analyses

Quicksight data sources, data sets and analyses must be set up using the management script.

## Management

You can use the `manager.rb` CLI tool to manage the data lake:

    bundle exec ruby manager.rb help

### Manually run ETL on any given time range

    bundle exec ruby manager.rb etl --time-range=current
    bundle exec ruby manager.rb etl --time-range=upcoming
    bundle exec ruby manager.rb etl --time-range=all

### Reset whole data lake

This will re-run ETL, then remove the Athena tables, then re-run the Glue crawler to recreate the Athena tables:

    bundle exec ruby manager.rb reset

### Run Glue crawlers

    bundle exec ruby manager.rb crawl