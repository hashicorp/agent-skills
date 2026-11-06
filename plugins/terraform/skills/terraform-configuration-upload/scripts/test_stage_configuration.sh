#!/usr/bin/env bash
# Offline tests for explicit Terraform staging.

set -Eeuo pipefail
IFS=$'\n\t'

script_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
helper="$script_dir/stage_configuration.sh"
test_root=$(mktemp -d "${TMPDIR:-/tmp}/terraform-stage-test.XXXXXX")
trap 'rm -rf "$test_root"' EXIT HUP INT TERM

fail() {
  printf 'staging test failed: %s\n' "$1" >&2
  exit 1
}

command -v jq >/dev/null 2>&1 || fail "jq is required"

mkdir -p "$test_root/source/modules/example" "$test_root/staging"
chmod 700 "$test_root/staging"
printf 'terraform {}\n' >"$test_root/source/main.tf"
printf 'module "example" {}\n' >"$test_root/source/modules/example/main.tf"
printf 'not selected\n' >"$test_root/source/README.md"

result=$(
  "$helper" \
    --source-root "$test_root/source" \
    --staging-root "$test_root/staging" \
    --include main.tf \
    --include modules/example
)
[ "$(printf '%s' "$result" | jq -r '.status')" = staged ] || fail "staging was not successful"
[ "$(printf '%s' "$result" | jq -r '.files | join(",")')" = 'main.tf,modules/example/main.tf' ] || fail "unexpected staged file list"
[ -f "$test_root/staging/main.tf" ] || fail "main.tf was not staged"
[ ! -e "$test_root/staging/README.md" ] || fail "unselected file was staged"

if "$helper" --source-root "$test_root/source" --staging-root "$test_root/staging" --include README.md >/dev/null 2>&1; then
  fail "non-empty staging directory was accepted"
fi

rm -rf "$test_root/staging" && mkdir "$test_root/staging"
printf 'secret\n' >"$test_root/source/.env"
if "$helper" --source-root "$test_root/source" --staging-root "$test_root/staging" --include .env >/dev/null 2>&1; then
  fail "prohibited file was staged"
fi

rm -rf "$test_root/staging" && mkdir "$test_root/staging"
mkdir -p "$test_root/source/modules/example/.terraform"
if "$helper" --source-root "$test_root/source" --staging-root "$test_root/staging" --include modules/example >/dev/null 2>&1; then
  fail "nested prohibited directory was staged"
fi
rm -rf "$test_root/source/modules/example/.terraform"

rm -rf "$test_root/staging" && mkdir "$test_root/staging"
ln -s main.tf "$test_root/source/link.tf"
if "$helper" --source-root "$test_root/source" --staging-root "$test_root/staging" --include link.tf >/dev/null 2>&1; then
  fail "symlink was staged"
fi

rm -rf "$test_root/staging" && mkdir "$test_root/staging"
chmod 755 "$test_root/staging"
if "$helper" --source-root "$test_root/source" --staging-root "$test_root/staging" --include main.tf >/dev/null 2>&1; then
  fail "non-private staging directory was accepted"
fi
chmod 700 "$test_root/staging"

rm -rf "$test_root/source/nested-staging"
mkdir "$test_root/source/nested-staging"
if "$helper" --source-root "$test_root/source" --staging-root "$test_root/source/nested-staging" --include main.tf >/dev/null 2>&1; then
  fail "staging directory inside source was accepted"
fi
rm -rf "$test_root/source/nested-staging"

rm -rf "$test_root/staging" && mkdir "$test_root/staging" && chmod 700 "$test_root/staging"
mkdir "$test_root/source/empty"
if "$helper" --source-root "$test_root/source" --staging-root "$test_root/staging" --include empty >/dev/null 2>&1; then
  fail "empty selection was accepted"
fi
rm -rf "$test_root/source/empty"

rm -rf "$test_root/staging" && mkdir -p "$test_root/staging/nested-source"
printf 'terraform {}\n' >"$test_root/staging/nested-source/main.tf"
chmod 700 "$test_root/staging" "$test_root/staging/nested-source"
chmod 600 "$test_root/staging/nested-source/main.tf"
if "$helper" --source-root "$test_root/staging/nested-source" --staging-root "$test_root/staging" --include main.tf >/dev/null 2>&1; then
  fail "source directory inside staging was accepted"
fi

printf 'staging tests passed\n'
