#!/bin/bash
#
# Validates the agent-skills repository structure
# Ensures all plugins and skills follow the expected format
#

set -e

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ERRORS=0

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_error() {
    echo -e "${RED}ERROR:${NC} $1"
    ERRORS=$((ERRORS + 1))
}

log_success() {
    echo -e "${GREEN}OK:${NC} $1"
}

log_info() {
    echo -e "${YELLOW}INFO:${NC} $1"
}

# Check if jq is available
if ! command -v jq &> /dev/null; then
    echo "jq is required but not installed. Please install jq."
    exit 1
fi

echo "=========================================="
echo "Validating agent-skills repository structure"
echo "=========================================="
echo ""

# ---------------------------------------------
# 1. Validate marketplace.json
# ---------------------------------------------
echo "1. Checking marketplace.json..."

MARKETPLACE_FILE="$REPO_ROOT/.claude-plugin/marketplace.json"

if [[ ! -f "$MARKETPLACE_FILE" ]]; then
    log_error "marketplace.json not found at $MARKETPLACE_FILE"
else
    # Check if valid JSON
    if ! jq empty "$MARKETPLACE_FILE" 2>/dev/null; then
        log_error "marketplace.json is not valid JSON"
    else
        log_success "marketplace.json is valid JSON"

        # Check required fields
        NAME=$(jq -r '.name // empty' "$MARKETPLACE_FILE")
        if [[ -z "$NAME" ]]; then
            log_error "marketplace.json missing 'name' field"
        else
            log_success "marketplace.json has name: $NAME"
        fi

        OWNER=$(jq -r '.owner.name // empty' "$MARKETPLACE_FILE")
        if [[ -z "$OWNER" ]]; then
            log_error "marketplace.json missing 'owner.name' field"
        else
            log_success "marketplace.json has owner: $OWNER"
        fi

        # Check plugins array exists
        PLUGINS_COUNT=$(jq '.plugins | length' "$MARKETPLACE_FILE")
        if [[ "$PLUGINS_COUNT" -eq 0 ]]; then
            log_error "marketplace.json has no plugins defined"
        else
            log_success "marketplace.json has $PLUGINS_COUNT plugin(s) defined"
        fi
    fi
fi

echo ""

# ---------------------------------------------
# 2. Validate each plugin referenced in marketplace
# ---------------------------------------------
echo "2. Checking plugins referenced in marketplace.json..."

