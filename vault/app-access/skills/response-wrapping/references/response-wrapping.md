---
name: response-wrapping
description: Reference documentation for Vault response wrapping, cubbyhole secrets, and secure secret distribution patterns.
---

# Response Wrapping Reference

## Core Concepts

### Cubbyhole Secrets Engine

The cubbyhole secrets engine provides private, token-scoped secret storage:

- **Token Isolation**: Each token has its own cubbyhole that no other token can access
- **Automatic Cleanup**: Cubbyhole is destroyed when the token expires or is revoked
- **No Hierarchy**: Child tokens cannot access parent's cubbyhole
- **Default Enabled**: Mounted at `cubbyhole/` by default, cannot be disabled

### Response Wrapping Mechanism

1. Client requests wrapped response with `X-Vault-Wrap-TTL` header
2. Vault generates a single-use wrapping token
3. Original response is stored in the wrapping token's cubbyhole
4. Client receives wrapping token instead of original response
5. Recipient unwraps token to retrieve original response
6. Wrapping token is immediately invalidated after unwrap

## CLI Reference

| Command | Description |
|---------|-------------|
| `vault read -wrap-ttl=<duration> <path>` | Read and wrap response |
| `vault write -wrap-ttl=<duration> <path>` | Write and wrap response |
| `vault unwrap [token]` | Unwrap wrapped token |
| `vault token create -wrap-ttl=<duration>` | Create and wrap new token |

## API Endpoints

| Method | Path | Description |
|--------|------|-------------|
| POST | `/sys/wrapping/wrap` | Wrap arbitrary data |
| POST | `/sys/wrapping/unwrap` | Unwrap wrapped token |
| POST | `/sys/wrapping/lookup` | Look up wrapping token properties |
| POST | `/sys/wrapping/rewrap` | Rewrap with new wrapping token |

## Wrapping Token Properties

```json
{
  "wrapping_token": "hvs.CAESIFhP...",
  "wrapping_accessor": "abc123...",
  "wrapping_token_ttl": 300,
  "wrapping_token_creation_time": "2024-01-15T10:00:00Z",
  "wrapping_token_creation_path": "secret/data/myapp"
}
```

## Security Considerations

1. **Single Use**: Wrapped tokens can only be unwrapped once
2. **TTL Limits**: Set appropriate TTL based on delivery time
3. **Malfeasance Detection**: Failed unwrap indicates interception
4. **Creation Path**: Stored for audit purposes, reveals original request path
5. **No Renewal**: Wrapping tokens cannot be renewed

## Use Cases

| Scenario | Recommended TTL |
|----------|-----------------|
| Interactive handoff | 5-15 minutes |
| Service bootstrap | 30 minutes - 24 hours |
| Automated deployment | Match deployment window |
| Emergency credential | 1-5 minutes |
