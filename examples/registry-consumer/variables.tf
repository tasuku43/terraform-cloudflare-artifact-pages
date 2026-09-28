variable "cloudflare_account_id" {
  description = "Cloudflare account ID that owns the R2 bucket and DNS zone."
  type        = string
}

variable "cloudflare_zone_id" {
  description = "Existing Cloudflare zone ID containing public_hostname."
  type        = string
}

variable "r2_bucket_name" {
  description = "Globally unique name for the new private R2 bucket."
  type        = string
}

variable "public_hostname" {
  description = "Public hostname in the selected zone, without a scheme, port, or path."
  type        = string
}

variable "preview_retention_days" {
  description = "Provider-managed preview lifetime; match the CLI deployment config."
  type        = number
}
