# Artifact Pages Cloudflare module

This root module creates one private R2 bucket and connects it to the Cloudflare delivery and preview-retention configuration used by Artifact Pages. It preserves the static application/content planes and logical SPA routes, rewrites unmatched paths—including `/_control/*`—to `/index.html`, respects origin cache headers, and configures provider-managed `_previews/` expiration. It leaves the alternate `r2.dev` domain unmanaged; for a newly created private bucket, Cloudflare leaves that domain disabled by default. It does not create a WAF or firewall ruleset. Production artifacts and raw preview objects receive the same trusted-HTML Content Security Policy: HTTPS resources are allowed, insecure HTTP resources are blocked, and the rule grants no CORS access.

The module does not deploy the SPA, publish a registry or site, create publisher credentials, configure viewer accounts, or add a request-time service. Cloudflare Access remains an operator-managed edge policy. The CLI continues to publish application and content objects through its configured credentials.

## Registry consumer

The intended public Registry address is `tasuku43/artifact-pages/cloudflare`. The GitHub repository exists as a public shell, but its module source has not been pushed; the Registry does not list the module. The package is prepared for candidate version `0.1.0`, which has not been approved or published. After the owner approves a release, pushes the reviewed source and immutable tag, and publishes it to the Registry, a caller can use:

```hcl
module "artifact_pages" {
  source  = "tasuku43/artifact-pages/cloudflare"
  version = "0.1.0"

  account_id             = var.cloudflare_account_id
  zone_id                = var.cloudflare_zone_id
  # Optional: defaults to "artifact-pages" within this account.
  bucket_name            = var.r2_bucket_name
  public_hostname        = var.public_hostname
  preview_retention_days = var.preview_retention_days
}
```

See [`examples/registry-consumer`](examples/registry-consumer) for the complete consumer root and [`examples/local-consumer`](examples/local-consumer) for a runnable local plan against this checkout.

## Inputs

| Name | Required | Description |
| --- | --- | --- |
| `account_id` | Yes | 32-character Cloudflare account ID that owns the R2 bucket and configuration. |
| `zone_id` | Yes | Existing Cloudflare zone containing `public_hostname`. |
| `bucket_name` | No | Name for the new private R2 bucket. Defaults to `artifact-pages`, which is scoped to the Cloudflare account. The default is not reserved; an existing name causes bucket creation to fail. |
| `public_hostname` | Yes | Public hostname without a scheme, port, or path. The DNS zone and custom-domain prerequisites must already exist. |
| `preview_retention_days` | Yes | Whole number from 1 through 36500 for provider-managed `_previews/` expiration. The CLI deployment configuration does not contain a retention value. |
| `access_key_id_env` | No | Environment-variable name for the primary R2 access key ID in generated CLI configuration. Defaults to `CF_R2_ACCESS_KEY_ID`. |
| `secret_access_key_env` | No | Environment-variable name for the primary R2 secret access key in generated CLI configuration. Defaults to `CF_R2_SECRET_ACCESS_KEY`. |
| `api_token_env` | No | Environment-variable name for the Cloudflare API token in generated CLI configuration. Defaults to `CF_API_TOKEN`. |
| `registry_reader` | No | Optional delegated-publisher registry-reader environment names. Omit it for the normal setup. When set, provide both `access_key_id_env` and `secret_access_key_env`; `session_token_env` is optional for temporary credentials. |
| `additional_lifecycle_rules` | No | Additional R2 lifecycle rules to preserve alongside the module-owned preview rules. Defaults to `[]`; supply all existing non-module rules when taking lifecycle ownership of a bucket. |
| `minimum_tls_version` | No | Custom-domain TLS minimum. Defaults to `1.2`. |
| `connect_custom_domain` | No | Create the R2 custom-domain connection. Defaults to `true`; set `false` only when the same connection is already managed outside Terraform because the provider cannot import it. |
| `existing_transform_rules` | No | Complete existing transform phase-root rules, in execution order. Defaults to `[]`. |
| `existing_cache_rules` | No | Complete existing cache phase-root rules, in execution order. Defaults to `[]`. |
| `existing_response_header_rules` | No | Complete existing response-header transform phase-root rules, in execution order. Defaults to `[]`. |
| `transform_ruleset_name` | No | Phase-root name. Defaults to `Artifact Pages logical routes`; retain an imported root's existing name. |
| `cache_ruleset_name` | No | Phase-root name. Defaults to `Artifact Pages origin cache policy`; retain an imported root's existing name. |
| `response_header_ruleset_name` | No | Phase-root name. Defaults to `Artifact Pages trusted HTML resource policy`; retain an imported root's existing name. |

