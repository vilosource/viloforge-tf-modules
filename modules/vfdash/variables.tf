variable "name" {
  description = "Resource-name prefix used for the Lambda function, DynamoDB table, IAM role, and log group."
  type        = string
  default     = "vfdash"
}

variable "domain" {
  description = "Public hostname served by the CloudFront distribution (e.g. dash.viloforge.com). The ACM cert and CloudFront alias both bind to this exact name."
  type        = string
}

variable "cloudflare_zone_id" {
  description = "Cloudflare zone ID for the parent domain (viloforge.com). Used to write the ACM DNS-01 validation CNAMEs and the user-facing dash CNAME."
  type        = string
}

variable "lambda_zip_path" {
  description = "Local filesystem path to the Lambda artifact built by `make build-lambda` in vilosource/vfdash (a zip containing the `bootstrap` binary for the provided.al2023 runtime)."
  type        = string
}

variable "lambda_memory_mb" {
  description = "Lambda memory allocation. CPU scales linearly with this. 256 MiB is comfortable for the chi router on a cold start."
  type        = number
  default     = 256
}

variable "lambda_timeout_seconds" {
  description = "Lambda handler timeout. The HTTP read budget (per protocols §11) is well under 1 second; 10 leaves headroom for cold-start DynamoDB reaches."
  type        = number
  default     = 10
}

variable "vfdash_api_key" {
  description = "Static API key honoured by the auth middleware as a fallback to Google ID token. Lands in the Lambda function's environment, which means anyone with lambda:GetFunctionConfiguration can read it. Sourced from TF_VAR_vfdash_api_key — never put in tfvars."
  type        = string
  sensitive   = true
  default     = ""
}

variable "google_oauth_client_id" {
  description = "Google OAuth client_id used as the audience when validating ID tokens. When empty, only the API-key path works."
  type        = string
  default     = ""
}

variable "idempotency_ttl" {
  description = "Cache lifetime for the Idempotency-Key middleware. Parsed by Go's time.ParseDuration."
  type        = string
  default     = "24h"
}

variable "log_retention_days" {
  description = "CloudWatch Logs retention for the Lambda log group. 14 days keeps free-tier headroom; bump if richer post-mortems are needed."
  type        = number
  default     = 14
}

variable "tags" {
  description = "Extra tags merged into every resource."
  type        = map(string)
  default     = {}
}
