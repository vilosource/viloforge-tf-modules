terraform {
  required_version = ">= 1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
      # ACM cert for CloudFront MUST live in us-east-1; the caller
      # passes a second AWS provider via providers = { aws.us_east_1
      # = aws.us_east_1 }.
      configuration_aliases = [aws.us_east_1]
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5.0"
    }
  }
}

# =============================================================================
# DynamoDB — single-table backing for the API + Idempotency-Key cache
# =============================================================================
# Schema matches docs/tile-management-PRD.md §Storage:
#   PK = user#<uid>
#   SK = user# / dashboard# / group# / entry# / idem#
#   GSI entry-by-url over (gsi1pk = entry-by-url group#<did>#<gid>,
#                          gsi1sk = normalised url)
#   TTL on attribute "ttl" (used by the idempotency-key cache;
#   safely no-ops on rows without the attribute)
resource "aws_dynamodb_table" "main" {
  name         = var.name
  billing_mode = "PAY_PER_REQUEST"

  hash_key  = "pk"
  range_key = "sk"

  attribute {
    name = "pk"
    type = "S"
  }
  attribute {
    name = "sk"
    type = "S"
  }
  attribute {
    name = "gsi1pk"
    type = "S"
  }
  attribute {
    name = "gsi1sk"
    type = "S"
  }

  global_secondary_index {
    name            = "entry-by-url"
    hash_key        = "gsi1pk"
    range_key       = "gsi1sk"
    projection_type = "ALL"
  }

  ttl {
    attribute_name = "ttl"
    enabled        = true
  }

  point_in_time_recovery {
    enabled = true
  }

  tags = merge(var.tags, {
    Name = var.name
  })
}

# =============================================================================
# IAM — Lambda execution role with DynamoDB CRUD + CloudWatch Logs
# =============================================================================
resource "aws_iam_role" "lambda" {
  name = "${var.name}-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "lambda_dynamodb" {
  name = "${var.name}-dynamodb"
  role = aws_iam_role.lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "dynamodb:GetItem",
        "dynamodb:PutItem",
        "dynamodb:UpdateItem",
        "dynamodb:DeleteItem",
        "dynamodb:Query",
        "dynamodb:DescribeTable",
        "dynamodb:UpdateTimeToLive",
      ]
      Resource = [
        aws_dynamodb_table.main.arn,
        "${aws_dynamodb_table.main.arn}/index/*",
      ]
    }]
  })
}

# =============================================================================
# CloudWatch — log group with bounded retention so we stay free-tier
# =============================================================================
resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${var.name}"
  retention_in_days = var.log_retention_days
  tags              = var.tags
}

# =============================================================================
# Lambda — chi router via aws-lambda-go-api-proxy/chi (provided.al2023)
# =============================================================================
resource "aws_lambda_function" "main" {
  function_name = var.name
  role          = aws_iam_role.lambda.arn

  runtime = "provided.al2023"
  handler = "bootstrap"

  filename         = var.lambda_zip_path
  source_code_hash = filebase64sha256(var.lambda_zip_path)

  memory_size = var.lambda_memory_mb
  timeout     = var.lambda_timeout_seconds
  # arm64 saves ~20% on per-ms billing but the existing
  # `make build-lambda` target produces an amd64 binary; add an
  # arm64 target before flipping this.
  architectures = ["x86_64"]

  environment {
    variables = {
      VFDASH_TABLE_NAME      = aws_dynamodb_table.main.name
      VFDASH_API_KEY         = var.vfdash_api_key
      GOOGLE_OAUTH_CLIENT_ID = var.google_oauth_client_id
      VFDASH_CORS_ORIGINS    = "https://${var.domain}"
      VFDASH_IDEMPOTENCY_TTL = var.idempotency_ttl
    }
  }

  depends_on = [aws_cloudwatch_log_group.lambda]
  tags       = var.tags
}

resource "aws_lambda_function_url" "main" {
  function_name = aws_lambda_function.main.function_name
  # AWS_IAM (not NONE) so the URL can sit safely behind CloudFront
  # via Origin Access Control + SigV4 signing. AWS's "block public
  # access for Lambda Function URLs" feature (default-on for new
  # accounts post-2024) silently 403s unsigned NONE-auth URLs —
  # routing through CloudFront-signed-OAC is the recommended
  # alternative and it's also more defensible than relying on a
  # public URL.
  authorization_type = "AWS_IAM"
  invoke_mode        = "BUFFERED"

  cors {
    allow_credentials = false
    allow_origins     = ["*"]
    allow_methods     = ["*"]
    allow_headers     = ["*"]
    max_age           = 3600
  }
}

