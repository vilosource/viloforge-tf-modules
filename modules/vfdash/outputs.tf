output "lambda_function_arn" {
  description = "ARN of the vfdash Lambda function."
  value       = aws_lambda_function.main.arn
}

output "lambda_function_name" {
  description = "Name of the vfdash Lambda function (useful for `aws logs tail`)."
  value       = aws_lambda_function.main.function_name
}

output "function_url" {
  description = "Direct Lambda Function URL (bypasses CloudFront — useful for debugging)."
  value       = aws_lambda_function_url.main.function_url
}

output "cloudfront_domain" {
  description = "CloudFront distribution domain (the d123abc.cloudfront.net target the dash CNAME points at)."
  value       = aws_cloudfront_distribution.main.domain_name
}

output "cloudfront_distribution_id" {
  description = "CloudFront distribution id (useful for `aws cloudfront create-invalidation`)."
  value       = aws_cloudfront_distribution.main.id
}

output "dynamodb_table_name" {
  description = "DynamoDB table name (vfdash by default)."
  value       = aws_dynamodb_table.main.name
}

output "dynamodb_table_arn" {
  description = "DynamoDB table ARN."
  value       = aws_dynamodb_table.main.arn
}

output "log_group_name" {
  description = "CloudWatch Logs group for the Lambda."
  value       = aws_cloudwatch_log_group.lambda.name
}

# --- Cognito ---

output "cognito_user_pool_id" {
  description = "Cognito User Pool ID."
  value       = aws_cognito_user_pool.main.id
}

output "cognito_app_client_id" {
  description = "Cognito App Client ID — the OAuth client the extension authenticates as."
  value       = aws_cognito_user_pool_client.main.id
}

output "cognito_domain" {
  description = "Cognito hosted UI base URL."
  value       = "https://${aws_cognito_user_pool_domain.main.domain}.auth.${data.aws_region.current.name}.amazoncognito.com"
}

output "cognito_issuer" {
  description = "Cognito JWT issuer URL — the value the server's JWT validator checks against."
  value       = "https://cognito-idp.${data.aws_region.current.name}.amazonaws.com/${aws_cognito_user_pool.main.id}"
}

output "google_idp_redirect_uri" {
  description = "Redirect URI to add to the Google OAuth Web-application client's Authorised redirect URIs in Google Cloud Console."
  value       = "https://${aws_cognito_user_pool_domain.main.domain}.auth.${data.aws_region.current.name}.amazoncognito.com/oauth2/idpresponse"
}

output "public_url" {
  description = "Public URL the extension hits (https://<domain>)."
  value       = "https://${var.domain}"
}
