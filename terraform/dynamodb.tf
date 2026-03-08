# Stores a record for every pipeline execution — file name, status, timestamps, record counts
resource "aws_dynamodb_table" "pipeline_tracking" {
  name         = "${local.project}-tracking"
  billing_mode = "PAY_PER_REQUEST" # No need to pre-provision capacity  scales automatically

  # Primary key->every pipeline run gets a unique ID
  hash_key = "run_id"

  attribute {
    name = "run_id"
    type = "S" # S = String
  }

  # Global Secondary Index-> lets you query by file name across all runs
  global_secondary_index {
    name            = "FileNameIndex"
    hash_key        = "file_name"
    projection_type = "ALL" # Include all attributes in the index
  }

  attribute {
    name = "file_name"
    type = "S"
  }

  tags = {
    Name        = "${local.project}-tracking"
    Environment = local.environment
    Purpose     = "Tracks every pipeline run — status, timestamps, record counts"
  }
}

# Output the table name so we can reference it in our Lambda Python code
output "tracking_table_name" {
  description = "Name of the DynamoDB pipeline tracking table"
  value       = aws_dynamodb_table.pipeline_tracking.name
}
