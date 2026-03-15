#  Elasticsearch — Index and search processed data


resource "aws_elasticsearch_domain" "pipeline_es" {
  domain_name           = "${local.project}-es"
  elasticsearch_version = "7.10"

  cluster_config {
    instance_type  = "t3.small.elasticsearch"
    instance_count = 1
  }

  ebs_options {
    ebs_enabled = true
    volume_size = 10
    volume_type = "gp2"
  }

  tags = {
    Name        = "${local.project}-es"
    Environment = local.environment
    Purpose     = "Index and search processed pipeline data"
  }
}


# Access Policy — allow all actions from the local account
resource "aws_elasticsearch_domain_policy" "pipeline_es_policy" {
  domain_name = aws_elasticsearch_domain.pipeline_es.domain_name

  access_policies = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { AWS = "*" }
      Action    = "es:*"
      Resource  = "${aws_elasticsearch_domain.pipeline_es.arn}/*"
    }]
  })
}


# Outputs
output "elasticsearch_endpoint" {
  description = "Elasticsearch domain endpoint"
  value       = aws_elasticsearch_domain.pipeline_es.endpoint
}

output "elasticsearch_domain_name" {
  description = "Elasticsearch domain name"
  value       = aws_elasticsearch_domain.pipeline_es.domain_name
}
