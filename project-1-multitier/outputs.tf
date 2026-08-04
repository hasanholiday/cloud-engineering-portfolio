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
