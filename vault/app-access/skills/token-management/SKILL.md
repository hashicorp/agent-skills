---
name: token-management
description: Use when working with Vault token types, creating periodic or batch tokens, managing token accessors, orphan tokens, or token lifecycle. Covers service vs batch tokens and renewal strategies.
---

# Token Management

## What Are You Trying to Solve?

### "My app needs a simple, renewable token"
→ Use **service tokens** (default). [Jump to Service Tokens](#service-tokens)

### "I have high-scale ephemeral workloads (serverless, short-lived pods)"
→ Use **batch tokens** for minimal overhead. [Jump to Batch Tokens](#batch-tokens)

### "My service runs indefinitely and must not lose access"
→ Use **periodic tokens** that never expire if renewed. [Jump to Periodic Tokens](#periodic-tokens)

### "I need token to survive parent revocation"
→ Use **orphan tokens** for independent lifecycle. [Jump to Orphan Tokens](#orphan-tokens)

### "I need to revoke a token without exposing its value"
→ Use **token accessors** for safe revocation. [Jump to Token Accessors](#token-accessors)

---

## How Vault Tokens Work

1. **Authentication** → Client authenticates via auth method
2. **Token issued** → Vault returns token with policies and TTL
3. **Token usage** → Client uses token for API requests
4. **Renewal/Expiry** → Token must be renewed before TTL or it expires
5. **Revocation** → Token and all children revoked (unless orphan)

---

## Token Type Selection

| Your Workload | Token Type | Why |
|---------------|------------|-----|
| Standard app, needs renewal | Service | Full features, stored in Vault |
| Serverless, short-lived pods | Batch | Lightweight, no storage overhead |
| Long-running daemon | Periodic | Renewable forever if renewed in time |
| Independent of parent | Orphan | Won't be revoked with parent |
| Pre-approved parameters | Role-based | Enforce TTL, policies, orphan status |

---

## Token Prefixes

```
hvs.<random>  - Service token
hvb.<random>  - Batch token  
hvr.<random>  - Recovery token
```

---

## Reference

- [Token Concepts](https://developer.hashicorp.com/vault/docs/concepts/tokens)
- [Token Auth Method](https://developer.hashicorp.com/vault/docs/auth/token)
- For complete token lifecycle patterns and accessor management, see [references/token-management.md](references/token-management.md)

## Service Tokens

Standard tokens with full features:

```bash
# Create service token (default)
vault token create -policy=myapp -ttl=4h

# Create with explicit type
vault token create -type=service -policy=myapp

# Renew before expiration
vault token renew hvs.token_value

# Or self-renew
vault token renew
```

## Batch Tokens

Lightweight, no storage overhead:

```bash
# Create batch token
vault token create -type=batch -policy=myapp -ttl=1h

# Batch tokens cannot be renewed
# They expire at TTL, period

# Best for:
# - Serverless functions
# - Kubernetes pods with short lifespans
# - High-throughput automation
```

## Periodic Tokens

Never expire if renewed within period:

```bash
# Create periodic token (requires sudo/root)
vault token create -period=24h -policy=myapp

# Token TTL resets to period on each renewal
vault token renew hvs.periodic_token

# Use for:
# - Long-running services
# - Database connection pools
# - Background workers
```

## Orphan Tokens

Independent of parent token lifecycle:

```bash
# Create orphan token
vault token create -orphan -policy=myapp

# Or via token store role
vault write auth/token/roles/orphan-role orphan=true
vault token create -role=orphan-role

# Orphan tokens are NOT revoked when parent is revoked
```

## Token Accessors

Reference tokens without exposing values:

```bash
# Get accessor when creating token
vault token create -policy=myapp
# Key             Value
# token_accessor  abc123xyz

# Lookup token by accessor
vault token lookup -accessor abc123xyz

# Revoke by accessor (safer for automation)
vault token revoke -accessor abc123xyz

# List all accessors (requires root/sudo)
vault list auth/token/accessors
```

## Token Capabilities

Check what a token can do:

```bash
# Check current token's capabilities on a path
vault token capabilities secret/data/myapp

# Check specific token's capabilities
vault token capabilities -accessor abc123 secret/data/myapp

# Self-check
vault token lookup
```

## Token Renewal Strategies

### Manual Renewal

```bash
# Renew with default increment
vault token renew

# Renew with specific increment
vault token renew -increment=1h

# Renew another token
vault token renew hvs.other_token
```

### Programmatic Renewal

```go
// Go example with vault client
client.Auth().Token().RenewSelf(3600)
```

### Renewal Considerations

```
┌─────────────────────────────────────────────────────────┐
│                    Token Lifetime                        │
├──────────────┬──────────────────────────────────────────┤
│   Created    │                 Max TTL                   │
│      │       │                    │                      │
│      ▼       │                    ▼                      │
│   [────TTL────]───renew──[────TTL────]───renew──[──]     │
│                                                    │     │
│                                              Token │     │
│                                              Expires     │
└─────────────────────────────────────────────────────────┘
```

## Token Store Roles

Pre-define token configurations:

```bash
# Create role for CI/CD tokens
vault write auth/token/roles/cicd \
  allowed_policies="deploy-policy" \
  orphan=true \
  renewable=true \
  token_period=1h \
  token_explicit_max_ttl=24h

# Create token from role
vault token create -role=cicd
```

## Decision Matrix

| Requirement | Token Type |
|-------------|------------|
| Standard app with renewal | Service |
| High-scale, short-lived | Batch |
| Long-running, must not expire | Periodic |
| Independent lifecycle | Orphan |
| Pre-approved parameters | Role-based |

## API Examples

### Create Token

```bash
curl -X POST \
  -H "X-Vault-Token: $VAULT_TOKEN" \
  -d '{"policies":["myapp"],"ttl":"1h"}' \
  $VAULT_ADDR/v1/auth/token/create
```

### Lookup Token

```bash
curl -X POST \
  -H "X-Vault-Token: $VAULT_TOKEN" \
  -d '{"token":"hvs.target_token"}' \
  $VAULT_ADDR/v1/auth/token/lookup
```

### Revoke Token

```bash
curl -X POST \
  -H "X-Vault-Token: $VAULT_TOKEN" \
  -d '{"token":"hvs.target_token"}' \
  $VAULT_ADDR/v1/auth/token/revoke
```

## Troubleshooting

| Issue | Cause | Resolution |
|-------|-------|------------|
| Token expired unexpectedly | Didn't renew before TTL | Implement renewal loop |
| Cannot renew batch token | Batch tokens are non-renewable | Use service token instead |
| Max TTL prevents renewal | System or mount max_ttl hit | Re-authenticate for new token |
| Orphan token still revoked | Explicit revocation, not parent | Check audit logs |
