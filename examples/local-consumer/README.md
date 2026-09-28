# Local Cloudflare module contract plan

This clean caller uses a local path only so maintainers can validate the package before a public release exists. Its sample identifiers are placeholders; its plan must never be applied. For consumers, use the Registry address and an owner-approved published version from [`examples/registry-consumer`](../registry-consumer) after Registry publication.

Run from this directory:

```sh
terraform init -backend=false -input=false
terraform plan -refresh=false -input=false -var-file=terraform.tfvars.example
```

The no-refresh plan checks that one module declaration creates the bucket, delivery rules, and preview lifecycle configuration. It is local source validation, not Cloudflare account or edge evidence.
