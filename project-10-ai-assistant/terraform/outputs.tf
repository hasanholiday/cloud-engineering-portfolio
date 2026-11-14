output "api_url" {
  value = "${aws_api_gateway_stage.prod.invoke_url}/ask"
}
output "docs_bucket" {
  value = aws_s3_bucket.docs.bucket
}
output "api_key_id" {
  value       = aws_api_gateway_api_key.team.id
  description = "Read the key value in the API Gateway console or with: aws apigateway get-api-key --api-key <id> --include-value"
}
output "ingest_function" {
  value = aws_lambda_function.ingest.function_name
}
