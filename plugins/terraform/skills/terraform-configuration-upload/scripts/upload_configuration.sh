#!/usr/bin/env bash
# Terraform configuration preparation and upload helper.
# Requires: Bash, find, sort, tar, mktemp, wc, jq, stat, sed, grep, diff, tr,
# and env. Upload mode also requires curl and sleep.

set -Eeuo pipefail
IFS=$'\n\t'
umask 077

usage() {
  cat >&2 <<'EOF'
usage: upload_configuration.sh --configuration-root DIR --inspect
       upload_configuration.sh --configuration-root DIR --upload \
         --organization ORG --workspace WORKSPACE [--address URL]

This helper validates a caller-prepared private staging directory and creates a temporary
root-level tar.gz archive. Inspect mode is offline and returns the included
relative file list. Upload mode creates a speculative HCP Terraform
configuration version with automatic Run queueing disabled, uploads the archive,
and waits for the configuration version to become usable.

Upload mode reads the API token from TFE_TOKEN and never prints the token,
signed upload URL, archive, or raw API responses.
EOF
}

fail() {
  printf 'configuration upload helper failed: %s\n' "$1" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "required command is unavailable"
}

configuration_root=''
inspect=0
upload=0
address=${TFE_ADDRESS:-https://app.terraform.io}
organization=''
workspace=''
max_files=10000
max_file_bytes=52428800
max_total_bytes=524288000

while [ "$#" -gt 0 ]; do
  case "$1" in
    --configuration-root)
      [ "$#" -ge 2 ] || { usage; exit 2; }
      configuration_root=$2
      shift 2
      ;;
    --inspect)
      inspect=1
      shift
      ;;
    --upload)
      upload=1
      shift
      ;;
    --address)
      [ "$#" -ge 2 ] || { usage; exit 2; }
      address=$2
      shift 2
      ;;
    --organization)
      [ "$#" -ge 2 ] || { usage; exit 2; }
      organization=$2
      shift 2
      ;;
    --workspace)
      [ "$#" -ge 2 ] || { usage; exit 2; }
      workspace=$2
      shift 2
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      usage
      exit 2
      ;;
  esac
done

[ -n "$configuration_root" ] || { usage; exit 2; }
[ "$inspect" -eq 1 ] && [ "$upload" -eq 1 ] && fail "choose either --inspect or --upload"
[ "$inspect" -eq 0 ] && [ "$upload" -eq 0 ] && fail "one of --inspect or --upload is required"
[ -d "$configuration_root" ] || fail "configuration root is not a directory"
case "$configuration_root" in
  /) ;;
  */) configuration_root=${configuration_root%/} ;;
esac

if [ "$upload" -eq 1 ]; then
  [ -n "$organization" ] || fail "--organization is required for upload"
  [ -n "$workspace" ] || fail "--workspace is required for upload"
  [ -n "${TFE_TOKEN:-}" ] || fail "TFE_TOKEN is required for upload"
  require_command curl
  require_command sleep
fi

address=${address%/}
[ -n "$address" ] || fail "HCP Terraform address is invalid"
case "$address" in
  https://?*) ;;
  *) fail "HCP Terraform address must use HTTPS" ;;
esac
address_authority=${address#https://}
case "$address_authority" in
  ''|*[/?#@]*) fail "HCP Terraform address must contain only a hostname and optional port" ;;
esac
if [[ "$address_authority" == *:* ]]; then
  address_host=${address_authority%%:*}
  address_port=${address_authority#*:}
  case "$address_port" in
    ''|*[!0-9]*) fail "HCP Terraform address port is invalid" ;;
  esac
  [ "$((10#$address_port))" -ge 1 ] && [ "$((10#$address_port))" -le 65535 ] \
    || fail "HCP Terraform address port is invalid"
else
  address_host=$address_authority
fi
case "$address_host" in
  ''|.*|*.|-*|*-|*[!A-Za-z0-9.-]*) fail "HCP Terraform address hostname is invalid" ;;
esac
case "$address_host" in
  *[!0-9.]* ) ;;
  *) fail "IP-literal HCP Terraform addresses are unsupported" ;;
esac

require_command find
require_command sort
require_command tar
require_command mktemp
require_command wc
require_command jq
require_command stat
require_command tr
require_command sed
require_command grep
require_command diff
require_command env
require_command id

