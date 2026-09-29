# Existing-bucket preview-retention submodule

Manages the complete R2 lifecycle rule set for an existing bucket. It expires only objects under `_previews/` after `preview_retention_days` and aborts incomplete preview multipart uploads after seven days. Preview retention is configured and enforced only through this provider lifecycle policy; it is not part of the Artifact Pages CLI configuration. Expiration is asynchronous and is not an exact-time revocation mechanism.

The lifecycle resource owns the bucket's complete lifecycle configuration. Inspect the current rules and supply every rule that must remain through `additional_lifecycle_rules`. This provider resource cannot be imported. Its delete operation only removes Terraform state and leaves the API lifecycle configuration in place; keep it in one state or delete its rules manually through Cloudflare before handing off ownership. This submodule does not create the bucket or manage application/content delivery.

| Input | Description |
| --- | --- |
| `account_id` | Cloudflare account that owns the bucket. |
| `bucket_name` | Existing R2 bucket name. |
| `preview_retention_days` | Positive whole-number lifetime in days for objects under `_previews/`. |
| `additional_lifecycle_rules` | Complete set of existing non-module lifecycle rules to preserve. See the [provider rule schema](https://registry.terraform.io/providers/cloudflare/cloudflare/5.24.0/docs/resources/r2_bucket_lifecycle). |

This submodule uses Terraform `>= 1.5.0, < 2.0.0` and Cloudflare provider `>= 5.24.0, < 6.0.0`. It can be selected from a consumer repository with the Cloudflare module Git URL and `//modules/retention?ref=<full-commit-sha>`.
