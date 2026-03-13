#  EventBridge — Automatically trigger the pipeline on a schedule

# IAM Role — allows EventBridge to start Step Functions executions
resource "aws_iam_role" "eventbridge_exec" {
  name = "${local.project}-eventbridge-exec-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "events.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Name        = "${local.project}-eventbridge-exec-role"
    Environment = local.environment
  }
}

# Policy — EventBridge 
resource "aws_iam_role_policy" "eventbridge_policy" {
  name = "${local.project}-eventbridge-policy"
  role = aws_iam_role.eventbridge_exec.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "states:StartExecution"
      Resource = aws_sfn_state_machine.pipeline.arn
    }]
  })
}


# 1. Schedule Rule — triggers every hour
resource "aws_cloudwatch_event_rule" "pipeline_schedule" {
  name                = "${local.project}-schedule"
  description         = "Trigger the data pipeline every hour"
  schedule_expression = "rate(1 minute)"

  tags = {
    Name        = "${local.project}-schedule"
    Environment = local.environment
  }
}

resource "aws_cloudwatch_event_target" "start_pipeline_on_schedule" {
  rule     = aws_cloudwatch_event_rule.pipeline_schedule.name
  arn      = aws_sfn_state_machine.pipeline.arn
  role_arn = aws_iam_role.eventbridge_exec.arn

  input = jsonencode({
    id     = "schedule-trigger"
    bucket = aws_s3_bucket.raw.bucket
    key    = "test_data.csv"
  })
}


# 2. S3 Upload Rule — triggers whenever ANY file is uploaded to the raw bucket
resource "aws_cloudwatch_event_rule" "s3_upload_trigger" {
  name        = "${local.project}-s3-upload-trigger"
  description = "Trigger the data pipeline when a file is uploaded to S3"

  event_pattern = jsonencode({
    source      = ["aws.s3"]
    detail-type = ["Object Created"]
    detail = {
      bucket = {
        name = [aws_s3_bucket.raw.bucket]
      }
    }
  })

  tags = {
    Name        = "${local.project}-s3-upload-trigger"
    Environment = local.environment
  }
}

resource "aws_cloudwatch_event_target" "start_pipeline_on_upload" {
  rule     = aws_cloudwatch_event_rule.s3_upload_trigger.name
  arn      = aws_sfn_state_machine.pipeline.arn
  role_arn = aws_iam_role.eventbridge_exec.arn

  # Extract bucket and key from the S3 event to pass to Step Functions
  # NOTE: LocalStack requires a top-level "id" field in the input template
  # to avoid a KeyError: 'id' bug in the events provider.
  input_transformer {
    input_paths = {
      s3_bucket = "$.detail.bucket.name"
      s3_key    = "$.detail.object.key"
      event_id  = "$.id"
    }
    input_template = <<EOF
{
  "id": <event_id>,
  "bucket": <s3_bucket>,
  "key": <s3_key>
}
EOF
  }
}


# Outputs
output "eventbridge_schedule_rule_name" {
  value = aws_cloudwatch_event_rule.pipeline_schedule.name
}

output "eventbridge_s3_rule_name" {
  value = aws_cloudwatch_event_rule.s3_upload_trigger.name
}
