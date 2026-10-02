import assert from 'node:assert/strict'
import { readFile, stat } from 'node:fs/promises'
import test from 'node:test'

const root = new URL('../', import.meta.url)
const read = async (path) => readFile(new URL(path, root), 'utf8')
const main = await read('main.tf')
const variables = await read('variables.tf')
const outputs = await read('outputs.tf')
const delivery = await read('modules/delivery/main.tf')
const deliveryVariables = await read('modules/delivery/variables.tf')
const retention = await read('modules/retention/main.tf')
const retentionVariables = await read('modules/retention/variables.tf')

test('Registry module package has a root entry, self-contained submodules, examples, and license', async () => {
  for (const path of [
    'README.md', 'LICENSE', 'main.tf', 'variables.tf', 'outputs.tf', 'versions.tf',
    'modules/delivery/README.md', 'modules/delivery/main.tf',
    'modules/retention/README.md', 'modules/retention/main.tf',
    'examples/local-consumer/main.tf', 'examples/registry-consumer/main.tf',
  ]) {
    await stat(new URL(path, root))
  }
  assert.match(main, /source\s*=\s*"\.\/modules\/delivery"/u)
  assert.match(main, /source\s*=\s*"\.\/modules\/retention"/u)
})

test('one entry module creates and shares one bucket and one validated retention value', () => {
  assert.match(main, /resource\s+"cloudflare_r2_bucket"\s+"origin"/u)
  assert.match(main, /resource\s+"cloudflare_r2_bucket"\s+"origin"\s*\{[\s\S]*?name\s*=\s*var\.bucket_name/u)
  assert.match(main, /bucket_name\s*=\s*cloudflare_r2_bucket\.origin\.name/u)
  assert.match(main, /preview_retention_days\s*=\s*var\.preview_retention_days/u)
  assert.match(main, /additional_lifecycle_rules\s*=\s*var\.additional_lifecycle_rules/u)
  for (const name of ['transform_ruleset_name', 'cache_ruleset_name', 'response_header_ruleset_name']) {
    assert.match(main, new RegExp(`${name}\\s*=\\s*var\\.${name}`, 'u'))
    assert.match(variables, new RegExp(`variable\\s+"${name}"`, 'u'))
    assert.match(deliveryVariables, new RegExp(`variable\\s+"${name}"`, 'u'))
    assert.match(delivery, new RegExp(`name\\s+=\\s+var\\.${name}`, 'u'))
  }
  assert.match(retention, /rules\s*=\s*local\.lifecycle_rules/u)
  assert.match(retention, /bucket_name\s*=\s*var\.bucket_name/u)
  assert.match(retention, /max_age\s*=\s*var\.preview_retention_days\s*\*\s*24\s*\*\s*60\s*\*\s*60/u)
  assert.match(retentionVariables, /additional_lifecycle_rules must have unique non-empty IDs/u)
  assert.match(retentionVariables, /expire-preview-objects/u)
  assert.match(variables, /preview_retention_days\s*>=\s*1[\s\S]*?floor\(var\.preview_retention_days\)\s*==\s*var\.preview_retention_days/u)
  assert.doesNotMatch(outputs, /previewRetentionDays/u)
  assert.match(outputs, /bucket\s*=\s*cloudflare_r2_bucket\.origin\.name/u)
})

test('delivery preserves logical routes and cache policy without managing r2.dev', () => {
  assert.doesNotMatch(delivery, /cloudflare_r2_managed_domain/u)
  assert.match(delivery, /action\s*=\s*"rewrite"[\s\S]*?value\s*=\s*"\/index\.html"/u)
  assert.doesNotMatch(delivery, /control_block_rule|http_request_firewall_custom|action\s*=\s*"block"/u)
  assert.match(delivery, /lower\(url_decode\(http\.request\.uri\.path, \\"r\\"\)\)/u)
  for (const path of ['/index.html', '/preview-bridge.js', '/_indexes', '/_artifacts', '/_previews']) {
    assert.ok(delivery.includes(`\\"${path}\\"`), `route exclusions must reserve ${path}`)
  }
  assert.doesNotMatch(delivery, /reserved_path_exclusions[\s\S]*?\/_control/u)
  assert.match(delivery, /edge_ttl\s*=\s*\{\s*mode\s*=\s*"respect_origin"/u)
  assert.match(delivery, /browser_ttl\s*=\s*\{\s*mode\s*=\s*"respect_origin"/u)
  for (const name of ['existing_transform_rules', 'existing_cache_rules', 'existing_response_header_rules']) {
    assert.match(variables, new RegExp(`variable\\s+"${name}"`, 'u'))
  }
})

test('trusted production and preview HTML receive path-scoped HTTPS CSP without a CORS grant', async () => {
  assert.match(delivery, /phase\s*=\s*"http_response_headers_transform"/u)
  assert.match(delivery, /trusted_artifact_csp_expression\s*=\s*"concat\(/u)
  assert.match(delivery, /trusted_preview_csp_expression\s*=\s*"concat\(/u)
  assert.match(delivery, /split\(http\.request\.uri\.path,[\s\S]*?\[2\]/u)
  assert.ok(delivery.includes('split(http.request.uri.path, \\"/\\", 6)[4]'), 'preview CSP must use the sha segment after revisions/')
  assert.ok(!delivery.includes('split(http.request.uri.path, \\"/\\", 5)[3]'), 'preview CSP must not treat the revisions segment as the sha')
  assert.match(delivery, /starts_with\(\$\{local\.normalized_path\}, \\"\/_artifacts\/\\"\)/u)
  assert.match(delivery, /starts_with\(\$\{local\.normalized_path\}, \\"\/_previews\/\\"\)[\s\S]*?contains \\"\/files\/\\"/u)
  assert.match(delivery, /"Content-Security-Policy"\s*=\s*\{\s*operation\s*=\s*"set"\s*expression\s*=/u)
  assert.match(deliveryVariables, /existing_response_header_rules/u)
  assert.doesNotMatch(delivery, /Access-Control-Allow-Origin|Access-Control-Allow-Headers/u)
  for (const input of ['transform_ruleset_name', 'cache_ruleset_name', 'response_header_ruleset_name']) {
    assert.ok((await read('README.md')).includes(`| \`${input}\` | No |`), `README must document ${input}`)
  }
  assert.match(await read('README.md'), /_previews\/<site>\/revisions\/<sha>\/files/u)
})

test('deployment output stays minimal, uses the effective bucket, and names primary credential variables', () => {
  assert.match(outputs, /publicBaseURL\s*=\s*module\.delivery\.public_base_url/u)
  assert.match(outputs, /accountId\s*=\s*var\.account_id/u)
  assert.match(outputs, /bucket\s*=\s*cloudflare_r2_bucket\.origin\.name/u)
  assert.match(outputs, /zoneId\s*=\s*var\.zone_id/u)
  assert.match(outputs, /accessKeyIdEnv\s*=\s*var\.access_key_id_env/u)
  assert.match(outputs, /secretAccessKeyEnv\s*=\s*var\.secret_access_key_env/u)
  assert.match(outputs, /apiTokenEnv\s*=\s*var\.api_token_env/u)
  assert.match(outputs, /var\.access_key_id_env\s*==\s*"CF_R2_ACCESS_KEY_ID"/u)
  assert.match(outputs, /var\.secret_access_key_env\s*==\s*"CF_R2_SECRET_ACCESS_KEY"/u)
  assert.match(outputs, /var\.api_token_env\s*==\s*"CF_API_TOKEN"/u)
  assert.doesNotMatch(outputs, /previewRetentionDays|sessionTokenEnv/u)
  assert.match(outputs, /var\.registry_reader\s*==\s*null\s*\?\s*\{\}\s*:\s*merge\(/u)
  assert.match(outputs, /registryReaderAccessKeyIdEnv\s*=\s*var\.registry_reader\.access_key_id_env/u)
  assert.match(outputs, /registryReaderSecretAccessKeyEnv\s*=\s*var\.registry_reader\.secret_access_key_env/u)
  assert.match(outputs, /registryReaderSessionTokenEnv\s*=\s*var\.registry_reader\.session_token_env/u)
  assert.doesNotMatch(outputs, /accessKeyId\s*=\s*var\.|secretAccessKey\s*=\s*var\.|apiToken\s*=\s*var\./u)
  assert.match(variables, /variable "bucket_name"[\s\S]*?default\s*=\s*"artifact-pages"/u)
  assert.match(variables, /variable "access_key_id_env"[\s\S]*?default\s*=\s*"CF_R2_ACCESS_KEY_ID"/u)
  assert.match(variables, /variable "secret_access_key_env"[\s\S]*?default\s*=\s*"CF_R2_SECRET_ACCESS_KEY"/u)
  assert.match(variables, /variable "api_token_env"[\s\S]*?default\s*=\s*"CF_API_TOKEN"/u)
  assert.match(variables, /variable "registry_reader"[\s\S]*?default\s*=\s*null/u)
  assert.match(variables, /registry_reader must contain valid environment-variable names/u)
})

test('local and Registry examples have separate, explicit source contracts', async () => {
  const local = await read('examples/local-consumer/main.tf')
  const localVariables = await read('examples/local-consumer/variables.tf')
  const registry = await read('examples/registry-consumer/main.tf')
  const registryVariables = await read('examples/registry-consumer/variables.tf')
  const registryReadme = await read('examples/registry-consumer/README.md')
  assert.match(local, /source\s*=\s*"\.\.\/\.\."/u)
  assert.match(localVariables, /variable "r2_bucket_name"[\s\S]*?default\s*=\s*null/u)
  assert.match(registry, /source\s*=\s*"tasuku43\/artifact-pages\/cloudflare"/u)
  assert.match(registry, /version\s*=\s*"0\.1\.0"/u)
  assert.match(registryVariables, /variable "r2_bucket_name"[\s\S]*?default\s*=\s*null/u)
  assert.match(registryReadme, /has not approved or published/u)
})

test('local Cloudflare example uses reserved values and does not claim live verification', async () => {
  const tfvars = await read('examples/local-consumer/terraform.tfvars.example')
  const readme = await read('examples/local-consumer/README.md')
  assert.match(tfvars, /public_hostname\s*=\s*"artifacts\.example\.com"/u)
  assert.match(tfvars, /preview_retention_days\s*=\s*1/u)
  assert.match(readme, /reserved example hostname/u)
  assert.doesNotMatch(readme, /artifact-pages\.dev/u)
  assert.match(readme, /seconds-based age condition.*separate disposable bucket/su)
  assert.match(readme, /does not change or claim exact timing/u)
  assert.match(readme, /must never be applied/u)
})

test('migration guide states state moves, bucket import, ruleset ownership, and destruction limits', async () => {
  const readme = await read('README.md')
  assert.match(readme, /terraform state mv/u)
  assert.match(readme, /terraform import/u)
  assert.match(readme, /three zone phase-root rulesets/iu)
  assert.match(readme, /additional_lifecycle_rules/u)
  assert.match(readme, /does not support importing or destroying/u)
  assert.match(readme, /state mv 'cloudflare_r2_bucket\.origin' 'module\.artifact_pages\.cloudflare_r2_bucket\.origin'/u)
  assert.match(readme, /state may contain sensitive values/u)
  assert.match(readme, /does not enable a force-destroy option/u)
  assert.match(readme, /account permissions, plan limits, and Cloudflare pricing/u)
  assert.match(readme, /verify that its alternate `r2\.dev` domain is disabled/u)
  assert.match(await read('modules/delivery/README.md'), /enabled `r2\.dev` URL bypasses these hostname rewrite rules/u)
})
