---
name: token-management
description: Reference documentation for Vault token types, lifecycle, and management patterns.
---

# Token Management Reference

## Token Types

| Type | Prefix | Storage | Renewable | Parent Revocation |
|------|--------|---------|-----------|-------------------|
| Service | `hvs.` | Yes | Yes | Revokes children |
| Batch | `hvb.` | No | No | Stops working |
| Periodic | `hvs.` | Yes | Yes (indefinite) | Revokes children |
| Orphan | `hvs.` | Yes | Yes | Not affected |
| Root | `hvs.` | Yes | Optional | N/A |

## Token Capabilities

Service tokens support all capabilities:
- Create child tokens
- Have cubbyholes
- Be renewed
- Be explicitly revoked
- Have explicit max TTL
- Be periodic

Batch tokens are lightweight but limited:
- No storage overhead
- Cannot create children
- Cannot be renewed
- No cubbyhole
- Scale with standbys

## CLI Reference

| Command | Description |
|---------|-------------|
| `vault token create` | Create new token |
| `vault token lookup [token]` | View token details |
| `vault token renew [token]` | Renew token lease |
| `vault token revoke [token]` | Revoke token and children |
| `vault token capabilities <path>` | Check token permissions |
| `vault list auth/token/accessors` | List all token accessors |

## Token Creation Flags

| Flag | Description |
|------|-------------|
| `-type=<type>` | service or batch |
| `-policy=<policy>` | Attach policy (repeatable) |
| `-ttl=<duration>` | Initial TTL |
| `-explicit-max-ttl=<duration>` | Hard limit on lifetime |
| `-period=<duration>` | Create periodic token |
| `-orphan` | Create without parent |
| `-renewable=<bool>` | Allow renewal (default: true) |
| `-no-parent` | Create orphan (requires sudo) |

## API Endpoints

| Method | Path | Description |
|--------|------|-------------|
| POST | `/auth/token/create` | Create token |
| POST | `/auth/token/create-orphan` | Create orphan token |
| POST | `/auth/token/lookup` | Lookup token |
| POST | `/auth/token/lookup-accessor` | Lookup by accessor |
| POST | `/auth/token/renew` | Renew token |
| POST | `/auth/token/revoke` | Revoke token |
| POST | `/auth/token/revoke-orphan` | Revoke, orphan children |
| POST | `/auth/token/revoke-accessor` | Revoke by accessor |
| LIST | `/auth/token/accessors` | List all accessors |

## Token Store Roles

Pre-define token parameters:

```bash
vault write auth/token/roles/cicd \
  allowed_policies="deploy,read" \
  disallowed_policies="admin" \
  orphan=true \
  renewable=true \
  token_period=1h \
  token_explicit_max_ttl=24h \
  token_type=service \
  token_num_uses=0 \
  token_bound_cidrs="10.0.0.0/8"
```

## TTL Hierarchy

1. **System max TTL**: 32 days (default), configurable
2. **Mount max TTL**: Per auth method tuning
3. **Role/Auth max TTL**: Configured on role or auth method
4. **Request TTL**: Requested at token creation
5. **Explicit max TTL**: Hard cap if set

## Accessor Usage

Accessors provide safe token references:

- Lookup token metadata
- Check token capabilities
- Renew token
- Revoke token
- Audit logging

**Cannot**: Read token value, use token for authentication

## Root Token Best Practices

1. Generate only for initial setup or emergencies
2. Use `vault operator generate-root` with quorum
3. Revoke immediately after use
4. Prefer limited tokens for daily operations
5. Multiple witnesses when using root tokens
