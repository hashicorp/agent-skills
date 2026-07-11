---
name: terraform-cloud-secrets
description: Use when generating dynamic Terraform Cloud or Enterprise API tokens through Vault. Covers organization, team, and user token types with rotation and lease management.
---

# Terraform Cloud Secrets Engine

## What Are You Trying to Solve?

### "My CI/CD pipeline needs Terraform Cloud API access"
→ Create a **team token role** (recommended). [Jump to Team Tokens](#team-tokens-recommended)

### "I need individual developer tokens"
→ Create a **user token role**. [Jump to User Tokens](#user-tokens)

### "I need org-level management access"
→ Create an **organization token role** (⚠️ single active token). [Jump to Organization Tokens](#organization-tokens)

### "I'm using Terraform Enterprise (self-hosted)"
→ Configure with your **TFE address**. [Jump to TFE Setup](#configure-for-terraform-enterprise)

---

## How Terraform Cloud Secrets Engine Works

1. **Configure** → Vault connects to TFC/TFE with admin token
2. **Create roles** → Map to teams, users, or organization
3. **Generate credentials** → Apps request tokens from Vault
4. **Automatic expiry** → Team/user tokens expire at max_ttl

---

## Token Type Selection

| Your Need | Token Type | Key Characteristic |
|-----------|------------|-------------------|
| CI/CD automation | Team | ✅ Multiple active, auto-expire |
| Developer tooling | User | ✅ Multiple active, auto-expire |
| Org-level admin | Organization | ⚠️ Single active, manual rotation |
| Legacy (avoid) | Team Legacy | ⚠️ Single active, deprecated |

**Recommendation:** Use **team tokens** for most automation—they support multiple concurrent tokens and automatic expiry.

---

## Reference

- [Terraform Cloud Secrets Engine](https://developer.hashicorp.com/vault/docs/secrets/terraform)
- [TFC API Tokens](https://developer.hashicorp.com/terraform/cloud-docs/users-teams-organizations/api-tokens)
- For complete token types and workspace patterns, see [references/terraform-cloud-secrets.md](references/terraform-cloud-secrets.md)

## Setup

### Enable the Engine

```bash
vault secrets enable terraform
```

### Configure for Terraform Cloud

```bash
vault write terraform/config \
  token="$TFC_TOKEN"
```

### Configure for Terraform Enterprise

```bash
vault write terraform/config \
  address="https://tfe.example.com" \
  token="$TFE_TOKEN"
```

## Token Types

### Team Tokens (Recommended)

Dynamic tokens scoped to a team with configurable TTL:

```bash
# Get team ID from TFC API or UI
# Teams API: GET /organizations/{org}/teams

# Create role
vault write terraform/role/ci-team \
  team_id="team-abc123" \
  credential_type=team \
  description="CI/CD pipeline token" \
  ttl=1h \
  max_ttl=24h

# Generate token
vault read terraform/creds/ci-team
```

### User Tokens

Dynamic tokens for a specific user:

```bash
# Get user ID from TFC API or profile
# Account API: GET /account/details

vault write terraform/role/my-user \
  user_id="user-xyz789"

vault read terraform/creds/my-user
```

### Organization Tokens

Single active token for organization-level operations:

```bash
vault write terraform/role/org-admin \
  organization="my-org" \
  credential_type=organization

# Rotate (invalidates previous token)
vault write -f terraform/rotate-role/org-admin

# Read current token
vault read terraform/creds/org-admin
```

### Legacy Team Tokens (Deprecated)

```bash
vault write terraform/role/legacy-team \
  team_id="team-abc123" \
  credential_type=team_legacy

# Rotate (invalidates previous token)
vault write -f terraform/rotate-role/legacy-team
```

## Token Comparison

| Type | Multiple Active | Auto-Expire | Use Case |
|------|-----------------|-------------|----------|
| Team | Yes | Yes (max_ttl) | CI/CD, automation |
| User | Yes | Yes (max_ttl) | Individual automation |
| Organization | No | No | Org-level admin |
| Legacy Team | No | No | Backward compatibility |

## Role Configuration Options

```bash
vault write terraform/role/example \
  team_id="team-abc123" \
  credential_type=team \
  description="Token description shown in TFC" \
  ttl=2h \
  max_ttl=12h
```

| Option | Description |
|--------|-------------|
| `team_id` | TFC team ID (for team/legacy roles) |
| `user_id` | TFC user ID (for user roles) |
| `organization` | Organization name (for org roles) |
| `credential_type` | `team`, `user`, `organization`, `team_legacy` |
| `description` | Visible in TFC token list |
| `ttl` | Lease duration |
| `max_ttl` | Maximum lease duration, sets TFC ExpiredAt |

## Generate Credentials

```bash
vault read terraform/creds/ci-team

# Key             Value
# lease_id        terraform/creds/ci-team/abc123
# lease_duration  1h
# lease_renewable true
# token           tftk.abcdef1234567890
# token_id        at-456defghi789
# description     CI/CD pipeline token(42)
# expired_at      2024-01-15T12:00:00Z
```

## Use the Token

### Environment Variable

```bash
export TFE_TOKEN=$(vault read -field=token terraform/creds/ci-team)
terraform init
terraform plan
```

### Terraform Configuration

```hcl
# main.tf
terraform {
  cloud {
    organization = "my-org"
    workspaces {
      name = "my-workspace"
    }
  }
}
```

### API Calls

```bash
curl -H "Authorization: Bearer $(vault read -field=token terraform/creds/ci-team)" \
  https://app.terraform.io/api/v2/organizations/my-org/workspaces
```

## CI/CD Integration

### GitHub Actions

```yaml
jobs:
  terraform:
    steps:
      - name: Get TFC Token
        run: |
          export TFE_TOKEN=$(vault read -field=token terraform/creds/ci-team)
          echo "TFE_TOKEN=$TFE_TOKEN" >> $GITHUB_ENV
      
      - name: Terraform Plan
        run: terraform plan
```

### GitLab CI

```yaml
plan:
  script:
    - export TFE_TOKEN=$(vault read -field=token terraform/creds/ci-team)
    - terraform init
    - terraform plan
```

## Token Scope Recommendations

| Use Case | Token Type | Scope |
|----------|------------|-------|
| CI/CD pipeline | Team | Team with workspace access |
| Developer automation | User | Individual user account |
| Org-level management | Organization | Full org access |
| Workspace-specific | Team | Limited team membership |

## Lease Management

### Renew Token

```bash
vault lease renew terraform/creds/ci-team/abc123
```

### Revoke Token

```bash
vault lease revoke terraform/creds/ci-team/abc123
```

### Rotate Stored Token (Org/Legacy)

```bash
vault write -f terraform/rotate-role/org-admin
```

## API Examples

### Create Role

```bash
curl -X POST \
  -H "X-Vault-Token: $VAULT_TOKEN" \
  -d '{"team_id":"team-abc123","credential_type":"team","ttl":"1h"}' \
  $VAULT_ADDR/v1/terraform/role/ci-team
```

### Generate Credentials

```bash
curl -X GET \
  -H "X-Vault-Token: $VAULT_TOKEN" \
  $VAULT_ADDR/v1/terraform/creds/ci-team
```

## Troubleshooting

| Issue | Cause | Resolution |
|-------|-------|------------|
| "Team not found" | Wrong team ID | Verify team ID in TFC API |
| "Unauthorized" | Config token lacks permission | Use token with team/org management |
| Token expires early | TFC ExpiredAt reached | Increase max_ttl |
| Duplicate description error | TFC requires unique descriptions | Random suffix added automatically |
| Org token invalidated | Another process rotated | Use team tokens for concurrency |
