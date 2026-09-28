variable "cloudflare_account_id" {
  description = "Cloudflare account ID used by the local no-refresh plan fixture."
  type        = string
}

variable "cloudflare_zone_id" {
  description = "Cloudflare zone ID used by the local no-refresh plan fixture."
  type        = string
}

variable "r2_bucket_name" {
  description = "Sample globally unique R2 bucket name. Replace it before a real deployment."
  type        = string
}

variable "public_hostname" {
  description = "Sample hostname in the selected Cloudflare zone. Replace it before a real deployment."
  type        = string
}

variable "preview_retention_days" {
  description = "Preview lifetime in whole days. Match this value to the CLI deployment configuration."
  type        = number
}
