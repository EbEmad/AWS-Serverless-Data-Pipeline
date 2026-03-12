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


# Schedule Rule — triggers every hour
resource "aws_cloudwatch_event_rule" "pipeline_schedule" {
  name                = "${local.project}-schedule"
  description         = "Trigger the data pipeline every hour"
  schedule_expression = "rate(1 hour)"

  tags = {
    Name        = "${local.project}-schedule"
    Environment = local.environment
  }
}

# Target — when the rule fires, start a Step Functions execution
resource "aws_cloudwatch_event_target" "start_pipeline" {
  rule     = aws_cloudwatch_event_rule.pipeline_schedule.name
  arn      = aws_sfn_state_machine.pipeline.arn
  role_arn = aws_iam_role.eventbridge_exec.arn

  # tells the pipeline which file to process
  input = jsonencode({
    bucket = "${local.project}-raw-data"
    key    = "test_data.csv"
  })
}


# Outputs
output "eventbridge_rule_name" {
  description = "Name of the EventBridge schedule rule"
  value       = aws_cloudwatch_event_rule.pipeline_schedule.name
}
