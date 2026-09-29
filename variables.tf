variable "account_id" {
  description = "Cloudflare account that owns the R2 bucket and zone configuration."
  type        = string

  validation {
    condition     = can(regex("^[0-9a-fA-F]{32}$", var.account_id))
    error_message = "account_id must be a 32-character hexadecimal Cloudflare account ID."
  }
}

variable "zone_id" {
  description = "Existing Cloudflare DNS zone that owns public_hostname."
  type        = string

  validation {
    condition     = can(regex("^[0-9a-fA-F]{32}$", var.zone_id))
    error_message = "zone_id must be a 32-character hexadecimal Cloudflare zone ID."
  }
}

variable "bucket_name" {
  description = "Name of the new private R2 bucket. Defaults to artifact-pages, which is account-scoped; availability is not guaranteed."
  type        = string
  default     = "artifact-pages"
  nullable    = false

  validation {
    condition     = trimspace(var.bucket_name) != ""
    error_message = "bucket_name must not be empty."
  }
}

variable "public_hostname" {
  description = "Hostname for the R2 custom domain, without a scheme or path."
  type        = string

  validation {
    condition = length(var.public_hostname) <= 253 && length(split(".", var.public_hostname)) >= 2 && alltrue([
      for label in split(".", var.public_hostname) :
      length(label) <= 63 && can(regex("^[A-Za-z0-9]([A-Za-z0-9-]*[A-Za-z0-9])?$", label))
    ])
    error_message = "public_hostname must be a DNS hostname with valid labels, without a scheme, port, or path."
  }
}

variable "preview_retention_days" {
  description = "Whole-number provider-managed lifetime for objects under _previews/. This setting is not part of the CLI deployment configuration."
  type        = number

  validation {
    condition     = var.preview_retention_days >= 1 && var.preview_retention_days <= 36500 && floor(var.preview_retention_days) == var.preview_retention_days
    error_message = "preview_retention_days must be a whole number from 1 to 36500."
  }
}

variable "access_key_id_env" {
  description = "Environment-variable name for the primary R2 access key ID in generated CLI configuration."
  type        = string
  default     = "CF_R2_ACCESS_KEY_ID"

  validation {
    condition     = can(regex("^[A-Za-z_][A-Za-z0-9_]*$", var.access_key_id_env))
    error_message = "access_key_id_env must be a valid environment-variable name."
  }
}

variable "secret_access_key_env" {
  description = "Environment-variable name for the primary R2 secret access key in generated CLI configuration."
  type        = string
  default     = "CF_R2_SECRET_ACCESS_KEY"

  validation {
    condition     = can(regex("^[A-Za-z_][A-Za-z0-9_]*$", var.secret_access_key_env))
    error_message = "secret_access_key_env must be a valid environment-variable name."
  }
}

variable "api_token_env" {
  description = "Environment-variable name for the Cloudflare API token in generated CLI configuration."
  type        = string
  default     = "CF_API_TOKEN"

  validation {
    condition     = can(regex("^[A-Za-z_][A-Za-z0-9_]*$", var.api_token_env))
    error_message = "api_token_env must be a valid environment-variable name."
  }
}

variable "additional_lifecycle_rules" {
  description = "Additional Cloudflare R2 lifecycle rules to keep in the bucket's complete lifecycle configuration. Do not duplicate the module-owned preview rules."
  type        = list(any)
  default     = []
}

variable "minimum_tls_version" {
  description = "Minimum TLS version accepted by the R2 custom domain."
  type        = string
  default     = "1.2"

  validation {
    condition     = contains(["1.0", "1.1", "1.2", "1.3"], var.minimum_tls_version)
    error_message = "minimum_tls_version must be one of 1.0, 1.1, 1.2, or 1.3."
  }
}

variable "connect_custom_domain" {
  description = "Whether Terraform should create the R2 custom-domain connection. The Cloudflare provider cannot import an existing connection."
  type        = bool
  default     = true
}

variable "existing_transform_rules" {
  description = "Complete existing http_request_transform root ruleset rules, in execution order, to preserve when this module owns that phase."
  type        = list(any)
  default     = []
}

variable "existing_cache_rules" {
  description = "Complete existing http_request_cache_settings root ruleset rules, in execution order, to preserve when this module owns that phase."
  type        = list(any)
  default     = []
}

variable "existing_response_header_rules" {
  description = "Complete existing http_response_headers_transform root ruleset rules, in execution order, to preserve when this module owns that phase."
  type        = list(any)
  default     = []
}

variable "transform_ruleset_name" {
  description = "Name for the http_request_transform phase root. For an imported ruleset, use its current name."
  type        = string
  default     = "Artifact Pages logical routes"
}

variable "cache_ruleset_name" {
  description = "Name for the http_request_cache_settings phase root. For an imported ruleset, use its current name."
  type        = string
  default     = "Artifact Pages origin cache policy"
}

variable "response_header_ruleset_name" {
  description = "Name for the http_response_headers_transform phase root. For an imported ruleset, use its current name."
  type        = string
  default     = "Artifact Pages trusted HTML resource policy"
}
