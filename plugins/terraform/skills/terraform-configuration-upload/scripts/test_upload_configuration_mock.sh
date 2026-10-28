#!/usr/bin/env bash
# Offline API lifecycle and secret-containment test.

set -Eeuo pipefail
IFS=$'\n\t'

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
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
if ! result=$(
  PATH="$fake_bin:$PATH" \
  FAKE_CURL_ARGV="$fake_argv" \
  FAKE_CURL_CONFIGS="$fake_configs" \
  FAKE_UPLOAD_CONFIG="$fake_upload_config" \
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

if grep -Fq "$token" "$fake_argv" || grep -Fq "$signed_url" "$fake_argv"; then
  fail "token or signed URL appeared in curl argv"
fi
if printf '%s' "$result" | grep -Fq "$token" || printf '%s' "$result" | grep -Fq "$signed_url"; then
  fail "token or signed URL appeared in stdout"
fi
if grep -Fq "$token" "$test_root/upload.err" || grep -Fq "$signed_url" "$test_root/upload.err"; then
  fail "token or signed URL appeared in stderr"
fi

grep -Fq 'Authorization: Bearer fixture-api-token' "$fake_configs" \
  || fail "API request did not contain authorization in its private config"
grep -Fq 'Content-Type: application/octet-stream' "$fake_upload_config" \
  || fail "upload request did not use octet-stream"
if grep -Fq 'Authorization: Bearer' "$fake_upload_config"; then
  fail "signed upload request contained bearer authorization"
fi

printf 'API security tests passed\n'
