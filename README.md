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

The tool supports these basic actions:

* purge - Delete everything in the S3 bucket and delete the Athena tables.
* load - Load data from Ticketsauce to S3.
* crawl - Crawl S3 data and create Athena tables.
* reset - Purge, load, crawl.

### Manually load data for any given time range

    bundle exec ruby manager.rb load --time-range=current
    bundle exec ruby manager.rb load --time-range=upcoming
    bundle exec ruby manager.rb load --time-range=all

### Run Glue crawlers

    bundle exec ruby manager.rb crawl

### Purge whole data lake

Delete the contents of the S3 bucket and remove all derived Athena tables for this environment:

    bundle exec ruby manager.rb purge

### Reset whole data lake

This will purge, then load, then crawl:

    bundle exec ruby manager.rb reset