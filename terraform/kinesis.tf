#  Kinesis — Real-time data streaming

#  Kinesis Data Stream
resource "aws_kinesis_stream" "pipeline_stream" {
  name             = "${local.project}-stream"
  shard_count      = 1
  retention_period = 24

  tags = {
    Name        = "${local.project}-stream"
    Environment = local.environment
  }
}

#  IAM Role for Kinesis Firehose (to deliver to S3)
resource "aws_iam_role" "firehose_exec" {
  name = "${local.project}-firehose-exec-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "firehose.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

#  Kinesis Firehose Delivery Stream (Kinesis Stream → S3 Backup)
resource "aws_kinesis_firehose_delivery_stream" "s3_archive" {
  name        = "${local.project}-firehose"
  destination = "extended_s3"

  kinesis_source_configuration {
    kinesis_stream_arn = aws_kinesis_stream.pipeline_stream.arn
    role_arn           = aws_iam_role.firehose_exec.arn
  }

  extended_s3_configuration {
    role_arn   = aws_iam_role.firehose_exec.arn
    bucket_arn = aws_s3_bucket.processed.arn
    prefix     = "archive/"
  }
}

# IAM Policy for Firehose
resource "aws_iam_role_policy" "firehose_policy" {
  name = "${local.project}-firehose-policy"
  role = aws_iam_role.firehose_exec.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:AbortMultipartUpload", "s3:GetBucketLocation", "s3:GetObject", "s3:ListBucket", "s3:ListBucketMultipartUploads", "s3:PutObject"]
        Resource = [aws_s3_bucket.processed.arn, "${aws_s3_bucket.processed.arn}/*"]
      },
      {
        Effect   = "Allow"
        Action   = ["kinesis:DescribeStream", "kinesis:GetShardIterator", "kinesis:GetRecords", "kinesis:ListShards"]
        Resource = aws_kinesis_stream.pipeline_stream.arn
      }
    ]
  })
}
