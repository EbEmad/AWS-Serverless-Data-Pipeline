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

#  Kinesis Firehose Delivery Stream (Kinesis Stream → Elasticsearch + S3 Backup)
resource "aws_kinesis_firehose_delivery_stream" "es_delivery" {
  name        = "${local.project}-firehose"
  destination = "elasticsearch"

  kinesis_source_configuration {
    kinesis_stream_arn = aws_kinesis_stream.pipeline_stream.arn
    role_arn           = aws_iam_role.firehose_exec.arn
  }

  elasticsearch_configuration {
    domain_arn = aws_elasticsearch_domain.pipeline_es.arn
    role_arn   = aws_iam_role.firehose_exec.arn
    index_name = "pipeline-data"
    
    s3_backup_mode = "AllDocuments"
    s3_configuration {
      role_arn   = aws_iam_role.firehose_exec.arn
      bucket_arn = aws_s3_bucket.processed.arn
      prefix     = "archive/"
    }
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
      },
      {
        Effect   = "Allow"
        Action   = ["es:DescribeElasticsearchDomain", "es:DescribeElasticsearchDomains", "es:DescribeElasticsearchDomainConfig", "es:ESHttpPost", "es:ESHttpPut"]
        Resource = ["${aws_elasticsearch_domain.pipeline_es.arn}", "${aws_elasticsearch_domain.pipeline_es.arn}/*"]
      }
    ]
  })
}
