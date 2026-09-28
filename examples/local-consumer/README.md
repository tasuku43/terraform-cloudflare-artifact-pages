# Local Cloudflare module contract plan

This clean caller uses a local path only so maintainers can validate the package before a public release exists. It targets the owner-reported `artifact-pages.dev` apex as the prepared Cloudflare handoff. The purchase record does not verify authoritative DNS, the Cloudflare account or zone IDs, credentials, TLS, or deployed delivery. The account ID, zone ID, and bucket name remain placeholders; this plan must never be applied. For consumers, use the Registry address and an owner-approved published version from [`examples/registry-consumer`](../registry-consumer) after Registry publication.

The sample uses the minimum whole-day `preview_retention_days = 1` accepted by the shared module/CLI contract. R2 lifecycle deletion is asynchronous: Cloudflare says objects are typically removed within 24 hours after their expiration time, and processing can take longer ([R2 lifecycle behavior](https://developers.cloudflare.com/r2/buckets/object-lifecycles/)). An hours-scale provider check can use the API's seconds-based age condition ([R2 lifecycle API](https://developers.cloudflare.com/api/resources/r2/subresources/buckets/subresources/lifecycle/)) on a test-only prefix in a separate disposable bucket, then observe eventual deletion. This does not change or claim exact timing for the shared preview-retention contract.

Run from this directory:

```sh
terraform init -backend=false -input=false
terraform plan -refresh=false -input=false -var-file=terraform.tfvars.example
```

The no-refresh plan checks that one module declaration creates the bucket, delivery rules, and preview lifecycle configuration for the selected apex hostname. It is local source validation, not Cloudflare account or edge evidence.