The module supports Terraform `>= 1.5.0, < 2.0.0` and Cloudflare provider `>= 5.24.0, < 6.0.0`. Local acceptance uses Terraform 1.9.8. The package-root lock file selects Cloudflare provider 5.26.0; the clean local consumer pins 5.24.0 to check the declared minimum supported provider version.

## Outputs

| Name | Description |
| --- | --- |
| `bucket_name` | Created R2 bucket name. |
| `public_base_url` | `https://<public_hostname>` for `cloudflare.publicBaseURL`. |
| `artifact_pages_deployment_config_yaml` | Ready-to-copy v1 target YAML with non-secret identifiers and the effective bucket. Default credential environment names are supplied by the CLI and omitted; non-default environment-name overrides are emitted. Put credential values outside Terraform state and source control. |

The generated CLI YAML includes the effective created bucket name, so an explicit `bucket_name` override is preserved. CLI-default environment names for the primary R2 key, secret, and API token are omitted. By default the YAML has no registry-reader environment names; set `registry_reader` explicitly to add the delegated publisher's separate reader identity. Temporary primary session credentials remain a CLI config option and are not output by this module. Preview retention is configured and enforced only through `preview_retention_days` and the R2 lifecycle rules; the CLI config does not contain or enforce an expiry value. The retention module appends the two required preview rules to `additional_lifecycle_rules`.

For a delegated publisher, set the optional object in the module call:

```hcl
registry_reader = {
  access_key_id_env     = "CF_R2_REGISTRY_READER_ACCESS_KEY_ID"
  secret_access_key_env = "CF_R2_REGISTRY_READER_SECRET_ACCESS_KEY"
  # Include only when Cloudflare issued temporary reader credentials.
  session_token_env = "CF_R2_REGISTRY_READER_SESSION_TOKEN"
}
```

The CLI uses these names only for `site publish` and `preview publish`. Other commands ignore the reader values, and a configuration without this object uses the primary credential to read the registry.

## Resource ownership and apply review

The caller must select the Cloudflare account, an existing managed DNS zone, a hostname in that zone, and the preview retention period. Terraform manages the R2 bucket, the complete `http_request_transform`, `http_request_cache_settings`, and `http_response_headers_transform` phase-root rulesets, and the bucket's complete lifecycle rule set. There is no `http_request_firewall_custom` ruleset. Unmatched paths, including reserved `/_control/*` object names, use the application shell and never request those object keys. The response-header rules apply the trusted HTML resource policy to raw `/_artifacts/<site>/*` and `/_previews/<site>/revisions/<sha>/files/*` paths on the selected hostname. They keep preview documents on the application origin; they do not add a hostname or CORS grant.

Before the first apply:

1. Inspect the three zone phase-root rulesets managed by this module. If one already exists, record its current name and rules. Set the matching `*_ruleset_name` input to the current name before import; Cloudflare ruleset names are immutable, and changing one after import plans replacement. Then import it into the corresponding resource and pass every existing rule through the matching `existing_*_rules` input in its existing execution order. For example:

   ```sh
   terraform import 'module.artifact_pages.module.delivery.cloudflare_ruleset.logical_routes' 'zones/<zone-id>/<ruleset-id>'
   terraform import 'module.artifact_pages.module.delivery.cloudflare_ruleset.origin_cache_policy' 'zones/<zone-id>/<ruleset-id>'
   terraform import 'module.artifact_pages.module.delivery.cloudflare_ruleset.trusted_html_resource_policy' 'zones/<zone-id>/<ruleset-id>'
   ```

   The default names and empty rule lists are for new phase roots. They do not preserve or adopt existing rulesets by themselves.
