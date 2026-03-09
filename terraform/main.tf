terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    # Needed by lambda.tf to auto-zip the Lambda handler files
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.0"
    }
  }
}


# AWS Provider configured to point to LocalStack
provider "aws" {
  region                      = var.aws_region
  access_key                  = var.aws_access_key
  secret_key                  = var.aws_secret_key

  # Skip real AWS validations —> we're using LocalStack
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true
  s3_use_path_style           = true

  # All AWS services point to LocalStack 
  endpoints {
    s3             = var.localstack_endpoint
    lambda         = var.localstack_endpoint
    stepfunctions  = var.localstack_endpoint
    kinesis        = var.localstack_endpoint
    firehose       = var.localstack_endpoint
    es             = var.localstack_endpoint
    redshift       = var.localstack_endpoint
    dynamodb       = var.localstack_endpoint
    cloudwatch     = var.localstack_endpoint
    sns            = var.localstack_endpoint
    sqs            = var.localstack_endpoint
    iam            = var.localstack_endpoint
    logs           = var.localstack_endpoint
    events         = var.localstack_endpoint
    scheduler      = var.localstack_endpoint
    sts            = var.localstack_endpoint
  }
}


# Local variables — computed from input variables, reused across all resources
locals {
  project     = var.project
  region      = var.aws_region
  account_id  = var.aws_account_id
  environment = var.environment
}
