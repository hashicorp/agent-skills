#!/usr/bin/env bash
# Copyright IBM Corp. 2025, 2026
# SPDX-License-Identifier: MPL-2.0

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ERRORS=0
EXPECTED_BUNDLES=$'packer\nterraform'

error() {
  printf 'ERROR: %s\n' "$1"
  ERRORS=$((ERRORS + 1))
}

ok() {
  printf 'OK: %s\n' "$1"
}

require_file() {
  if [[ -f "$1" ]]; then
    ok "found ${1#$REPO_ROOT/}"
  else
    error "missing ${1#$REPO_ROOT/}"
  fi
}

if ! command -v jq >/dev/null 2>&1; then
  printf 'jq is required but not installed.\n'
  exit 1
fi

cd "$REPO_ROOT" || exit 1

CLAUDE_MARKETPLACE="$REPO_ROOT/.claude-plugin/marketplace.json"
CODEX_MARKETPLACE="$REPO_ROOT/.agents/plugins/marketplace.json"

require_file "$CLAUDE_MARKETPLACE"
require_file "$CODEX_MARKETPLACE"
require_file "$REPO_ROOT/SKILLS.md"
require_file "$REPO_ROOT/SUPPORTED_MODELS.md"
require_file "$REPO_ROOT/CODEOWNERS"

while IFS= read -r json_file; do
  if jq empty "$json_file" >/dev/null 2>&1; then
    ok "valid JSON: ${json_file#./}"
  else
    error "invalid JSON: ${json_file#./}"
  fi
done < <(find . -type f -name '*.json' -not -path './.git/*' | sort)

