#!/usr/bin/env bash
# Offline API transport, lifecycle, and secret-containment test.

set -Eeuo pipefail
IFS=$'\n\t'

script_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
helper="$script_dir/upload_configuration.sh"
test_root=$(mktemp -d "${TMPDIR:-/tmp}/terraform-upload-mock-test.XXXXXX")
trap 'rm -rf "$test_root"' EXIT HUP INT TERM

fail() {
  printf 'mock test failed: %s\n' "$1" >&2
  exit 1
}

command -v jq >/dev/null 2>&1 || fail "jq is required"

fake_bin="$test_root/bin"
mkdir -p "$fake_bin"
fake_argv="$test_root/curl-argv"
fake_configs="$test_root/curl-configs"
fake_upload_config="$test_root/upload-config"
fake_tfctl_log="$test_root/tfctl-log"

cat >"$fake_bin/curl" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail

for arg in "$@"; do
  printf '<%s>\n' "$arg" >>"$FAKE_CURL_ARGV"
done

config=''
while [ "$#" -gt 0 ]; do
  case "$1" in
    --config) config=$2; shift 2 ;;
    *) shift ;;
  esac
done
[ -n "$config" ] || exit 2
url=$(sed -n 's/^url = "\(.*\)"$/\1/p' "$config")
output=$(sed -n 's/^output = "\(.*\)"$/\1/p' "$config")

if [[ "$url" == https://upload.example.test/* ]]; then
  cp "$config" "$FAKE_UPLOAD_CONFIG"
else
  cat "$config" >>"$FAKE_CURL_CONFIGS"
  printf '\n---\n' >>"$FAKE_CURL_CONFIGS"
fi

case "$url" in
  */organizations/*/workspaces/*)
    printf '%s\n' '{"data":{"id":"ws-123"}}' >"$output"
    ;;
  */workspaces/ws-123/configuration-versions)
    printf '%s\n' '{"data":{"id":"cv-123","attributes":{"status":"pending","upload-url":"https://upload.example.test/one-use?signature=fixture-signed-url"}}}' >"$output"
    ;;
  https://upload.example.test/*)
    : >"$output"
    ;;
  */configuration-versions/cv-123)
    printf '%s\n' '{"data":{"id":"cv-123","attributes":{"status":"uploaded"}}}' >"$output"
    ;;
  *)
    printf '%s\n' '{"errors":[{"title":"unexpected fake request"}]}' >"$output"
    printf '404'
    exit 0
    ;;
esac

printf '200'
EOF
chmod 700 "$fake_bin/curl"

cat >"$fake_bin/tfctl" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail

if [ "${1:-}" = '--version' ]; then
  printf 'v0.4.0\n'
  exit 0
fi

printf 'config=%s host=%s organization=%s token=%s args=%s\n' \
  "${TFCTL_CONFIG_DIR:-}" "${TFCTL_HOSTNAME:-}" "${TFCTL_ORGANIZATION:-}" \
  "${TFCTL_TOKEN:+present}" "$*" >>"$FAKE_TFCTL_LOG"

path=''
while [ "$#" -gt 0 ]; do
  if [ "$1" = 'api' ]; then
    shift
    path=${1:-}
    break
  fi
  shift
