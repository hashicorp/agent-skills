---
name: tf-ephemeral-migrator
description: >
  Use when full state removal of secrets from Terraform module state is required for ALL users.
  This pattern removes secrets from state for new AND existing users using ephemeral variables 
  and removed blocks.  Requires a manual step from existing users (extract secret from state, 
  pass as ephemeral variable). Fetches latest resource lists from policy-library-ephemerality, 
  scans module code (including embedded submodules), applies migration pattern, generates 
  upgrade guide, module consumer upgrade skill, and creates a single MAJOR version PR for module.
---

# Terraform Ephemeral Migration Skill

Remove secrets from state for all users. Single breaking change — no intermediate version.
Existing users perform a one-time manual step to preserve their secret value during migration.

**Requires Terraform 1.11+** — ephemeral blocks and write-only attributes are not available in earlier versions.

---

## Step 1: Fetch Resource Lists

Before scanning, fetch latest lists from:
```
https://raw.githubusercontent.com/drewmullen/policy-library-ephemerality/refs/heads/main/data/ephemerality.json
```

**Data structure:**
- `ephemeral[]`: data sources with ephemeral equivalents (ephemeral-retrieves)
- `resources[]`: resources to replace with `ephemeral` blocks (ephemeral-creates)
- `write_only{}`: map of resource type → write-only attribute names

---

## Step 2: Scan Module Code

