#  CloudWatch — Monitoring and Alarms

#   Alarm: Validator Lambda Errors
resource "aws_cloudwatch_metric_alarm" "validator_errors" {
  alarm_name          = "${local.project}-validator-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 60
  statistic           = "Sum"
  threshold           = 0
  alarm_description   = "Alarm triggers if the Validator Lambda encounters any errors."
  
  # Actions
  alarm_actions = [aws_sns_topic.pipeline_alerts.arn]
  ok_actions    = []

  # Dimensions link this metric to the specific Lambda function
  dimensions = {
    FunctionName = aws_lambda_function.validator.function_name
  }

  tags = {
    Name        = "${local.project}-validator-errors"
    Environment = local.environment
  }
}


#   Alarm: Transformer Lambda Errors
resource "aws_cloudwatch_metric_alarm" "transformer_errors" {
  alarm_name          = "${local.project}-transformer-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 60
  statistic           = "Sum"
  threshold           = 0
  alarm_description   = "Alarm triggers if the Transformer Lambda encounters any errors."
  
  # Actions
  alarm_actions = [aws_sns_topic.pipeline_alerts.arn]
  ok_actions    = []

  # Dimensions link this metric to the specific Lambda function
  dimensions = {
    FunctionName = aws_lambda_function.transformer.function_name
  }

  tags = {
    Name        = "${local.project}-transformer-errors"
    Environment = local.environment
  }
}
