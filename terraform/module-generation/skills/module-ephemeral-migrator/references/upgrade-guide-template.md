# Upgrade Guide Template

Create `docs/UPGRADE-GUIDE-${NEXT_MAJOR}.md` with the content below. Substitute all template
variables (`${NEXT_MAJOR}`, `${CURRENT_LATEST}`, `<module-name>`) with actual values. Generate
per-resource extraction commands for every secret found in Step 2 — do not include example
resource types that are not present in this module.

---

````markdown
# Upgrade from ${CURRENT_LATEST} to ${NEXT_MAJOR}

## What Changed

Resources that store secrets in tfstate were removed for all deployments. The legacy
secret-generating resource has been replaced with an ephemeral resource.

## Upgrade Requirement — One-Time Migration Required

Prior to upgrading, you must extract any secret values and pass them as ephemeral input
variables on your first apply after upgrading.

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
