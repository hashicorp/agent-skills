# Upgrade Helper Skill Template

Create `docs/skills/tf-ephemeral-upgrade-<module-name>.md` with the content below. Substitute
all template variables and generate only the sections for resource types actually found in Step 2.
Remove example resource type sections (tls_private_key, random_password) that do not apply.

---

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

Before apply, fetch the latest state version ID:
```bash
STATE_VERSION_ID=$(curl -s \
  --header "Authorization: Bearer $TFC_TOKEN" \
  "https://app.terraform.io/api/v2/workspaces/$WORKSPACE_ID/current-state-version" | \
  jq -r '.data.id')
```

Lock the workspace and restore the previous state version:
```bash
curl -s \
  --request POST \
  --header "Authorization: Bearer $TFC_TOKEN" \
  --header "Content-Type: application/vnd.api+json" \
  --data "{\"reason\": \"performing rollback\"}" \
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
          \"data\": {\"type\": \"state-versions\", \"id\": \"$STATE_VERSION_ID\"}
        }
      }
    }
  }" \
  "https://app.terraform.io/api/v2/workspaces/$WORKSPACE_ID/state-versions"
```

After apply, rollback requires re-importing the removed resource — contact module maintainer.

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
