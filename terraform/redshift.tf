
#  Redshift — Data warehouse for SQL analytics

resource "aws_redshift_cluster" "pipeline_redshift" {
  cluster_identifier = "${local.project}-redshift"
  database_name      = "pipeline_db"
  master_username    = "admin"
  master_password    = "Admin1234!"     # For LocalStack only — use Secrets Manager in real AWS
  node_type          = "dc2.large"
  cluster_type       = "single-node"
  number_of_nodes    = 1

  # Skip the final snapshot on destroy (LocalStack doesn't support snapshots)
  skip_final_snapshot = true

  tags = {
    Name        = "${local.project}-redshift"
    Environment = local.environment
    Purpose     = "Data warehouse for SQL analytics on processed pipeline data"
  }

  timeouts {
    create = "1m"
    update = "1m"
    delete = "1m"
  }
}


# Outputs
output "redshift_cluster_endpoint" {
  description = "Redshift cluster endpoint"
  value       = aws_redshift_cluster.pipeline_redshift.endpoint
}

output "redshift_database_name" {
  description = "Redshift database name"
  value       = aws_redshift_cluster.pipeline_redshift.database_name
}
