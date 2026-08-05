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
- `tfctl` ([install](https://github.com/hashicorp/tfctl-cli)) — authenticated via `tfctl auth login` or `TFCTL_TOKEN`
- `jq`

## Step 1: Detect Module Usage

```bash
grep -rn 'module "<module-name>"' . --include="*.tf"
terraform state list | grep 'module\.<module-name>'
```

Note your workspace name — it is used in all subsequent `tfctl` commands in place of a workspace ID.

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

Authenticate if not already logged in:
```bash
tfctl auth login
```

For each secret, export it under the module variable name and import it as a sensitive workspace variable:
```bash
export tls_private_key_data="$SECRET_TLS_PRIVATE_KEY"
tfctl variable import --env="tls_private_key_data" --workspace="<workspace-name>"

export random_password_data="$SECRET_RANDOM_PASSWORD"
tfctl variable import --env="random_password_data" --workspace="<workspace-name>"
```

`tfctl variable import` automatically marks all environment variables as sensitive.

Verify (sensitive values not shown):
```bash
tfctl api /workspaces/{workspace}/vars \
  -p 'workspace=<workspace-name>' \
  --jq '.data[] | {name: .attributes.key, sensitive: .attributes.sensitive}'
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
STATE_VERSION_ID=$(tfctl api /workspaces/{workspace}/current-state-version \
  -p 'workspace=<workspace-name>' --jq '.data.id')
```

Lock the workspace:
```bash
tfctl api /workspaces/{workspace}/actions/lock -X POST \
  -p 'workspace=<workspace-name>' \
  -a 'reason=performing rollback'
```

Restore the previous state version:
```bash
jq -n --arg id "$STATE_VERSION_ID" '{
  data: {
    type: "state-versions",
    relationships: {
      "rollback-state-version": {
        data: {type: "state-versions", id: $id}
      }
    }
  }
}' | tfctl api /workspaces/{workspace}/state-versions -X PATCH \
       -p 'workspace=<workspace-name>' -i -
```

After apply, rollback requires re-importing the removed resource — contact module maintainer.

## Troubleshooting

### "Variable is not ephemeral"
**Fix:** Module version must be ${NEXT_MAJOR}+. The `<secret>_data` variable requires `ephemeral = true`.

### Plan shows unexpected destroys
**Fix:** Do NOT apply. Verify workspace variables created (Step 3) and module version is correct.

### Workspace variable not found in Step 3
```bash
tfctl api /workspaces/{workspace}/vars \
  -p 'workspace=<workspace-name>' --jq '.data[].attributes.key'
```

## Related

- [UPGRADE-GUIDE-${NEXT_MAJOR}.md](./UPGRADE-GUIDE-${NEXT_MAJOR}.md)
- [examples/](../examples/)
````