# Permission for CloudFront's OAC to call the Function URL with
# SigV4 signing. The principal is the CloudFront service; the
# AWS:SourceArn condition pins it to *this* distribution.
resource "aws_lambda_permission" "cloudfront_oac" {
  statement_id           = "AllowCloudFrontInvokeViaOAC"
  function_name          = aws_lambda_function.main.function_name
  action                 = "lambda:InvokeFunctionUrl"
  principal              = "cloudfront.amazonaws.com"
  function_url_auth_type = "AWS_IAM"
  source_arn             = aws_cloudfront_distribution.main.arn
}

# CloudFront forwards the Host header as the original SNI; rip the
# pure hostname (no scheme, no path) out of the function URL so the
# CloudFront origin block consumes it.
locals {
  function_url_host = trimsuffix(replace(aws_lambda_function_url.main.function_url, "https://", ""), "/")
}

# =============================================================================
# ACM cert (us-east-1, required for CloudFront) + DNS-01 validation
# =============================================================================
resource "aws_acm_certificate" "cloudfront" {
  provider          = aws.us_east_1
  domain_name       = var.domain
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = var.tags
}

# One DNS validation record per domain on the cert. ACM emits these
# under domain_validation_options as soon as the cert is requested.
resource "cloudflare_dns_record" "acm_validation" {
  for_each = {
    for dvo in aws_acm_certificate.cloudfront.domain_validation_options :
    dvo.domain_name => {
      name  = dvo.resource_record_name
      type  = dvo.resource_record_type
      value = dvo.resource_record_value
    }
  }

  zone_id = var.cloudflare_zone_id
  name    = trimsuffix(each.value.name, ".")
  content = trimsuffix(each.value.value, ".")
  type    = each.value.type
  proxied = false
  ttl     = 60
}

resource "aws_acm_certificate_validation" "cloudfront" {
  provider                = aws.us_east_1
  certificate_arn         = aws_acm_certificate.cloudfront.arn
  validation_record_fqdns = [for r in cloudflare_dns_record.acm_validation : r.name]
}

# =============================================================================
# CloudFront — custom domain in front of the Lambda Function URL
# =============================================================================
# Cache disabled (this is an API). AllViewer policy forwards every
# header, query string, and method to the origin so the chi router
# sees the exact request the client sent.

# Managed policy IDs — published by AWS, not subject to drift.
locals {
  cloudfront_managed_cache_disabled                = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad"
  cloudfront_origin_request_all_viewer_except_host = "b689b0a8-53d0-40ab-baf2-68738e2966ac"
}

# Origin Access Control — CloudFront signs every origin request
# with SigV4 against the lambda service. Pairs with the
# AWS_IAM-auth Function URL above and the aws_lambda_permission
# below.
resource "aws_cloudfront_origin_access_control" "lambda" {
  name                              = "${var.name}-lambda-oac"
  description                       = "OAC for ${var.name} → Lambda Function URL"
  origin_access_control_origin_type = "lambda"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_distribution" "main" {
  enabled         = true
  is_ipv6_enabled = true
  comment         = "${var.name} — fronts Lambda Function URL"
  aliases         = [var.domain]

  origin {
    origin_id                = "lambda-function-url"
    domain_name              = local.function_url_host
    origin_access_control_id = aws_cloudfront_origin_access_control.lambda.id

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  default_cache_behavior {
    target_origin_id       = "lambda-function-url"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods         = ["GET", "HEAD"]
    compress               = true

    cache_policy_id          = local.cloudfront_managed_cache_disabled
    origin_request_policy_id = local.cloudfront_origin_request_all_viewer_except_host
  }

  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate_validation.cloudfront.certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  price_class = "PriceClass_100" # NA + EU only — keeps cost down

  tags = var.tags
}

# =============================================================================
# DNS — user-facing dash.viloforge.com → CloudFront
# =============================================================================
# Managed inline (matching the wg/events pattern in
# viloforge-platform/aws/environments/prod/main.tf) because the
# target only exists after this terraform run; viloforge-cloudflare
# is the source of truth for records that exist independently of
# any one Terraform stack.
resource "cloudflare_dns_record" "domain" {
  zone_id = var.cloudflare_zone_id
  name    = trimsuffix(var.domain, ".viloforge.com")
  content = aws_cloudfront_distribution.main.domain_name
  type    = "CNAME"
  proxied = false # CloudFront terminates TLS; CF proxy in front would double-CDN
  ttl     = 300
}