**Scope:**
- Scan all `.tf` files in module root
- Scan embedded submodules (often found local at `./modules/*`, don't include files from `.terraform/`)
- **DO NOT** pull or scan remote submodules

**What to find:**
- `resource "<type>"` where `<type>` in `resources[]` → ephemeral-creates candidate
- `data "<type>"` where `<type>` in `ephemeral[]` → ephemeral-retrieves candidate
- `resource "<type>"` where `<type>` in `write_only{}` keys → write-only candidate

**Record for each match:** file, type, name, attributes used, category

> **Note — `count` / `for_each` resources:** The `removed` block syntax differs when the resource uses `count` or `for_each`. Use `from = resource_type.name[0]` for count-based resources or `from = resource_type.name["key"]` for for_each. Record the meta-argument so the correct syntax is applied in Step 3.

---

## Step 3: Apply Migration Pattern

### Core Pattern

For each secret-bearing resource:

1. Add `ephemeral = true` input variable to accept legacy secret value (one-time migration)
2. Replace legacy resource with `removed { lifecycle { destroy = false } }`
3. Add `ephemeral` resource for net-new deployments
4. Update consumers with single conditional:
   - `var.<secret>_data != null` → use legacy value (existing users migrating)
   - else → use new ephemeral resource (new users)

### For ephemeral-creates (resource → ephemeral)

**Original:**
```hcl
resource "tls_private_key" "this" {
  algorithm = "RSA"
  rsa_bits  = 4096
}
```

**File: variables.tf** — add variables:
```hcl
variable "tls_private_key_data" {
  description = "Deprecated variable. Contains private key PEM from 1 time migration. Set only when migrating existing deployments to remove secret from state. Leave null for new deployments which will generate their own private key data."
  type        = string
  ephemeral   = true
  sensitive   = true
  default     = null
}

variable "secret_version" {
  description = "Increment to trigger a re-write of the write-only secret."
  type        = number
  default     = 1
}
```

**File: main.tf (or file containing the resource)** — replace resource:
```hcl
removed {
  lifecycle {
    destroy = false
  }
  from = tls_private_key.this
}

ephemeral "tls_private_key" "this" {
  algorithm = "RSA"
  rsa_bits  = 4096
}
```

**Consumer resource** — update to conditional write-only:
```hcl
resource "vault_kv_secret_v2" "example" {
  mount = "kvv2"
  name  = "mytls"

  data_json_wo = var.tls_private_key_data != null ? jsonencode(
    { private_key = var.tls_private_key_data }) : jsonencode(
    { private_key = ephemeral.tls_private_key.this.private_key_pem })

  data_json_wo_version = var.secret_version
}
```

### For ephemeral-retrieves (data → ephemeral)

**Original:**
```hcl
data "vault_kv_secret_v2" "creds" {
  mount = "secret"
  name  = "db"
}
```

**File: variables.tf** — add variable:
```hcl
variable "vault_secret_data" {
  description = "Legacy secret data. Set only when migrating existing deployments. Leave null for new deployments."
  type        = string
  ephemeral   = true
  sensitive   = true
  default     = null
}
```

**File: main.tf** — replace data source:
```hcl
removed {
  lifecycle {
    destroy = false
  }
  from = data.vault_kv_secret_v2.creds
}

ephemeral "vault_kv_secret_v2" "creds" {
  mount = "secret"
  name  = "db"
}
```

**Consumer** — update to conditional:
```hcl
locals {
  db_password = var.vault_secret_data != null ? var.vault_secret_data : ephemeral.vault_kv_secret_v2.creds.data["password"]
}
```

### For write-only attributes

**File: variables.tf** — add variable:
```hcl
variable "secret_string_data" {
  description = "Legacy secret string. Set only when migrating existing deployments."
  type        = string
  ephemeral   = true
  sensitive   = true
  default     = null
}
```

**File: main.tf** — update resource:
```hcl
resource "aws_secretsmanager_secret_version" "example" {
  secret_id = aws_secretsmanager_secret.example.id

  secret_string_wo         = var.secret_string_data != null ? var.secret_string_data : ephemeral.tls_private_key.this.private_key_pem
  secret_string_wo_version = var.secret_version
}
```

### Critical Rules

1. **`ephemeral = true` on input variables** — required for Terraform to accept ephemeral values
2. **`removed { lifecycle { destroy = false } }`** — removes resource from state, no infrastructure destroyed
3. **Single conditional on consumer** — ephemeral taint is static; keep paths isolated
4. **`*_wo_version`** — required for write-only attrs to detect changes and re-write
5. **No `moved` blocks needed** — `removed` handles state cleanup entirely

---

## Step 4: Generate Upgrade Guide

You will need to know the current latest version and the next major version for your module. Use `git fetch` to retrieve tags.

**File: `docs/UPGRADE-GUIDE-${NEXT_MAJOR}.md`**

````markdown
# Upgrade from ${CURRENT_LATEST} to ${NEXT_MAJOR}

## What Changed

Resources that store secrets in tfstate were removed for all deployments. The legacy
secret-generating resource has been replaced with an ephemeral resource.

## Upgrade Requirement — One-Time Migration Required

Prior to upgrading, you must extract any secret values and pass it as an ephemeral input variable
on your first apply after upgrading. 

### Step 1: Extract secret from state into env var

Do not write these secrets to stdout or commit them. Use a secure environment variable.

<generate per-resource extraction commands using actual resource type/name>

Example (tls_private_key):
```bash
SECRET_TLS_KEY=$(terraform state pull | jq -r '
  .resources[]
  | select(.module == "module.<module-name>" and .type == "tls_private_key")
  | .instances[0].attributes.private_key_pem
')
```

### Step 2: Write secret to HCP Terraform workspace as sensitive variable

```bash
TFC_TOKEN="<your-api-token>"
WORKSPACE_ID="<your-workspace-id>"
TFC_API="https://app.terraform.io/api/v2"

curl -s \
  --request POST \
  --header "Authorization: Bearer $TFC_TOKEN" \
  --header "Content-Type: application/vnd.api+json" \
  --data "{
    \"data\": {
      \"type\": \"vars\",
      \"attributes\": {
        \"key\": \"tls_private_key_data\",
        \"value\": $(echo "$SECRET_TLS_KEY" | jq -Rs .),
        \"category\": \"terraform\",
        \"sensitive\": true,
        \"description\": \"One-time migration: TLS private key from state\"
      }
    }
  }" \
  "$TFC_API/workspaces/$WORKSPACE_ID/vars"
```

### Step 3: Upgrade module and apply

```hcl
module "example" {
  source  = "..."
  version = "~> ${NEXT_MAJOR}"
  # all other config unchanged
}
```

```bash
terraform init -upgrade
terraform apply
```

On this apply:
- `removed` block removes the legacy resource from state (nothing destroyed)
- `var.tls_private_key_data` feeds the preserved value into the write-only attribute
- Secret is preserved, state is clean

## Rollback

Before apply:
```bash
terraform state push tfstate-before-upgrade-<timestamp>.backup
```

After apply, rollback requires re-importing the removed resource.
````

---

## Step 5: Generate Upgrade Helper Skill (REQUIRED)

**File: `docs/skills/tf-ephemeral-upgrade-<module-name>.md`**

Must be created during migration, committed to repo. Readable without any tooling.

### Skill Template

````markdown
# <Module Name> Upgrade Assistant

Upgrade <module-name> from v1.x → ${NEXT_MAJOR}. Secrets fully removed from state.
Existing users: one-time manual step required to preserve secret values.

## Workflow

1. Detect module usage and workspace ID
2. Extract secret values from state into env vars
3. Write secrets to HCP Terraform workspace as sensitive variables
4. Upgrade module version and apply

## Prerequisites

- Terraform v1.11+
- `curl` and `jq`
- HCP Terraform API token
- Workspace ID

## Step 1: Detect Module Usage

```bash
grep -rn 'module "<module-name>"' . --include="*.tf"
terraform state list | grep 'module\.<module-name>'
```

Get workspace ID:
```bash
curl -s \
  --header "Authorization: Bearer $TFC_TOKEN" \
  "https://app.terraform.io/api/v2/organizations/<org>/workspaces/<workspace-name>" \
  | jq -r '.data.id'
```

## Step 2: Extract Secret Values into Env Vars

<generate per-resource extraction for each secret found — stored in env vars, never printed to stdout>

### tls_private_key

```bash
SECRET_TLS_PRIVATE_KEY=$(terraform state pull | jq -r '
  .resources[]
  | select(.module == "module.<module-name>" and .type == "tls_private_key")
  | .instances[0].attributes.private_key_pem
')
```

### random_password

```bash
SECRET_RANDOM_PASSWORD=$(terraform state pull | jq -r '
  .resources[]
  | select(.module == "module.<module-name>" and .type == "random_password")
  | .instances[0].attributes.result
')
```

## Step 3: Write Secrets to HCP Terraform Workspace

```bash
TFC_TOKEN="<your-api-token>"
WORKSPACE_ID="<your-workspace-id>"
TFC_API="https://app.terraform.io/api/v2"
```

For each secret:
```bash
curl -s \
  --request POST \
  --header "Authorization: Bearer $TFC_TOKEN" \
  --header "Content-Type: application/vnd.api+json" \
  --data "{
    \"data\": {
      \"type\": \"vars\",
      \"attributes\": {
        \"key\": \"<variable_name>\",
        \"value\": $(echo "$SECRET_TLS_PRIVATE_KEY" | jq -Rs .),
        \"category\": \"terraform\",
        \"sensitive\": true,
        \"description\": \"One-time migration: legacy secret from state\"
      }
    }
  }" \
  "$TFC_API/workspaces/$WORKSPACE_ID/vars"
```

Verify (sensitive value not shown):
```bash
curl -s \
  --header "Authorization: Bearer $TFC_TOKEN" \
  "$TFC_API/workspaces/$WORKSPACE_ID/vars" | \
  jq '.data[] | {name: .attributes.key, sensitive: .attributes.sensitive}'
```

## Step 4: Upgrade Module and Apply

```hcl
module "<module-name>" {
  source  = "..."
  version = "~> ${NEXT_MAJOR}"
  # all other config unchanged
  # do NOT set <secret>_data here — read from workspace variable automatically
}
```

```bash
terraform init -upgrade
terraform plan -out=upgrade.tfplan
```

Expected plan:
```
# module.<module-name>.tls_private_key.this has been removed
  (lifecycle.destroy = false — no infrastructure destroyed)

# module.<module-name>.vault_kv_secret_v2.example will be updated in-place
~ resource "vault_kv_secret_v2" "example" {
    ~ data_json    = (sensitive value) -> null
    + data_json_wo = (known after apply)
  }
```

Validation:
- ✅ `removed` — resource leaves state, nothing destroyed
- ✅ Consumer updated to write-only attribute
- ✅ No resource creates or destroys

```bash
terraform apply upgrade.tfplan
```

Verify:
```bash
# Removed resource should no longer appear in state
terraform state list | grep '<removed_resource_type>'
# expect: no output

# Consumer resources should still be present
terraform state list | grep 'module.<module-name>'
```

## Rollback

Before apply fetch the latest state version id:
```bash
STATE_VERSION_ID=$(curl -s \
  --header "Authorization: Bearer $TFC_TOKEN" \
  "https://app.terraform.io/api/v2/workspaces/$WORKSPACE_ID/current-state-version" | \
  jq -r '.data.id')
```

If a rollback is required, use the state version id to restore:

The lock the workspace and restore the previous state version:
```bash
curl -s \
  --request POST \
  --header "Authorization: Bearer $TFC_TOKEN" \
  --header "Content-Type: application/vnd.api+json" \
  --data "{
    \"reason\": \"performing rollback\"
  }" \
  "https://app.terraform.io/api/v2/workspaces/$WORKSPACE_ID/actions/lock"

curl -s \
  --request PATCH \
  --header "Authorization: Bearer $TFC_TOKEN" \
  --header "Content-Type: application/vnd.api+json" \
  --data "{
    \"data\": {
      \"type\": \"state-versions\",
      \"relationships\": {
        \"rollback-state-version\": {
          \"data\": {
            \"type\": \"state-versions\",
            \"id\": \"$STATE_VERSION_ID\"
          }
        }
      }
    }
  }" \
  "https://app.terraform.io/api/v2/workspaces/$WORKSPACE_ID/state-versions"
```



After apply, rollback requires re-importing removed resource — contact module maintainer.

## Troubleshooting

### "Variable is not ephemeral"
**Fix:** Module version must be ${NEXT_MAJOR}+. The `<secret>_data` variable requires `ephemeral = true`.

### Plan shows unexpected destroys
**Fix:** Do NOT apply. Verify workspace variables created (Step 3) and module version is correct.

### Workspace variable not found in Step 3
```bash
curl -s --header "Authorization: Bearer $TFC_TOKEN" \
  "$TFC_API/workspaces/$WORKSPACE_ID/vars" | jq '.data[].attributes.key'
```

## Related

- [UPGRADE-GUIDE-${NEXT_MAJOR}.md](./UPGRADE-GUIDE-${NEXT_MAJOR}.md)
- [examples/](../examples/)
````

---

## Git Workflow — Single PR

### Detect Version

```bash
CURRENT_VERSION=$(git tag --list 'v*.*.*' --sort=-v:refname | head -n 1)

if [ -z "$CURRENT_VERSION" ]; then
  echo "No local tags found, fetching from remote..."
  git fetch --tags
  CURRENT_VERSION=$(git tag --list 'v*.*.*' --sort=-v:refname | head -n 1)
fi

if [ -z "$CURRENT_VERSION" ]; then
  echo "No tags found, assuming v1.0.0"
  CURRENT_VERSION="v1.0.0"
fi

MAJOR=$(echo $CURRENT_VERSION | sed 's/v//' | cut -d. -f1)
NEXT_MAJOR="v$((MAJOR + 1)).0.0"

echo "Current: $CURRENT_VERSION → Next major: $NEXT_MAJOR"
```

**Example with tag v1.1.1:** `NEXT_MAJOR=v2.0.0`

### Single PR: Major Version

**Branch:** `feat/ephemeral-migration`

**Files Changed:**
- `main.tf` — `removed` block, `ephemeral` resource, write-only consumers
- `variables.tf` — `<secret>_data` ephemeral variables, `secret_version`
- `docs/UPGRADE-GUIDE-${NEXT_MAJOR}.md` — upgrade guide (REQUIRED)
- `docs/skills/tf-ephemeral-upgrade-<module>.md` — upgrade assistant (REQUIRED)
- `README.md` — add breaking change notice, major version bump, and link to `docs/UPGRADE-GUIDE-${NEXT_MAJOR}.md` in the changelog or migration section

**Commit Message:**
```
feat!: remove secrets from state

BREAKING CHANGE: Legacy secret-generating resources replaced with ephemeral resources.
Existing users must perform a one-time manual migration step before applying.
See docs/UPGRADE-GUIDE-${NEXT_MAJOR}.md for instructions.

- Replace resource blocks with removed + ephemeral
- Add ephemeral input variables for one-time legacy migration
- Update consumers to write-only attributes with conditional
- Add docs/UPGRADE-GUIDE-${NEXT_MAJOR}.md
- Add docs/skills/tf-ephemeral-upgrade-<module>.md

Target version: ${NEXT_MAJOR}
```

**PR Description** — write to `pr_description.md` (substitute `${NEXT_MAJOR}` and `${CURRENT_VERSION}` with actual values before writing). Discard file after PR creation.:
```markdown
## Description

Removes secrets from Terraform state.

## Version

**MAJOR VERSION BUMP** (${CURRENT_VERSION} → ${NEXT_MAJOR})

⚠️ **BREAKING CHANGE**: Existing users must perform a one-time migration step.

## Impact

### New Deployments
No changes required. Secrets are ephemeral and never written to state.

### Existing Deployments
One-time manual step required on first apply:
1. Extract secret from state into env var
2. Write to HCP Terraform workspace as sensitive variable
3. Apply upgrade — secret preserved, removed from state

Full instructions: `docs/skills/tf-ephemeral-upgrade-<module>.md`

## Changes

### `variables.tf`
- `<secret>_data` (string, ephemeral, sensitive, default: null) — one-time migration input
- `secret_version` (number, default: 1) — increment to re-write write-only secret

### Resource Changes
- `removed { lifecycle { destroy = false } }` replaces legacy resource
- `ephemeral "<type>" "this"` added
- Consumer resources updated to `_wo` write-only attributes with conditional

## Documentation
- `docs/UPGRADE-GUIDE-${NEXT_MAJOR}.md` — upgrade guide
- `docs/skills/tf-ephemeral-upgrade-<module>.md` — step-by-step upgrade assistant
```

**Git Commands:**
```bash
git checkout -b feat/ephemeral-migration

# Verify required files exist
test -f docs/UPGRADE-GUIDE-${NEXT_MAJOR}.md || echo "ERROR: Upgrade guide not created!"
test -f docs/skills/tf-ephemeral-upgrade-*.md || echo "ERROR: Upgrade skill not created!"

git add main.tf variables.tf docs/ README.md examples/
git commit -m "feat!: Remove secrets from state

BREAKING CHANGE: Legacy secret-generating resources replaced with ephemeral resources.
Existing users must perform a one-time manual migration step before applying.
See docs/UPGRADE-GUIDE-${NEXT_MAJOR}.md for instructions.

Target version: ${NEXT_MAJOR}"

git push -u origin feat/ephemeral-migration

gh pr create \
  --title "feat!: remove secrets from state (${NEXT_MAJOR} - MAJOR)" \
  --body-file docs/pr_description.md \
  --label "breaking-change" \
  --label "major-version" \
  --base main

PR_URL=$(gh pr view --json url -q .url)
echo "PR: $PR_URL"
```

---

## Final Output to User

```
✅ Migration complete!

Files created:
- variables.tf — ephemeral input variables
- main.tf — removed block + ephemeral resource + write-only consumers
- docs/UPGRADE-GUIDE-${NEXT_MAJOR}.md — upgrade guide ⭐
- docs/skills/tf-ephemeral-upgrade-<module>.md — upgrade assistant ⭐
- README.md — updated

PR created:
- PR (MAJOR ${NEXT_MAJOR}): $PR_URL

Next steps for maintainers:
1. Review and merge PR
2. Tag: git tag ${NEXT_MAJOR} && git push origin ${NEXT_MAJOR}

Existing users must follow docs/skills/tf-ephemeral-upgrade-<module>.md
before upgrading — one-time step to preserve secret values.
```

---

## Complete Reference

- Blog post: https://dev.to/drewmullen/fully-migrate-secrets-out-of-terraform-module-state-without-breaking-existing-users-1jc5
- Policy library: https://github.com/drewmullen/policy-library-ephemerality
- Ephemerality data: https://raw.githubusercontent.com/drewmullen/policy-library-ephemerality/refs/heads/main/data/ephemerality.json
