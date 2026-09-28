# Existing-bucket delivery submodule

Connects an existing private R2 bucket to the Artifact Pages custom-domain delivery contract. This module does not create the bucket or configure lifecycle expiration.

It creates or manages the R2 custom domain, disables the alternate `r2.dev` domain, owns zone phase-root rulesets for logical route rewrites, private `/_control` denial, origin-respecting cache settings, and the trusted-HTML Content Security Policy on raw `/_artifacts/<site>/*` and `/_previews/<site>/revisions/<sha>/files/*` objects. Preview HTML stays on the application origin, is intended for an ordinary unsandboxed iframe, and receives the same trusted executable-content policy as production HTML. The CSP includes the object's site or revision path plus HTTPS sources, blocks insecure HTTP, and adds no CORS grant. See the root [module README](../../README.md#resource-ownership-and-apply-review) before applying. In particular, import and preserve the complete existing zone phase rules before managing a phase root, including its immutable name.

The custom-domain resource cannot be imported. Set `connect_custom_domain = false` only when an existing connection is managed and verified separately. The managed `r2.dev` resource is not importable or destroyable; manage its disabled state in one Terraform state.

This submodule uses Terraform `>= 1.5.0, < 2.0.0` and Cloudflare provider `>= 5.24.0, < 6.0.0`. It can be selected from a consumer repository with the Cloudflare module Git URL and `//modules/delivery?ref=<full-commit-sha>`.

The `transform_ruleset_name`, `firewall_ruleset_name`, `cache_ruleset_name`, and `response_header_ruleset_name` inputs default to descriptive Artifact Pages names for new phase roots. When importing an existing root, set the corresponding input to its current name before planning; changing a ruleset name requires replacement.
