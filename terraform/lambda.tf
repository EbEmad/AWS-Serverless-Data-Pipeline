#  IAM — Role shared by both Lambda functions

resource "aws_iam_role" "lambda_exec" {
  name = "${local.project}-lambda-exec-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Name        = "${local.project}-lambda-exec-role"
    Environment = local.environment
  }
}

# Inline policy — grants everything both Lambdas need

resource "aws_iam_role_policy" "lambda_policy" {
  name = "${local.project}-lambda-policy"
  role = aws_iam_role.lambda_exec.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # CloudWatch Logs
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "arn:aws:logs:*:*:*"
      },
      # S3 — read raw bucket, write processed bucket
      {
        Effect = "Allow"
        Action = ["s3:GetObject", "s3:HeadObject"]
        Resource = "arn:aws:s3:::${local.project}-raw-data/*"
      },
      {
        Effect   = "Allow"
        Action   = ["s3:PutObject"]
        Resource = "arn:aws:s3:::${local.project}-processed-data/*"
      },
      # DynamoDB — tracking table
      {
        Effect   = "Allow"
        Action   = ["dynamodb:PutItem", "dynamodb:UpdateItem", "dynamodb:GetItem"]
        Resource = aws_dynamodb_table.pipeline_tracking.arn
      },
      # Kinesis — publish records
      {
        Effect   = "Allow"
        Action   = ["kinesis:PutRecord", "kinesis:PutRecords"]
        # Reference the stream once kinesis.tf exists; using a wildcard for now
        Resource = "arn:aws:kinesis:${local.region}:${local.account_id}:stream/${local.project}-stream"
      }
    ]
  })
}



#  Package Lambda source code into ZIP files


data "archive_file" "validator_zip" {
  type        = "zip"
  source_file = "${path.module}/../lambdas/validator/handler.py"
  output_path = "${path.module}/../lambdas/validator/validator.zip"
}

data "archive_file" "transformer_zip" {
  type        = "zip"
  source_file = "${path.module}/../lambdas/transformer/handler.py"
  output_path = "${path.module}/../lambdas/transformer/transformer.zip"
}


#  Lambda — Validator

resource "aws_lambda_function" "validator" {
  function_name    = "${local.project}-validator"
  filename         = data.archive_file.validator_zip.output_path
  source_code_hash = data.archive_file.validator_zip.output_base64sha256

  role    = aws_iam_role.lambda_exec.arn
  handler = "handler.lambda_handler"
  runtime = var.lambda_runtime

  memory_size = var.lambda_memory_size
  timeout     = var.lambda_timeout

  environment {
    variables = {
      TRACKING_TABLE   = aws_dynamodb_table.pipeline_tracking.name
      AWS_ENDPOINT_URL = var.lambda_endpoint_url
    }
  }

  tags = {
    Name        = "${local.project}-validator"
    Environment = local.environment
    Purpose     = "Validates incoming CSV files before processing"
  }
}



#  Lambda — Transformer

resource "aws_lambda_function" "transformer" {
  function_name    = "${local.project}-transformer"
  filename         = data.archive_file.transformer_zip.output_path
  source_code_hash = data.archive_file.transformer_zip.output_base64sha256

  role    = aws_iam_role.lambda_exec.arn
  handler = "handler.lambda_handler"
  runtime = var.lambda_runtime

  memory_size = var.lambda_memory_size
  timeout     = var.lambda_timeout

  environment {
    variables = {
      TRACKING_TABLE   = aws_dynamodb_table.pipeline_tracking.name
      PROCESSED_BUCKET = "${local.project}-processed-data"
      KINESIS_STREAM   = "${local.project}-stream"
      AWS_ENDPOINT_URL = var.lambda_endpoint_url
    }
  }

  tags = {
    Name        = "${local.project}-transformer"
    Environment = local.environment
    Purpose     = "Cleans, transforms and streams validated data"
  }
}


#  Outputs

output "validator_function_name" {
  description = "Name of the Validator Lambda function"
  value       = aws_lambda_function.validator.function_name
}

output "transformer_function_name" {
  description = "Name of the Transformer Lambda function"
  value       = aws_lambda_function.transformer.function_name
}
