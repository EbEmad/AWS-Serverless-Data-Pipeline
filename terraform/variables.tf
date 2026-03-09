#  Input Variables — Centralized configuration for the pipeline

variable "project" {
  description = "Project name used as a prefix for all resource names"
  type        = string
  default     = "aws-data-pipeline"
}

variable "environment" {
  description = "Deployment environment (local, dev, staging, prod)"
  type        = string
  default     = "local"
}

# ---- AWS / LocalStack ---------------------------------------

variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "us-east-1"
}


variable "aws_access_key" {
  description = "AWS access key (use 'test' for LocalStack)"
  type        = string
  default     = "test"
  sensitive   = true
}

variable "aws_secret_key" {
  description = "AWS secret key (use 'test' for LocalStack)"
  type        = string
  default     = "test"
  sensitive   = true
}

variable "aws_account_id" {
  description = "AWS account ID (LocalStack default is 000000000000)"
  type        = string
  default     = "000000000000"
}

variable "localstack_endpoint" {
  description = "LocalStack gateway URL. Set to empty string when deploying to real AWS."
  type        = string
  default     = "http://localhost:4566"
}

variable "lambda_endpoint_url" {
  description = "Endpoint URL that Lambda containers use to reach LocalStack (host.docker.internal). Set to empty string for real AWS."
  type        = string
  default     = "http://host.docker.internal:4566"
}

# ---- Lambda -------------------------------------------------

variable "lambda_runtime" {
  description = "Python runtime version for Lambda functions"
  type        = string
  default     = "python3.9"
}

variable "lambda_memory_size" {
  description = "Memory (MB) allocated to each Lambda function"
  type        = number
  default     = 128
}

variable "lambda_timeout" {
  description = "Timeout (seconds) for each Lambda function"
  type        = number
  default     = 30
}

# ---- DynamoDB -----------------------------------------------

variable "dynamodb_billing_mode" {
  description = "DynamoDB billing mode (PAY_PER_REQUEST or PROVISIONED)"
  type        = string
  default     = "PAY_PER_REQUEST"
}

# ---- S3 ----------------------------------------------------

variable "enable_s3_versioning" {
  description = "Enable versioning on S3 buckets"
  type        = bool
  default     = true
}
