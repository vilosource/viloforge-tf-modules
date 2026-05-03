# vfdash

Terraform module for the [vfdash](https://github.com/vilosource/vfdash)
launchpad backend on AWS.

## What it provisions

- **DynamoDB** `vfdash` — single-table, on-demand, GSI `entry-by-url`,
  TTL on the `ttl` attribute, point-in-time recovery on
- **Lambda** `vfdash` — `provided.al2023`, x86_64, 256 MiB by default,
  consumes the `bootstrap` zip produced by `make build-lambda`
- **Lambda Function URL** — auth `NONE` (the Go service does its own
  auth), buffered invoke mode
- **IAM role** for the Lambda with DynamoDB CRUD on the table + the
  managed `AWSLambdaBasicExecutionRole` for CloudWatch Logs
- **CloudWatch Log group** with bounded retention (14 days default)
- **ACM certificate** in `us-east-1` (CloudFront requires it there)
  with DNS-01 validation via Cloudflare
- **CloudFront distribution** with the public alias, HTTPS-redirect,
  caching disabled, all-viewer-headers forwarded
- **Cloudflare DNS records** — ACM validation CNAMEs and the
  user-facing `<host>` → CloudFront CNAME

## Free-tier footprint

For personal-use new-tab traffic the design stays at $0 indefinitely:
Lambda (1M req + 400k GB-s/mo always-free), DynamoDB on-demand
(25 GB always-free), CloudFront (1 TB egress + 10M req/mo
always-free since 2021), ACM (free), CloudWatch Logs (5 GB free).

What's deliberately **not** here: NAT Gateway, Route 53 hosted zone,
WAF, provisioned concurrency.

## Usage

```hcl
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
  # …profile/auth as your other aws provider…
}

module "vfdash" {
  source = "git::ssh://git@github.com/vilosource/viloforge-tf-modules.git//modules/vfdash?ref=v0.1.0"

  providers = {
    aws.us_east_1 = aws.us_east_1
  }

  domain             = "dash.viloforge.com"
  cloudflare_zone_id = var.cloudflare_zone_id
  lambda_zip_path    = "${path.root}/../../../../vfdash/bin/lambda.zip"

  # Optional auth knobs:
  google_oauth_client_id = "1234567890.apps.googleusercontent.com"
  # vfdash_api_key        = sourced from TF_VAR_vfdash_api_key (sensitive)

  tags = {
    Component = "vfdash"
  }
}
```

## Inputs the operator must supply at apply time

- `TF_VAR_vfdash_api_key` — sensitive; only path the extension can
  authenticate with until OAuth is wired
- `CLOUDFLARE_API_TOKEN` — needed by the cloudflare provider for
  the validation + dash CNAMEs

`viloforge-platform/aws/environments/prod/scripts/tf-env.sh`
already pulls both from the ansible vault — extend it with
`vault_vfdash_api_key` if you store the api key there.

## Lambda artifact

Build before applying:

```sh
cd ~/GitHub/vfdash
make build-lambda          # produces bin/lambda.zip
```

Re-apply when the binary changes; `source_code_hash =
filebase64sha256(...)` makes terraform notice the diff.

## Outputs

- `public_url` — `https://<domain>`, the URL the extension's options
  page should point at
- `function_url` — direct Lambda Function URL (bypass CloudFront for
  debugging)
- `cloudfront_distribution_id` — for `aws cloudfront
  create-invalidation`
- `lambda_function_name`, `dynamodb_table_name`, `log_group_name` —
  for `aws logs tail`, `aws dynamodb scan`, etc.

## CORS

The Go service hardcodes `chrome-extension://*` plus the
`VFDASH_CORS_ORIGINS` env var (set by this module to
`https://<domain>`). Lambda Function URL CORS is set to allow
`*` because CloudFront strips the Function URL hostname out of
the request and the Go service is the canonical CORS authority.

## CloudFront + OAC + Lambda Function URL gotchas

Three traps the module already handles, documented here so the
next person reading this doesn't re-derive them:

1. **Two permissions, not one.** Since October 2025, AWS_IAM
   Function URLs require *both* `lambda:InvokeFunctionUrl` and
   `lambda:InvokeFunction`. The module grants both; without the
   second you get a 403 with the message `Forbidden. For
   troubleshooting Function URL authorization issues, see ...`
   from the URL gate (Lambda is never invoked).

2. **OAC overwrites the `Authorization` header.** OAC's
   `signing_behavior = "always"` replaces any client-supplied
   Authorization with its SigV4 signature, then Lambda's URL
   frontend strips that header after validating. Apps that
   authenticate with bearer tokens (us — `Authorization: Bearer
   <api-key-or-id-token>`) must use a *different* header. The Go
   service reads from `X-Vfdash-Auth` first, then falls back to
   `Authorization` for direct/local-dev callers.

3. **POST/PUT bodies must be hash-signed by the client.** OAC
   signs every PUT/POST origin request including the body, but
   Lambda Function URLs *reject unsigned payloads*. The client
   must compute SHA-256 of the request body and send it as
   `x-amz-content-sha256: <hex>`. Without this header you get
   `403 InvalidSignatureException`. The vfdash-launchpad
   extension does this for every request.

A request through CloudFront → OAC → Lambda Function URL → vfdash
therefore looks like:

```
POST https://dash.viloforge.com/api/v1/.../entries
X-Vfdash-Auth: Bearer <key-or-google-id-token>   # for vfdash auth
Content-Type: application/json
Idempotency-Key: <client-generated>              # for vfdash idem cache
x-amz-content-sha256: <sha256(body)>             # for OAC signing
<json body>
```
