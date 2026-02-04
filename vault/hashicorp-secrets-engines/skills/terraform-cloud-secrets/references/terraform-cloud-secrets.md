---
name: terraform-cloud-secrets
description: Reference documentation for Vault Terraform Cloud secrets engine token types and configuration.
---

# Terraform Cloud Secrets Engine Reference

## Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `address` | TFC/TFE API address | https://app.terraform.io |
| `token` | TFC API token for configuration | Required |

## Role Parameters

| Parameter | Description |
|-----------|-------------|
| `credential_type` | `team`, `user`, `organization`, or `team_legacy` |
| `organization` | Organization name (for org roles) |
| `team_id` | Team ID (for team/legacy roles) |
| `user_id` | User ID (for user roles) |
| `description` | Token description (visible in TFC) |
| `ttl` | Lease duration |
| `max_ttl` | Maximum duration (sets ExpiredAt in TFC) |

## Token Type Comparison

| Type | Multiple Active | Auto-Expire | Vault Stores |
|------|-----------------|-------------|--------------|
| team | Yes | Yes | No (generated each time) |
| user | Yes | Yes | No (generated each time) |
| organization | No | No | Yes (stored, rotated) |
| team_legacy | No | No | Yes (stored, rotated) |

## API Endpoints

| Method | Path | Description |
|--------|------|-------------|
| POST | `/terraform/config` | Configure TFC access |
| POST | `/terraform/role/:name` | Create/update role |
| GET | `/terraform/role/:name` | Read role |
| LIST | `/terraform/role` | List roles |
| DELETE | `/terraform/role/:name` | Delete role |
| GET | `/terraform/creds/:name` | Generate credentials |
| POST | `/terraform/rotate-role/:name` | Rotate stored token |

## Credential Response

```json
{
  "lease_id": "terraform/creds/role/abc123",
  "lease_duration": 3600,
  "renewable": true,
  "data": {
    "token": "tftk.abc123...",
    "token_id": "at-xyz789",
    "description": "Token description(42)",
    "expired_at": "2024-01-16T10:00:00Z"
  }
}
```

## Finding IDs

### Team ID

```bash
# Via TFC API
curl -H "Authorization: Bearer $TFC_TOKEN" \
  https://app.terraform.io/api/v2/organizations/$ORG/teams

# Or check TFC UI: Settings > Teams > team name in URL
```

### User ID

```bash
# Via TFC API (current user)
curl -H "Authorization: Bearer $TFC_TOKEN" \
  https://app.terraform.io/api/v2/account/details
```

### Organization Name

```bash
# Via TFC API
curl -H "Authorization: Bearer $TFC_TOKEN" \
  https://app.terraform.io/api/v2/organizations
```

## Token Permissions Required

| Role Type | Config Token Needs |
|-----------|-------------------|
| team | Team token management |
| user | User token management |
| organization | Organization token access |

## TFC API Token Types

| TFC Token Type | Scope | Vault Role Type |
|----------------|-------|-----------------|
| User token | User's permissions across orgs | user |
| Team token | Team's workspace permissions | team |
| Org token | Full organization access | organization |