done
path=${path#https://app.terraform.io/api/v2}

case "$path" in
  /organizations/*/workspaces/*)
    printf '%s\n' '{"data":{"id":"ws-tfctl-123"}}'
    ;;
  /workspaces/ws-tfctl-123/configuration-versions)
    printf '%s\n' '{"data":{"id":"cv-tfctl-123","attributes":{"status":"pending","upload-url":"https://upload.example.test/tfctl?signature=fixture-tfctl-signed-url"}}}'
    ;;
  /configuration-versions/cv-tfctl-123)
    printf '%s\n' '{"data":{"id":"cv-tfctl-123","attributes":{"status":"uploaded"}}}'
    ;;
  *)
    printf 'unexpected tfctl API path: %s\n' "$path" >&2
    exit 1
    ;;
esac
EOF
chmod 700 "$fake_bin/tfctl"

mkdir -p "$test_root/config"
printf 'terraform {}\n' >"$test_root/config/main.tf"
chmod 700 "$test_root/config" && chmod 600 "$test_root/config/main.tf"
token='fixture-api-token'

if TFE_TOKEN="$token" "$helper" \
  --configuration-root "$test_root/config" \
  --organization example-org \
  --workspace example-workspace \
  --address 'https://user@example.test' \
  --upload >/dev/null 2>&1; then
  fail "endpoint containing userinfo was accepted"
fi

signed_url='fixture-signed-url'
tfctl_signed_url='fixture-tfctl-signed-url'
if ! result=$(
  PATH="$fake_bin:$PATH" \
  FAKE_CURL_ARGV="$fake_argv" \
  FAKE_CURL_CONFIGS="$fake_configs" \
  FAKE_UPLOAD_CONFIG="$fake_upload_config" \
  FAKE_TFCTL_LOG="$fake_tfctl_log" \
  TFE_TOKEN="$token" \
    "$helper" \
      --configuration-root "$test_root/config" \
      --organization example-org \
      --workspace example-workspace \
      --upload
) 2>"$test_root/tfctl.err"; then
  fail "tfctl-preferred mock upload did not succeed"
fi

[ "$(printf '%s' "$result" | jq -r '.configuration_version_id')" = 'cv-tfctl-123' ] \
  || fail "tfctl-preferred upload returned the wrong configuration version"
grep -Fq 'token=present' "$fake_tfctl_log" \
  || fail "tfctl did not receive the token through its environment"
grep -Fq 'host=app.terraform.io' "$fake_tfctl_log" \
  || fail "tfctl did not receive the validated API host"
grep -Fq "$tfctl_signed_url" "$fake_upload_config" \
  || fail "curl did not upload the tfctl-issued signed URL"
if [ -s "$fake_configs" ]; then
  fail "curl was used for API requests when tfctl was available"
fi

# An installed but too-old tfctl must select the curl API fallback.
sed -i.bak 's/v0\.4\.0/v0.3.0/' "$fake_bin/tfctl"
rm -f "$fake_bin/tfctl.bak" "$fake_configs" "$fake_upload_config" "$fake_argv"

if ! result=$(
  PATH="$fake_bin:$PATH" \
  FAKE_CURL_ARGV="$fake_argv" \
  FAKE_CURL_CONFIGS="$fake_configs" \
  FAKE_UPLOAD_CONFIG="$fake_upload_config" \
  FAKE_TFCTL_LOG="$fake_tfctl_log" \
  TFE_TOKEN="$token" \
    "$helper" \
      --configuration-root "$test_root/config" \
      --organization example-org \
      --workspace example-workspace \
      --upload
) 2>"$test_root/upload.err"; then
  fail "mock upload did not succeed"
fi

[ "$(printf '%s' "$result" | jq -r '.configuration_version_id')" = 'cv-123' ] \
  || fail "mock upload returned the wrong configuration version"

grep -Fq 'Authorization: Bearer fixture-api-token' "$fake_configs" \
  || fail "curl fallback did not handle API requests"

if grep -Fq "$token" "$fake_argv" || grep -Fq "$signed_url" "$fake_argv"; then
  fail "token or signed URL appeared in curl argv"
fi
if printf '%s' "$result" | grep -Fq "$token" || printf '%s' "$result" | grep -Fq "$signed_url"; then
  fail "token or signed URL appeared in stdout"
fi
if grep -Fq "$token" "$test_root/upload.err" || grep -Fq "$signed_url" "$test_root/upload.err"; then
  fail "token or signed URL appeared in stderr"
fi

grep -Fq 'Content-Type: application/octet-stream' "$fake_upload_config" \
  || fail "upload request did not use octet-stream"
if grep -Fq 'Authorization: Bearer' "$fake_upload_config"; then
  fail "signed upload request contained bearer authorization"
fi

printf 'API security tests passed\n'
