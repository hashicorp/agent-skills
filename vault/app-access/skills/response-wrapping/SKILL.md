---
name: response-wrapping
description: Use when working with Vault response wrapping, cubbyhole secrets, secure secret distribution, wrapped tokens, or bootstrap workflows. Covers wrap/unwrap operations and malfeasance detection.
---

# Response Wrapping and Cubbyhole

## What Are You Trying to Solve?

### "I need to securely hand off a secret to a new service"
→ Use **response wrapping** with wrapped tokens. [Jump to Bootstrap Workflow](#bootstrap-workflow)

### "I need single-use, time-limited secret delivery"
→ **Wrap the response** with a short TTL. [Jump to Wrap Any Response](#wrap-any-response)

### "I need to detect if someone intercepted my secret"
→ Use **malfeasance detection** (second unwrap fails). [Jump to Malfeasance Detection](#malfeasance-detection)

### "I need private storage scoped to a single token"
→ Use **cubbyhole** for token-scoped secrets. [Jump to Cubbyhole](#cubbyhole-secrets-engine)

---

## How Response Wrapping Works

1. **Request with wrap** → Add `-wrap-ttl=5m` to any Vault command
2. **Vault stores response** → Response stored in wrapping token's cubbyhole
3. **Wrapped token returned** → You get a single-use token instead of the secret
4. **Recipient unwraps** → Recipient uses token exactly once to retrieve secret
5. **Token destroyed** → After unwrap, token and cubbyhole are gone forever

**Key insight:** If unwrap fails, someone already used the token—you've detected interception.

---

## Secure Handoff Pattern

```
┌──────────┐     wrapped token      ┌──────────┐
│ Operator │ ─────────────────────► │ Service  │
└──────────┘                        └────┬─────┘
                                         │
                                         │ unwrap (once)
                                         ▼
                                    ┌──────────┐
                                    │  Vault   │
                                    └──────────┘
```

---

## Wrapping TTL Guidelines

| Scenario | Recommended TTL |
|----------|-----------------|
| Interactive handoff (human) | 5-15 minutes |
| Automated bootstrap | 1-24 hours |
| Scheduled deployment | Match deployment window |
| Emergency/sensitive access | 30 seconds - 5 minutes |

---

## Reference

- [Response Wrapping](https://developer.hashicorp.com/vault/docs/concepts/response-wrapping)
- [Cubbyhole Secrets Engine](https://developer.hashicorp.com/vault/docs/secrets/cubbyhole)
- For complete wrapping workflows and security patterns, see [references/response-wrapping.md](references/response-wrapping.md)

## Cubbyhole Secrets Engine

Every token has its own private cubbyhole storage:

```bash
# Write to current token's cubbyhole
vault write cubbyhole/my-secret value="sensitive-data"

# Read from cubbyhole
vault read cubbyhole/my-secret

# Cubbyhole is destroyed when token expires or is revoked
```

**Key Properties:**
- Scoped to the token - no other token can access it
- Not shared across token hierarchies
- Automatically destroyed with the token
- Cannot be listed by other tokens

## Response Wrapping

### Wrap Any Response

```bash
# Wrap a secret read with 5-minute TTL
vault read -wrap-ttl=5m secret/data/myapp

# Returns wrapped token instead of secret
Key                              Value
---                              -----
wrapping_token:                  hvs.CAES...
wrapping_accessor:               8WxD3y...
wrapping_token_ttl:              5m
wrapping_token_creation_time:    2024-01-15T10:30:00Z
wrapping_token_creation_path:    secret/data/myapp
```

### Unwrap a Wrapped Token

```bash
# Recipient unwraps to get the original response
vault unwrap hvs.CAES...

# Or using the environment
VAULT_TOKEN=hvs.CAES... vault unwrap
```

### Wrap Arbitrary Data

```bash
# Wrap arbitrary JSON data
vault write -wrap-ttl=1h sys/wrapping/wrap data='{"api_key":"secret123"}'
```

## API Examples

### Create Wrapped Response

```bash
curl -X GET \
  -H "X-Vault-Token: $VAULT_TOKEN" \
  -H "X-Vault-Wrap-TTL: 300" \
  $VAULT_ADDR/v1/secret/data/myapp
```

### Unwrap Token

```bash
curl -X POST \
  -H "X-Vault-Token: hvs.wrapped_token" \
  $VAULT_ADDR/v1/sys/wrapping/unwrap
```

### Look Up Wrapped Token Properties

```bash
curl -X POST \
  -H "X-Vault-Token: $VAULT_TOKEN" \
  -d '{"token": "hvs.wrapped_token"}' \
  $VAULT_ADDR/v1/sys/wrapping/lookup
```

## Malfeasance Detection

If someone intercepts and unwraps a token before the intended recipient:

```bash
# Second unwrap attempt fails with clear indication
vault unwrap hvs.previously_unwrapped

Error: wrapping token is not valid or does not exist
```

The original sender can verify delivery by:
1. Storing the wrapping accessor
2. Checking if the token was unwrapped by the expected entity
3. Detecting if unwrap happened from unexpected source

## Bootstrap Workflow

### Service Bootstrap with Wrapped Token

```bash
# 1. Operator creates wrapped approle credentials
vault write -wrap-ttl=24h -f auth/approle/role/myapp/secret-id

# 2. Deliver wrapped token to new service (secure channel)
# 3. Service unwraps on first boot
vault unwrap hvs.wrapped_secretid

# 4. Service authenticates with unwrapped secret-id
vault write auth/approle/login \
  role_id="role-id" \
  secret_id="unwrapped-secret-id"
```

### Secure Handoff Pattern

```
┌──────────┐     wrapped token      ┌──────────┐
│ Operator │ ─────────────────────► │ Service  │
└──────────┘                        └────┬─────┘
                                         │
                                         │ unwrap (once)
                                         ▼
                                    ┌──────────┐
                                    │  Vault   │
                                    └──────────┘
```

## Wrapping TTL Best Practices

| Use Case | Recommended TTL |
|----------|-----------------|
| Interactive handoff | 5-15 minutes |
| Automated bootstrap | 1-24 hours |
| Scheduled deployment | Match deployment window |
| Emergency access | 30 seconds - 5 minutes |

## Common Patterns

### Wrap Token Creation

```bash
# Create wrapped token for another service
vault token create \
  -wrap-ttl=1h \
  -policy=app-policy \
  -ttl=4h
```

### Rewrap for Extended Delivery

```bash
# Rewrap an existing wrapped token with new TTL
vault write sys/wrapping/rewrap token="hvs.old_wrapped"
```

## Troubleshooting

| Issue | Cause | Resolution |
|-------|-------|------------|
| "wrapping token is not valid" | Already unwrapped or expired | Generate new wrapped response |
| "permission denied" | Token lacks unwrap permission | Use token with appropriate policy |
| Empty response on unwrap | Original secret was empty | Verify source secret exists |
