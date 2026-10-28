#!/usr/bin/env bash
# Copy an explicit Terraform file selection into a private staging directory.

set -Eeuo pipefail
IFS=$'\n\t'
umask 077

usage() {
  cat >&2 <<'EOF'
usage: stage_configuration.sh --source-root DIR --staging-root DIR \
  --include RELATIVE_PATH [--include RELATIVE_PATH ...]

Copies only explicitly selected regular files and directories. It does not
interpret .terraformignore, discover dependencies, create archives, or upload.
EOF
}

fail() {
  printf 'configuration staging failed: %s\n' "$1" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "required command is unavailable"
}

source_root=''
staging_root=''
includes=()
max_files=10000
max_file_bytes=52428800
max_total_bytes=524288000
staged_files=0
staged_bytes=0

while [ "$#" -gt 0 ]; do
  case "$1" in
    --source-root)
      [ "$#" -ge 2 ] || { usage; exit 2; }
      source_root=$2
      shift 2
      ;;
    --staging-root)
      [ "$#" -ge 2 ] || { usage; exit 2; }
      staging_root=$2
      shift 2
      ;;
    --include)
      [ "$#" -ge 2 ] || { usage; exit 2; }
      includes+=("$2")
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

[ -n "$source_root" ] || { usage; exit 2; }
[ -n "$staging_root" ] || { usage; exit 2; }
[ "${#includes[@]}" -gt 0 ] || { usage; exit 2; }
[ -d "$source_root" ] || fail "source root is not a directory"
[ ! -L "$source_root" ] || fail "source root must not be a symlink"
[ -d "$staging_root" ] || fail "staging root is not a directory"
[ ! -L "$staging_root" ] || fail "staging root must not be a symlink"

require_command find
require_command sort
require_command jq
require_command stat
require_command cp
require_command mkdir
require_command dirname
require_command grep
require_command sed
require_command tr
require_command wc
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

require_private_path "$staging_root"

source_real=$(CDPATH= cd -- "$source_root" && pwd -P) || fail "could not resolve source root"
staging_real=$(CDPATH= cd -- "$staging_root" && pwd -P) || fail "could not resolve staging root"
case "$staging_real/" in
  "$source_real/"*) fail "source and staging roots must not overlap" ;;
esac
case "$source_real/" in
  "$staging_real/"*) fail "source and staging roots must not overlap" ;;
esac

if find "$staging_root" -mindepth 1 -print -quit | grep -q .; then
  fail "staging root must be empty"
fi

validate_relative_path() {
  case "$1" in
    ''|.|./*|/*|../*|*/../*|*/..|-*|*/-*) fail "unsafe source path" ;;
    *$'\n'*|*$'\t'*) fail "unsupported source path" ;;
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

copy_file() {
  local source=$1 relative=$2 destination size
  validate_relative_path "$relative"
  is_forbidden_path "$relative" && fail "selected path is prohibited"
  [ -f "$source" ] || fail "selected path is not a regular file"
  if stat -f '%u %Lp' "$source" 2>/dev/null | grep -Eq '^[0-9]+ [0-7]{3,4}$'; then
    size=$(stat -f '%z' "$source")
  else
    size=$(stat -c '%s' "$source")
  fi
  [ -n "$size" ] || fail "could not inspect selected file"
  [ "$size" -le "$max_file_bytes" ] || fail "selected file is too large"
  [ "$((staged_bytes + size))" -le "$max_total_bytes" ] || fail "selected files are too large"
  [ "$((staged_files + 1))" -le "$max_files" ] || fail "too many selected files"
  destination="$staging_root/$relative"
  [ ! -e "$destination" ] || fail "staging selection would overwrite a file"
  mkdir -p "$(dirname "$destination")"
  cp -p "$source" "$destination" || fail "could not copy selected file"
  chmod 600 "$destination" || fail "could not protect staged file"
  staged_files=$((staged_files + 1))
  staged_bytes=$((staged_bytes + size))
}

copy_selection() {
  local include=$1 source path relative destination
  validate_relative_path "$include"
  is_forbidden_path "$include" && fail "selected path is prohibited"
  source="$source_root/$include"
  [ -e "$source" ] || fail "selected path does not exist"
  [ ! -L "$source" ] || fail "selected path is a symlink"

  if [ -f "$source" ]; then
    copy_file "$source" "$include"
    return
  fi
  [ -d "$source" ] || fail "selected path is not a regular file or directory"

  while IFS= read -r -d '' path; do
    relative=${path#"$source_root"/}
    validate_relative_path "$relative"
    is_forbidden_path "$relative" && fail "selected path contains a prohibited entry"
    [ ! -L "$path" ] || fail "selected path contains a symlink"
    if [ -d "$path" ]; then
      destination="$staging_root/$relative"
      [ ! -e "$destination" ] || fail "staging selection would overwrite a path"
      mkdir -p "$destination"
      chmod 700 "$destination" || fail "could not protect staged directory"
    elif [ -f "$path" ]; then
      copy_file "$path" "$relative"
    else
      fail "selected path contains an unsupported file type"
    fi
  done < <(find "$source" -mindepth 1 -print0)
}

for include in "${includes[@]}"; do
  copy_selection "$include"
done

[ "$staged_files" -gt 0 ] || fail "selected paths produced no regular files"

file_list=$(mktemp "${TMPDIR:-/tmp}/terraform-upload-stage-list.XXXXXX") || fail "could not create file list"
trap 'rm -f "$file_list"' EXIT HUP INT TERM
find "$staging_root" -type f -print | sed "s#^$staging_root/##" | LC_ALL=C sort >"$file_list"
jq -n --argjson files "$(jq -R -s 'split("\n") | map(select(length > 0))' "$file_list")" \
  --argjson file_count "$(wc -l <"$file_list" | tr -d '[:space:]')" \
  '{status: "staged", files: $files, file_count: $file_count}'