private_metadata() {
  if stat -f '%u %Lp' "$1" 2>/dev/null | grep -Eq '^[0-9]+ [0-7]{3,4}$'; then
    stat -f '%u %Lp' "$1"
  else
    stat -c '%u %a' "$1"
  fi
}

require_private_path() {
  local path=$1 owner mode
  IFS=' ' read -r owner mode <<<"$(private_metadata "$path")" || fail "could not inspect staging permissions"
  [ "$owner" = "$(id -u)" ] || fail "staging path is not owned by the current user"
  (( (8#$mode & 077) == 0 )) || fail "staging path is not private"
}

tmp_dir=$(mktemp -d "${TMPDIR:-/tmp}/terraform-upload.XXXXXX") || fail "could not create temporary directory"
cleanup() { rm -rf "$tmp_dir"; }
trap cleanup EXIT HUP INT TERM
require_private_path "$configuration_root"

file_list="$tmp_dir/file-list"
archive="$tmp_dir/configuration.tar.gz"
api_response="$tmp_dir/api-response"
api_error="$tmp_dir/api-error"
curl_config="$tmp_dir/curl-config"

curl_config_value() {
  jq -rn --arg value "$1" '$value | @json'
}

run_curl() {
  local method=$1 url=$2 output=$3 content_type=$4 body_file=${5:-} response_code

  : >"$curl_config"
  {
    printf 'url = %s\n' "$(curl_config_value "$url")"
    printf 'request = %s\n' "$(curl_config_value "$method")"
    printf 'max-time = 300\n'
    printf 'output = %s\n' "$(curl_config_value "$output")"
    printf 'write-out = %s\n' "$(curl_config_value '%{http_code}')"
    printf 'header = %s\n' "$(curl_config_value "$content_type")"
    if [ "$method" != "PUT" ]; then
      printf 'header = %s\n' "$(curl_config_value "Authorization: Bearer $TFE_TOKEN")"
      printf 'header = %s\n' "$(curl_config_value 'Accept: application/vnd.api+json')"
    fi
    if [ -n "$body_file" ]; then
      printf 'data-binary = %s\n' "$(curl_config_value "@$body_file")"
    fi
  } >"$curl_config"

  # Keep sensitive curl inputs in owner-only files, not child argv.
  response_code=$(env -u TFE_TOKEN curl -q --config "$curl_config" 2>"$api_error") \
    || fail "HCP Terraform API request failed"
  printf '%s' "$response_code"
}

file_size() {
  if stat -f '%u %Lp' "$1" 2>/dev/null | grep -Eq '^[0-9]+ [0-7]{3,4}$'; then
    stat -f '%z' "$1"
  else
    stat -c '%s' "$1"
  fi
}

url_encode() {
  jq -rn --arg value "$1" '$value | @uri'
}

api_call() {
  local method=$1 url=$2 body=${3:-} response_code body_file=''
  if [ -n "$body" ]; then
    body_file="$tmp_dir/request-body"
    printf '%s' "$body" >"$body_file"
    response_code=$(run_curl "$method" "$url" "$api_response" \
      'Content-Type: application/vnd.api+json' "$body_file")
  else
    response_code=$(run_curl "$method" "$url" "$api_response" \
      'Accept: application/vnd.api+json')
  fi
  case "$response_code" in
    2??) ;;
    *) fail "HCP Terraform API request returned an unexpected status" ;;
  esac
}

upload_archive() {
  local upload_url=$1 response_code
  response_code=$(run_curl PUT "$upload_url" /dev/null \
    'Content-Type: application/octet-stream' "$archive") || fail "configuration upload failed"
  case "$response_code" in
    2??) ;;
    *) fail "configuration upload returned an unexpected status" ;;
  esac
}

validate_relative_path() {
  case "$1" in
    ''|/*|../*|*/../*|*/..|.|./*) fail "unsafe staged path" ;;
    -*|*/-*) fail "unsupported staged path" ;;
    *$'\n'*|*$'\t'*) fail "unsupported staged path" ;;
  esac
}

is_forbidden_path() {
  case "$1" in
    .git|*/.git|.git/*|*/.git/*|.terraform|*/.terraform|.terraform/*|*/.terraform/*|.terraformignore|*/.terraformignore|*.tfstate|*.tfstate.*|crash.log|crash.*.log|.env|*/.env|.env.*|*/.env.*|*.pem|*.key|credentials.tfrc.json)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