if [[ -f "$CLAUDE_MARKETPLACE" && -f "$CODEX_MARKETPLACE" ]]; then
  CLAUDE_BUNDLES="$(jq -r '.plugins[].name' "$CLAUDE_MARKETPLACE" | sort)"
  CODEX_BUNDLES="$(jq -r '.plugins[].name' "$CODEX_MARKETPLACE" | sort)"

  [[ "$CLAUDE_BUNDLES" == "$EXPECTED_BUNDLES" ]] ||
    error "Claude marketplace must publish exactly packer and terraform"
  [[ "$CODEX_BUNDLES" == "$EXPECTED_BUNDLES" ]] ||
    error "Codex marketplace must publish exactly packer and terraform"
  [[ "$CLAUDE_BUNDLES" == "$CODEX_BUNDLES" ]] ||
    error "Claude and Codex marketplace bundle sets differ"

  [[ "$(jq '.plugins | length' "$CLAUDE_MARKETPLACE")" -eq 2 ]] ||
    error "Claude marketplace must contain exactly two entries"
  [[ "$(jq '.plugins | length' "$CODEX_MARKETPLACE")" -eq 2 ]] ||
    error "Codex marketplace must contain exactly two entries"

  for product in packer terraform; do
    plugin_root="$REPO_ROOT/plugins/$product"
    claude_manifest="$plugin_root/.claude-plugin/plugin.json"
    codex_manifest="$plugin_root/.codex-plugin/plugin.json"

    [[ "$(jq -r ".plugins[] | select(.name == \"$product\") | .source" "$CLAUDE_MARKETPLACE")" == "./plugins/$product" ]] ||
      error "Claude $product source must be ./plugins/$product"
    [[ "$(jq -r ".plugins[] | select(.name == \"$product\") | .source.path" "$CODEX_MARKETPLACE")" == "./plugins/$product" ]] ||
      error "Codex $product source must be ./plugins/$product"

    require_file "$claude_manifest"
    require_file "$codex_manifest"
    [[ -d "$plugin_root/skills" ]] || error "missing plugins/$product/skills"

    for manifest in "$claude_manifest" "$codex_manifest"; do
      [[ -f "$manifest" ]] || continue
      [[ "$(jq -r '.name // empty' "$manifest")" == "$product" ]] ||
        error "${manifest#$REPO_ROOT/} name must match product root"
      [[ "$(jq -r '.skills // empty' "$manifest")" == './skills/' ]] ||
        error "${manifest#$REPO_ROOT/} must reference ./skills/"
      jq -e '.version and .description and .author.name' "$manifest" >/dev/null ||
        error "${manifest#$REPO_ROOT/} lacks required metadata"
    done

    if [[ -f "$codex_manifest" ]]; then
      jq -e '.interface.displayName and .interface.shortDescription and
        .interface.longDescription and .interface.developerName and
        .interface.category and .interface.capabilities and
        .interface.defaultPrompt' "$codex_manifest" >/dev/null ||
        error "${codex_manifest#$REPO_ROOT/} lacks required interface metadata"
    fi
  done
fi

CLAUDE_MANIFEST_COUNT="$(find plugins -path '*/.claude-plugin/plugin.json' -type f | wc -l | tr -d ' ')"
CODEX_MANIFEST_COUNT="$(find plugins -path '*/.codex-plugin/plugin.json' -type f | wc -l | tr -d ' ')"
[[ "$CLAUDE_MANIFEST_COUNT" -eq 2 ]] || error "expected exactly two Claude plugin manifests"
[[ "$CODEX_MANIFEST_COUNT" -eq 2 ]] || error "expected exactly two Codex plugin manifests"

SKILL_COUNT="$(find plugins -path '*/skills/*/SKILL.md' -type f | wc -l | tr -d ' ')"
[[ "$SKILL_COUNT" -eq 20 ]] ||
  error "expected exactly 20 canonical Skills; found $SKILL_COUNT"

while IFS= read -r skill_file; do
  skill_dir="$(dirname "$skill_file")"
  skill_name="$(basename "$skill_dir")"
  product="$(printf '%s\n' "$skill_file" | cut -d/ -f2)"
  case "$product" in
    packer) product_label="Packer" ;;
    terraform) product_label="Terraform" ;;
    *) product_label="$product" ;;
  esac
  frontmatter="$(awk 'NR == 1 && $0 == "---" {inside=1; next} inside && $0 == "---" {exit} inside {print}' "$skill_file")"
  declared_name="$(printf '%s\n' "$frontmatter" | sed -n 's/^name:[[:space:]]*//p' | head -1)"
  lifecycle="$(printf '%s\n' "$frontmatter" | sed -n 's/^  lifecycle-status:[[:space:]]*//p' | head -1)"
  relative_dir="${skill_dir#./}"

  [[ "$declared_name" == "$skill_name" ]] ||
    error "$skill_file name does not match directory"
  printf '%s\n' "$frontmatter" | grep -q '^description:' ||
    error "$skill_file missing description"
  case "$lifecycle" in
    active|deprecation-candidate|deprecated|retired) ;;
    *) error "$skill_file has invalid or missing metadata.lifecycle-status" ;;
  esac

  expected_catalog="| $product_label | \`$skill_name\` | \`$lifecycle\` | \`$relative_dir\` |"
  grep -Fqx "$expected_catalog" SKILLS.md ||
    error "SKILLS.md missing aligned row for $relative_dir"
  grep -Fqx "/$relative_dir/ @hashicorp/team-agent-skills-ecosystem" CODEOWNERS ||
    error "CODEOWNERS missing explicit ecosystem ownership for $relative_dir"
done < <(find plugins -path '*/skills/*/SKILL.md' -type f | sort)

CATALOG_ROWS="$(grep -Ec '^\| (Packer|Terraform) \|' SKILLS.md || true)"
[[ "$CATALOG_ROWS" -eq 20 ]] || error "SKILLS.md must contain exactly 20 Skill rows"

if find plugins -type d -name evals -print -quit | grep -q .; then
  error "public Skill evaluation assets are forbidden; keep them in proj-agent-skills/evals"
fi

LEGACY_IDS=(
  "terraform-code""-generation"
  "terraform-module""-generation"
  "terraform-provider""-development"
  "terraform-policy""-code"
  "packer""-builders"
  "packer""-hcp"
)

for legacy_id in "${LEGACY_IDS[@]}"; do
  while IFS= read -r matched_file; do
    case "$matched_file" in
      ./README.md|./CHANGELOG.md) ;;
      *) error "legacy plugin id $legacy_id remains outside migration guidance: $matched_file" ;;
    esac
  done < <(grep -RIl --exclude-dir=.git --exclude='README.md' --exclude='CHANGELOG.md' "$legacy_id" . 2>/dev/null || true)
done

if [[ "$ERRORS" -gt 0 ]]; then
  printf 'Validation failed with %d error(s).\n' "$ERRORS"
  exit 1
fi

printf 'Validation passed for two marketplaces, two bundles, and 20 Skills.\n'
