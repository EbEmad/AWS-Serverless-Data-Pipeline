resource "aws_iam_role" "sfn_exec" {
  name = "${local.project}-sfn-exec-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "states.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Name        = "${local.project}-sfn-exec-role"
    Environment = local.environment
  }
}

resource "aws_iam_role_policy" "sfn_policy" {
  name = "${local.project}-sfn-policy"
  role = aws_iam_role.sfn_exec.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "lambda:InvokeFunction"
      Resource = [
        aws_lambda_function.validator.arn,
        aws_lambda_function.transformer.arn,
      ]
    }]
  })
}

# State Machine — Validate, then Transform, with error handling
resource "aws_sfn_state_machine" "pipeline" {

  name     = "${local.project}-state-machine"
  role_arn = aws_iam_role.sfn_exec.arn

  definition = jsondecode({
    Comment = "AWS Data Pipeline: Validate → Transform"
    StartAt = "Validate"

    States={
        Validate = {
        Type     = "Task"
        Resource = "arn:aws:states:::lambda:invoke"
        Parameters = {
          FunctionName = aws_lambda_function.validator.function_name
          Payload = {
            "bucket.$" = "$.bucket"
            "key.$"    = "$.key"
          }
        }
        # Unwrap the Lambda response from { Payload: { ... } }
        ResultSelector = {
          "status.$"       = "$.Payload.status"
          "run_id.$"       = "$.Payload.run_id"
          "record_count.$" = "$.Payload.record_count"
          "bucket.$"       = "$.Payload.bucket"
          "key.$"          = "$.Payload.key"
        }
        ResultPath = "$"
        Next       = "Transform"
        Catch = [{
          ErrorEquals = ["States.ALL"]
          Next        = "FailState"
          ResultPath  = "$.error"
        }]

    }

    Transform = {
        Type     = "Task"
        Resource = "arn:aws:states:::lambda:invoke"
        Parameters = {
          FunctionName = aws_lambda_function.transformer.function_name
          Payload = {
            "bucket.$"       = "$.bucket"
            "key.$"          = "$.key"
            "run_id.$"       = "$.run_id"
            "record_count.$" = "$.record_count"
          }
        }
        ResultSelector = {
          "status.$"              = "$.Payload.status"
          "run_id.$"              = "$.Payload.run_id"
          "output_record_count.$" = "$.Payload.output_record_count"
          "processed_key.$"       = "$.Payload.processed_key"
        }
        ResultPath = "$"
        Next       = "SuccessState"
        Catch = [{
          ErrorEquals = ["States.ALL"]
          Next        = "FailState"
          ResultPath  = "$.error"
        }]
      }

      SuccessState = {
        Type = "Succeed"
      }

      # --- Fail ---
      FailState = {
        Type  = "Fail"
        Cause = "Pipeline execution failed"
        Error = "PipelineError"
      }
  })

}