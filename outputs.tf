output "bucket_name" {
  description = "Name of the R2 bucket shared by delivery and preview retention."
  value       = cloudflare_r2_bucket.origin.name
}

output "public_base_url" {
  description = "Public custom-domain base URL to set as cloudflare.publicBaseURL in the Artifact Pages deployment configuration."
  value       = module.delivery.public_base_url
}

output "artifact_pages_deployment_config_yaml" {
  description = "Non-secret Artifact Pages deployment configuration. It contains environment-variable names, never credential values."
  value = yamlencode({
    schemaVersion        = 1
    provider             = "cloudflare"
    previewRetentionDays = var.preview_retention_days
    cloudflare = {
      accountId                        = var.account_id
      bucket                           = cloudflare_r2_bucket.origin.name
      zoneId                           = var.zone_id
      publicBaseURL                    = module.delivery.public_base_url
      accessKeyIdEnv                   = "CF_R2_ACCESS_KEY_ID"
      secretAccessKeyEnv               = "CF_R2_SECRET_ACCESS_KEY"
      sessionTokenEnv                  = "CF_R2_SESSION_TOKEN"
      registryReaderAccessKeyIdEnv     = "CF_R2_REGISTRY_READER_ACCESS_KEY_ID"
      registryReaderSecretAccessKeyEnv = "CF_R2_REGISTRY_READER_SECRET_ACCESS_KEY"
      registryReaderSessionTokenEnv    = "CF_R2_REGISTRY_READER_SESSION_TOKEN"
      apiTokenEnv                      = "CF_API_TOKEN"
    }
  })
}
