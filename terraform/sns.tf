#  SNS — Simple Notification Service

#   SNS Topic for Pipeline Alerts
resource "aws_sns_topic" "pipeline_alerts" {
  name = "${local.project}-alerts"

  tags = {
    Name        = "${local.project}-alerts"
    Environment = local.environment
    Purpose     = "Broadcast pipeline failures and critical alerts"
  }
}

#   (Optional) Email Subscription
# In a real AWS environment, you'd receive a confirmation email.
# LocalStack Free Tier accepts the subscription but won't actually send emails.
resource "aws_sns_topic_subscription" "email_alert" {
  topic_arn = aws_sns_topic.pipeline_alerts.arn
  protocol  = "email"
  endpoint  = "data-team-alerts@example.com"
}


#  Outputs
output "sns_topic_arn" {
  description = "SNS Topic ARN for pipeline alerts"
  value       = aws_sns_topic.pipeline_alerts.arn
}
