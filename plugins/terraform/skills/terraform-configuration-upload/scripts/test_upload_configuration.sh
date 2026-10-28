#!/usr/bin/env bash
# Local-only tests for the Terraform configuration upload helper.

set -Eeuo pipefail
IFS=$'\n\t'

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
helper="$script_dir/upload_configuration.sh"
test_root=$(mktemp -d "${TMPDIR:-/tmp}/terraform-upload-test.XXXXXX")
trap 'rm -rf "$test_root"' EXIT HUP INT TERM

fail() {
  printf 'test failed: %s\n' "$1" >&2
  exit 1
}

command -v jq >/dev/null 2>&1 || fail "jq is required"

mkdir -p "$test_root/basic/modules/example"
chmod 700 "$test_root/basic"
printf 'terraform {}\n' >"$test_root/basic/main.tf"
printf 'variable "name" {}\n' >"$test_root/basic/variables.tf"
printf 'module "example" {}\n' >"$test_root/basic/modules/example/main.tf"
find "$test_root/basic" -type f -exec chmod 600 {} +
find "$test_root/basic" -type d -exec chmod 700 {} +

result=$("$helper" --configuration-root "$test_root/basic" --inspect)
[ "$(printf '%s' "$result" | jq -r '.status')" = ready ] || fail "inspection was not ready"
[ "$(printf '%s' "$result" | jq -r '.file_count')" -eq 3 ] || fail "unexpected file count"
[ "$(printf '%s' "$result" | jq -r '.files | join(",")')" = 'main.tf,modules/example/main.tf,variables.tf' ] || fail "unexpected file list"

printf 'secret\n' >"$test_root/basic/.env"
if "$helper" --configuration-root "$test_root/basic" --inspect >/dev/null 2>&1; then
  fail "credential-like file was not rejected"
fi
rm "$test_root/basic/.env"

mkdir -p "$test_root/basic/modules/example/.terraform"
if "$helper" --configuration-root "$test_root/basic" --inspect >/dev/null 2>&1; then
  fail "nested .terraform directory was not rejected"
fi
rm -rf "$test_root/basic/modules/example/.terraform"

printf 'secret\n' >"$test_root/basic/modules/example/.env"
if "$helper" --configuration-root "$test_root/basic" --inspect >/dev/null 2>&1; then
  fail "nested .env file was not rejected"
fi
rm "$test_root/basic/modules/example/.env"

printf 'state\n' >"$test_root/basic/modules/example/terraform.tfstate"
if "$helper" --configuration-root "$test_root/basic" --inspect >/dev/null 2>&1; then
  fail "nested state file was not rejected"
fi
rm "$test_root/basic/modules/example/terraform.tfstate"

mkdir -p "$test_root/basic/modules/example/.git"
if "$helper" --configuration-root "$test_root/basic" --inspect >/dev/null 2>&1; then
  fail "nested .git directory was not rejected"
fi
rm -rf "$test_root/basic/modules/example/.git"

mkdir "$test_root/basic/.git"
if "$helper" --configuration-root "$test_root/basic" --inspect >/dev/null 2>&1; then
  fail "empty .git directory was not rejected"
fi
rmdir "$test_root/basic/.git"

mkdir "$test_root/basic/.terraform"
if "$helper" --configuration-root "$test_root/basic" --inspect >/dev/null 2>&1; then
  fail "empty .terraform directory was not rejected"
fi
rmdir "$test_root/basic/.terraform"

touch "$test_root/basic/.terraformignore"
if "$helper" --configuration-root "$test_root/basic" --inspect >/dev/null 2>&1; then
  fail ".terraformignore was not rejected from staging"
fi
rm "$test_root/basic/.terraformignore"

ln -s main.tf "$test_root/basic/link.tf"
if "$helper" --configuration-root "$test_root/basic" --inspect >/dev/null 2>&1; then
  fail "symlink was not rejected"
fi

rm "$test_root/basic/link.tf"
chmod 755 "$test_root/basic"
if "$helper" --configuration-root "$test_root/basic" --inspect >/dev/null 2>&1; then
  fail "non-private staging directory was accepted"
fi
chmod 700 "$test_root/basic"

printf 'filesystem tests passed\n'
