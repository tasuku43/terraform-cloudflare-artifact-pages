#!/usr/bin/env bash
set -euo pipefail

terraform_bin="${TERRAFORM_BIN:-terraform}"
terraform_version="$($terraform_bin version -json | node -e 'let input="";process.stdin.on("data",chunk=>input+=chunk).on("end",()=>process.stdout.write(JSON.parse(input).terraform_version))')"
if [[ "$terraform_version" != "1.9.8" ]]; then
  printf 'Expected Terraform 1.9.8, got %s\n' "$terraform_version" >&2
  exit 1
fi

export TF_PLUGIN_CACHE_DIR="${TF_PLUGIN_CACHE_DIR:-/tmp/terraform-provider-cache}"
mkdir -p "$TF_PLUGIN_CACHE_DIR"
export CLOUDFLARE_API_TOKEN="local-contract-plan-placeholder"

"$terraform_bin" fmt -check -recursive
"$terraform_bin" init -backend=false -input=false -lockfile=readonly
"$terraform_bin" validate
"$terraform_bin" -chdir=examples/local-consumer init -backend=false -input=false -lockfile=readonly
"$terraform_bin" -chdir=examples/local-consumer validate
"$terraform_bin" -chdir=examples/local-consumer plan -refresh=false -input=false -lock=false -var-file=terraform.tfvars.example

check_invalid_plan() {
  local input="$1"
  local expected="$2"
  local output
  local status
  set +e
  output=$("$terraform_bin" -chdir=examples/local-consumer plan -refresh=false -input=false -lock=false -var-file=terraform.tfvars.example -var "$input" 2>&1)
  status=$?
  set -e
  if [[ "$status" -eq 0 ]] || ! printf '%s' "$output" | rg -q "$expected"; then
    printf '%s\n' "$output" >&2
    printf 'Expected plan rejection containing: %s\n' "$expected" >&2
    exit 1
  fi
}

check_invalid_plan 'preview_retention_days=0' 'preview_retention_days must be a whole number'
check_invalid_plan 'preview_retention_days=1.5' 'preview_retention_days must be a whole number'
check_invalid_plan 'cloudflare_account_id="bad"' 'account_id must be a 32-character hexadecimal'
check_invalid_plan 'public_hostname="https://artifacts.example.com"' 'public_hostname must be a DNS hostname'

node --test tests/*.test.js

migration_root="$(mktemp -d /tmp/cloudflare-module-migration.XXXXXX)"
trap 'rm -rf "$migration_root"' EXIT
mkdir -p "$migration_root/work/modules"
cp -R tests/fixtures/module-migration/modules/. "$migration_root/work/modules/"
cp tests/fixtures/module-migration/old.tf "$migration_root/work/main.tf"
"$terraform_bin" -chdir="$migration_root/work" init -backend=false -input=false
"$terraform_bin" -chdir="$migration_root/work" apply -auto-approve -input=false
cp tests/fixtures/module-migration/new.tf "$migration_root/work/main.tf"
"$terraform_bin" -chdir="$migration_root/work" init -backend=false -input=false
"$terraform_bin" -chdir="$migration_root/work" state mv 'module.artifact_pages_delivery' 'module.artifact_pages.module.delivery'
"$terraform_bin" -chdir="$migration_root/work" state mv 'module.preview_retention' 'module.artifact_pages.module.retention'
"$terraform_bin" -chdir="$migration_root/work" plan -input=false -lock=false -detailed-exitcode