if [[ -f "$MARKETPLACE_FILE" ]]; then
    PLUGIN_SOURCES=$(jq -r '.plugins[].source' "$MARKETPLACE_FILE" 2>/dev/null)

    for SOURCE in $PLUGIN_SOURCES; do
        # Remove leading ./ if present
        SOURCE_PATH="${SOURCE#./}"
        PLUGIN_DIR="$REPO_ROOT/$SOURCE_PATH"
        PLUGIN_JSON="$PLUGIN_DIR/.claude-plugin/plugin.json"

        echo ""
        log_info "Checking plugin: $SOURCE_PATH"

        # Check plugin directory exists
        if [[ ! -d "$PLUGIN_DIR" ]]; then
            log_error "Plugin directory not found: $PLUGIN_DIR"
            continue
        else
            log_success "Plugin directory exists"
        fi

        # Check plugin.json exists
        if [[ ! -f "$PLUGIN_JSON" ]]; then
            log_error "plugin.json not found: $PLUGIN_JSON"
            continue
        else
            log_success "plugin.json exists"
        fi

        # Validate plugin.json
        if ! jq empty "$PLUGIN_JSON" 2>/dev/null; then
            log_error "plugin.json is not valid JSON: $PLUGIN_JSON"
            continue
        else
            log_success "plugin.json is valid JSON"
        fi

        # Check required fields in plugin.json
        PLUGIN_NAME=$(jq -r '.name // empty' "$PLUGIN_JSON")
        if [[ -z "$PLUGIN_NAME" ]]; then
            log_error "plugin.json missing 'name' field"
        else
            log_success "plugin.json has name: $PLUGIN_NAME"
        fi

        PLUGIN_VERSION=$(jq -r '.version // empty' "$PLUGIN_JSON")
        if [[ -z "$PLUGIN_VERSION" ]]; then
            log_error "plugin.json missing 'version' field"
        else
            log_success "plugin.json has version: $PLUGIN_VERSION"
        fi

        PLUGIN_DESC=$(jq -r '.description // empty' "$PLUGIN_JSON")
        if [[ -z "$PLUGIN_DESC" ]]; then
            log_error "plugin.json missing 'description' field"
        else
            log_success "plugin.json has description"
        fi

        # Check skills directory exists
        SKILLS_DIR="$PLUGIN_DIR/skills"
        if [[ ! -d "$SKILLS_DIR" ]]; then
            log_error "skills/ directory not found in plugin: $PLUGIN_DIR"
            continue
        else
            log_success "skills/ directory exists"
        fi

        # Validate each skill
        SKILL_COUNT=0
        for SKILL_DIR in "$SKILLS_DIR"/*/; do
            if [[ -d "$SKILL_DIR" ]]; then
                SKILL_NAME=$(basename "$SKILL_DIR")
                SKILL_MD="$SKILL_DIR/SKILL.md"

                if [[ ! -f "$SKILL_MD" ]]; then
                    log_error "SKILL.md not found for skill: $SKILL_NAME"
                else
                    # Check SKILL.md has frontmatter
                    if ! head -1 "$SKILL_MD" | grep -q "^---"; then
                        log_error "SKILL.md missing frontmatter (---) for skill: $SKILL_NAME"
                    else
                        # Extract and validate frontmatter
                        FRONTMATTER=$(sed -n '/^---$/,/^---$/p' "$SKILL_MD" | sed '1d;$d')

                        # Check for name field
                        if ! echo "$FRONTMATTER" | grep -q "^name:"; then
                            log_error "SKILL.md missing 'name' in frontmatter for skill: $SKILL_NAME"
                        fi

                        # Check for description field
                        if ! echo "$FRONTMATTER" | grep -q "^description:"; then
                            log_error "SKILL.md missing 'description' in frontmatter for skill: $SKILL_NAME"
                        fi

                        if echo "$FRONTMATTER" | grep -q "^name:" && echo "$FRONTMATTER" | grep -q "^description:"; then
                            log_success "SKILL.md valid for skill: $SKILL_NAME"
                        fi
                    fi
                fi
                SKILL_COUNT=$((SKILL_COUNT + 1))
            fi
        done

        if [[ "$SKILL_COUNT" -eq 0 ]]; then
            log_error "No skills found in $SKILLS_DIR"
        else
            log_success "Found $SKILL_COUNT skill(s) in plugin"
        fi
    done
fi

echo ""

# ---------------------------------------------
# 3. Check for orphaned plugins (not in marketplace)
# ---------------------------------------------
echo "3. Checking for orphaned plugins..."

# Find all plugin.json files
FOUND_PLUGINS=$(find "$REPO_ROOT" -path "*/.claude-plugin/plugin.json" -not -path "$REPO_ROOT/.claude-plugin/*" 2>/dev/null)

for PLUGIN_JSON in $FOUND_PLUGINS; do
    PLUGIN_DIR=$(dirname "$(dirname "$PLUGIN_JSON")")
    RELATIVE_PATH="${PLUGIN_DIR#$REPO_ROOT/}"

    # Check if this plugin is referenced in marketplace.json
    if [[ -f "$MARKETPLACE_FILE" ]]; then
        if ! jq -r '.plugins[].source' "$MARKETPLACE_FILE" | grep -q "$RELATIVE_PATH"; then
            log_error "Orphaned plugin not in marketplace.json: $RELATIVE_PATH"
        fi
    fi
done

log_success "Orphan check complete"

echo ""

# ---------------------------------------------
# 4. Validate product folder structure
# ---------------------------------------------
echo "4. Checking product folder structure..."

# Get all top-level directories that could be products (excluding hidden and special)
for DIR in "$REPO_ROOT"/*/; do
    DIR_NAME=$(basename "$DIR")

    # Skip special directories
    if [[ "$DIR_NAME" == "scripts" ]] || [[ "$DIR_NAME" == "node_modules" ]] || [[ "$DIR_NAME" =~ ^\. ]]; then
        continue
    fi

    # Check if this is a product folder (contains plugin subdirectories)
    HAS_PLUGINS=false
    for SUBDIR in "$DIR"/*/; do
        if [[ -d "$SUBDIR/.claude-plugin" ]]; then
            HAS_PLUGINS=true
            break
        fi
    done

    if [[ "$HAS_PLUGINS" == true ]]; then
        log_success "Valid product folder: $DIR_NAME"
    fi
done

echo ""
echo "=========================================="
echo "Validation complete"
echo "=========================================="

if [[ "$ERRORS" -gt 0 ]]; then
    echo -e "${RED}Found $ERRORS error(s)${NC}"
    exit 1
else
    echo -e "${GREEN}All checks passed!${NC}"
    exit 0
fi