build_file_list() {
  local output=$1
  local path relative size total_bytes=0 count=0
  : >"$output"

  while IFS= read -r -d '' path; do
    relative=${path#"$configuration_root"/}
    validate_relative_path "$relative"
    is_forbidden_path "$relative" && fail "staging directory contains a prohibited file"
    require_private_path "$path"
    size=$(file_size "$path") || fail "could not inspect staged file"
    [ "$size" -le "$max_file_bytes" ] || fail "staging directory contains an oversized file"
    total_bytes=$((total_bytes + size))
    [ "$total_bytes" -le "$max_total_bytes" ] || fail "staging directory is too large"
    count=$((count + 1))
    [ "$count" -le "$max_files" ] || fail "staging directory contains too many files"
    printf '%s\n' "$relative" >>"$output"
  done < <(find "$configuration_root" -type f -print0)

  while IFS= read -r -d '' path; do
    relative=${path#"$configuration_root"/}
    validate_relative_path "$relative"
    require_private_path "$path"
    fail "staging directory contains an unsupported file type"
  done < <(find "$configuration_root" \( -type l -o -type b -o -type c -o -type p -o -type s \) -print0)

  while IFS= read -r -d '' path; do
    relative=${path#"$configuration_root"/}
    validate_relative_path "$relative"
    is_forbidden_path "$relative" && fail "staging directory contains a prohibited path"
    require_private_path "$path"
  done < <(find "$configuration_root" -mindepth 1 -type d -print0)

  LC_ALL=C sort -u "$output" -o "$output"
}

build_file_list "$file_list"
file_count=$(wc -l <"$file_list" | tr -d '[:space:]')
[ "$file_count" -gt 0 ] || fail "configuration directory contains no files"

if [ "$inspect" -eq 1 ]; then
  jq -n --arg status ready --slurpfile files <(jq -R . "$file_list") \
    --argjson file_count "$file_count" \
    '{status: $status, files: $files, file_count: $file_count}'
  exit 0
fi

# Archive validated staging files at the archive root.
tar -czf "$archive" -C "$configuration_root" -T "$file_list" || fail "could not create archive"

archive_bytes=$(file_size "$archive") || fail "could not inspect archive"

archive_files="$tmp_dir/archive-files"
tar -tzf "$archive" | sed 's#^\./##; s#/$##' | grep -v '^$' | LC_ALL=C sort -u >"$archive_files" \
  || fail "could not inspect archive members"
if ! diff -u "$file_list" "$archive_files" >/dev/null 2>&1; then
  fail "archive members did not match the reviewed file list"
fi

if [ "$upload" -eq 1 ]; then
  encoded_organization=$(url_encode "$organization") || fail "could not encode organization"
  encoded_workspace=$(url_encode "$workspace") || fail "could not encode workspace"

  api_call GET "$address/api/v2/organizations/$encoded_organization/workspaces/$encoded_workspace"
  workspace_id=$(jq -er '.data.id // empty' "$api_response" 2>/dev/null) || fail "target workspace could not be resolved"

  create_body=$(jq -cn \
    '{data:{type:"configuration-versions",attributes:{"auto-queue-runs":false,speculative:true}}}')
  api_call POST "$address/api/v2/workspaces/$(url_encode "$workspace_id")/configuration-versions" "$create_body"
  configuration_version_id=$(jq -er '.data.id // empty' "$api_response" 2>/dev/null) || fail "configuration version creation was not confirmed"
  upload_url=$(jq -er '.data.attributes["upload-url"] // empty' "$api_response" 2>/dev/null) || fail "configuration upload capability was not confirmed"

  upload_archive "$upload_url"

  uploaded=0
  for ((attempt = 1; attempt <= 30; attempt++)); do
    api_call GET "$address/api/v2/configuration-versions/$(url_encode "$configuration_version_id")"
    status=$(jq -r '.data.attributes.status // empty' "$api_response")
    case "$status" in
      uploaded)
        uploaded=1
        break
        ;;
      errored|archived)
        fail "configuration version did not become usable"
        ;;
    esac
    sleep 2
  done
  [ "$uploaded" -eq 1 ] || fail "configuration version upload did not complete before timeout"

  jq -n \
    --arg configuration_version_id "$configuration_version_id" \
    --arg upload_status uploaded \
    --argjson file_count "$file_count" \
    --argjson archive_bytes "$archive_bytes" \
    '{configuration_version_id: $configuration_version_id, upload_status: $upload_status, file_count: $file_count, archive_bytes: $archive_bytes}'
fi
