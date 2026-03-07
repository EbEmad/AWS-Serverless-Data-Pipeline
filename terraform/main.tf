terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}


# AWS Provider configured to point to LocalStack
provider "aws" {
  region                      = "us-east-1"
  access_key                  = "test"
  secret_key                  = "test"

  # Skip real AWS validations —> we're using LocalStack
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true
  s3_use_path_style           = true

  # All AWS services point to LocalStack 
  endpoints {
    s3             = "http://localhost:4566"
    lambda         = "http://localhost:4566"
    stepfunctions  = "http://localhost:4566"
    kinesis        = "http://localhost:4566"
    firehose       = "http://localhost:4566"
    es             = "http://localhost:4566"
    redshift       = "http://localhost:4566"
    dynamodb       = "http://localhost:4566"
    cloudwatch     = "http://localhost:4566"
    sns            = "http://localhost:4566"
    sqs            = "http://localhost:4566"
    iam            = "http://localhost:4566"
    logs           = "http://localhost:4566"
    events         = "http://localhost:4566"
    scheduler      = "http://localhost:4566"
    sts            = "http://localhost:4566"
  }
}


# Local variables reused across all resources
locals {
  project     = "aws-data-pipeline"
  region      = "us-east-1"
  account_id  = "000000000000"   # LocalStack default account ID
  environment = "local"
}