2. Review the full plan for replacements, removals, and ruleset changes. The lifecycle resource owns the complete R2 bucket lifecycle configuration; pass every other lifecycle rule through `additional_lifecycle_rules`. The Cloudflare provider does not support importing or destroying this lifecycle resource. Its Terraform delete operation removes state but leaves the API configuration in place, so retain the configuration in one state or remove the rules manually through Cloudflare before handing off ownership.
3. The R2 custom-domain resource cannot be imported. If an identical custom-domain connection is already present, set `connect_custom_domain = false` and verify that the existing connection is enabled with the intended TLS version.
4. Keep the bucket content recoverable. The module does not enable a force-destroy option; empty or migrate the bucket deliberately before destroying it. Removing the module is not a content backup or a CLI deployment rollback.
5. Check current account permissions, plan limits, and Cloudflare pricing for R2 storage/requests, custom domains, and rules. The module itself does not estimate account-specific charges.

The Cloudflare provider needs permissions to manage R2 storage, R2 custom domains, lifecycle rules, and the three zone ruleset phases. Configure `cloudflare` authentication in the caller, typically through `CLOUDFLARE_API_TOKEN`; do not put token values in `.tf`, `.tfvars`, outputs, or committed examples.

## Existing-bucket use

The root entry module always creates a bucket. If a bucket already exists and should remain managed elsewhere, use the self-contained [`delivery` submodule](modules/delivery/README.md) and [`retention` submodule](modules/retention/README.md) separately against that bucket. The modules are included in this repository, so they do not depend on a sibling checkout of the OSS project. Before exposing an existing bucket, verify that its alternate `r2.dev` domain is disabled in Cloudflare; these modules leave that setting unmanaged, and an enabled `r2.dev` URL bypasses the custom-host rewrite rules and could expose private `/_control/*` objects.

The OSS repository's former `infra/cloudflare/delivery` and `infra/cloudflare/retention` implementations are being moved to these modules as their source of truth. For existing lower-level callers, keep the same Terraform module labels and inputs and change only the module `source` to the matching Git subdirectory pinned to a full commit SHA. The resource addresses therefore remain under the same module labels; review a fresh plan and expect no address-only replacement.

To migrate those two modules to the new root entry module, add the new `artifact_pages` module block, keep the existing rule inputs complete, and review all state moves before changing infrastructure. First back up the state, then move each old module instance into the new nested module path:

```sh
umask 077
state_backup_dir="$(mktemp -d "${TMPDIR:-/tmp}/artifact-pages-state.XXXXXX")"
terraform state pull > "$state_backup_dir/terraform-state.json"
terraform state mv 'module.artifact_pages_delivery' 'module.artifact_pages.module.delivery'
terraform state mv 'module.preview_retention' 'module.artifact_pages.module.retention'
```

Keep the backup outside the repository with restricted permissions because Terraform state may contain sensitive values. Retain it only as long as the migration requires.

If the existing R2 bucket is already managed in the same Terraform state, move that resource to the entry module's bucket address before planning. For a root resource named `cloudflare_r2_bucket.origin`, the command is:

```sh
terraform state mv 'cloudflare_r2_bucket.origin' 'module.artifact_pages.cloudflare_r2_bucket.origin'
```

Use the actual current address if the bucket is nested under another module. If the existing R2 bucket was created outside Terraform and is not in state, import it at `module.artifact_pages.cloudflare_r2_bucket.origin` using the provider's `<account_id>/<bucket_name>/<jurisdiction>` ID (use `default` when no special jurisdiction is configured):

```sh
terraform import 'module.artifact_pages.cloudflare_r2_bucket.origin' '<account-id>/<bucket-name>/default'
```

Do not run the new-bucket plan until the import and both module moves are reflected in state. Then review the plan for unexpected changes. A source pin or version rollback does not reverse applied state changes.

## Local validation

For the full developer integration suite, use Terraform 1.9.8, Node.js, Go, Python 3 (standard library only for the local API fixture), and a separately selected Artifact Pages OSS checkout:

```sh
ARTIFACT_PAGES_APPREPO_DIR=/absolute/oss/checkout ./scripts/validate.sh
```

For standalone package and exact-commit consumer checks without an OSS checkout, run `python3 scripts/check-package.py --commit FULL_SHA` under Terraform 1.9.8. See [release preparation and publication](RELEASE.md) for provenance, minimum-provider checks, owner approvals, and subsequent upgrades.

The validation runs formatting, backend-free initialization, validation, a no-refresh plan for the clean local caller, negative-input checks, source-contract tests, and an isolated `terraform_data` state-move fixture for the documented module-address migration. It does not authenticate to or modify a Cloudflare account. Real zone-rule compatibility, public routing/cache behavior, retention timing, R2 consistency, and purge propagation remain T15/T14 provider proof.
