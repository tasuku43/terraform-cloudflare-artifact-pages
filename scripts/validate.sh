#!/usr/bin/env bash
set -euo pipefail

terraform_bin="${TERRAFORM_BIN:-terraform}"
terraform_version="$($terraform_bin version -json | node -e 'let input="";process.stdin.on("data",chunk=>input+=chunk).on("end",()=>process.stdout.write(JSON.parse(input).terraform_version))')"
if [[ "$terraform_version" != "1.9.8" ]]; then
  printf 'Expected Terraform 1.9.8, got %s\n' "$terraform_version" >&2
  exit 1
fi

module_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
apprepo_dir="${ARTIFACT_PAGES_APPREPO_DIR:-$module_root/../git-artifact-pages}"
apprepo_dir="$(cd "$apprepo_dir" && pwd)"
if [[ ! -f "$apprepo_dir/go.mod" ]]; then
  printf 'Artifact Pages OSS checkout not found; set ARTIFACT_PAGES_APPREPO_DIR.\n' >&2
  exit 1
fi

export TF_PLUGIN_CACHE_DIR="${TF_PLUGIN_CACHE_DIR:-/tmp/terraform-provider-cache}"
mkdir -p "$TF_PLUGIN_CACHE_DIR" "$apprepo_dir/.local"
contract_helper_dir="$(mktemp -d "$apprepo_dir/.local/terraform-cloudflare-contract.XXXXXX")"
cp "$module_root/tests/cli-contract/validator.go" "$contract_helper_dir/main.go"
export TF_VAR_apprepo_dir="$apprepo_dir"
export TF_VAR_cli_contract_helper="$contract_helper_dir/main.go"

temporary_root="$(mktemp -d /tmp/cloudflare-module-validation.XXXXXX)"
trap 'rm -r "$temporary_root" "$contract_helper_dir"' EXIT

"$terraform_bin" fmt -check -recursive
"$terraform_bin" init -backend=false -input=false -lockfile=readonly
"$terraform_bin" validate
"$terraform_bin" -chdir=examples/local-consumer init -backend=false -input=false -lockfile=readonly
"$terraform_bin" -chdir=examples/local-consumer validate
"$terraform_bin" -chdir=tests/cli-contract init -backend=false -input=false -lockfile=readonly
"$terraform_bin" -chdir=tests/cli-contract test -no-color

node --test tests/*.test.js

migration_root="$temporary_root/migration"
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
