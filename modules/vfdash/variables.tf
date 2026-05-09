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

# --- Cognito (replaces vfdash_api_key + google_oauth_client_id) ---
#
# Phase J' / K' of the dynamic-auth rollout (vfdash repo
# docs/social-login-cognito-DESIGN.md) replaced per-provider
# Google validation with a Cognito User Pool. The module now
# provisions the User Pool + App Client + Hosted UI domain +
# Google federation, and sets the resulting IDs in the Lambda's
# env (COGNITO_USER_POOL_ID / COGNITO_APP_CLIENT_ID / COGNITO_DOMAIN
# / COGNITO_REGION). Local dev keeps the API key path; prod is
# Cognito-only.

variable "cognito_domain_prefix" {
  description = "Cognito hosted UI domain prefix; resolves to <prefix>.auth.<region>.amazoncognito.com. Must be globally unique within Cognito. Default: vfdash-auth."
  type        = string
  default     = "vfdash-auth"
}

variable "callback_urls" {
  description = "OAuth callback URLs registered on the Cognito App Client. For an unpacked Chrome extension this is `https://<install-id>.chromiumapp.org/`. Add both the local-dev install ID and (once published) the Web Store ID."
  type        = list(string)
}

variable "google_client_id" {
  description = "Google OAuth Web-application client ID, configured in Google Cloud Console with Cognito's /oauth2/idpresponse as the authorised redirect URI. Used by the Cognito Google IdP — the extension never sees this."
  type        = string
}

variable "google_client_secret" {
  description = "Google OAuth Web-application client secret. Stored on the Cognito IdP server-side. Sourced from TF_VAR_google_client_secret — never put in tfvars."
  type        = string
  sensitive   = true
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
