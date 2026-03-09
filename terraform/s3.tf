# S3 Bucket: Raw Data (Landing Zone)

resource "aws_s3_bucket" "raw" {
  bucket = "${local.project}-raw-data"

  tags = {
    Name        = "${local.project}-raw-data"
    Environment = local.environment
    Purpose     = "Landing zone for incoming raw data"
  }
}


# Block all public access on the raw bucket
resource "aws_s3_bucket_public_access_block" "raw" {
  bucket = aws_s3_bucket.raw.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}


# Enable versioning so we never lose raw files
resource "aws_s3_bucket_versioning" "raw" {
  bucket = aws_s3_bucket.raw.id

  versioning_configuration {
    status = var.enable_s3_versioning ? "Enabled" : "Suspended"
  }
}



# S3 Bucket: Processed Data

resource "aws_s3_bucket" "processed" {
  bucket = "${local.project}-processed-data"

  tags = {
    Name        = "${local.project}-processed-data"
    Environment = local.environment
    Purpose     = "Stores cleaned and transformed data"
  }
}

# Block all public access on the processed bucket
resource "aws_s3_bucket_public_access_block" "processed" {
  bucket = aws_s3_bucket.processed.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Enable versioning on processed bucket
resource "aws_s3_bucket_versioning" "processed" {
  bucket = aws_s3_bucket.processed.id

  versioning_configuration {
    status = var.enable_s3_versioning ? "Enabled" : "Suspended"
  }
}


# S3 Event Notification
# Fires when a new file is uploaded to the Raw bucket
# Triggers the Step Functions State Machine via EventBridge

resource "aws_s3_bucket_notification" "raw_upload_trigger" {
  bucket      = aws_s3_bucket.raw.id
  eventbridge = true   # Send S3 events to EventBridge — Step Functions will pick them up
}



# Outputs — print bucket names after terraform apply
output "raw_bucket_name" {
  description = "Name of the raw data S3 bucket"
  value       = aws_s3_bucket.raw.bucket
}

output "processed_bucket_name" {
  description = "Name of the processed data S3 bucket"
  value       = aws_s3_bucket.processed.bucket
}
