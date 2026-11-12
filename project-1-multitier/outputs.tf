output "load_balancer_url" {
  value       = aws_lb.main.dns_name
  description = "Visit this URL to see your application"
}

output "database_endpoint" {
  value       = aws_db_instance.main.endpoint
  description = "RDS database connection endpoint"
}

output "vpc_id" {
  value       = aws_vpc.main.id
  description = "VPC ID"
}

output "database_secret_arn" {
  value       = aws_db_instance.main.master_user_secret[0].secret_arn
  description = "Secrets Manager ARN holding the generated database password"
}
