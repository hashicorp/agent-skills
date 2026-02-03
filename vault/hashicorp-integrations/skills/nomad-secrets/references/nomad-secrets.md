---
name: nomad-secrets
description: Reference documentation for Vault Nomad secrets engine configuration and role types.
---

# Nomad Secrets Engine Reference

## Configuration

### Access Configuration

| Parameter | Description |
|-----------|-------------|
| `address` | Nomad API address |
| `token` | Nomad management token |
| `ca_cert` | CA certificate for TLS |
| `client_cert` | Client certificate for mTLS |
| `client_key` | Client private key for mTLS |

### Lease Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `ttl` | Default lease duration | 1h |
| `max_ttl` | Maximum lease duration | 32d |

## Role Parameters

| Parameter | Description |
|-----------|-------------|
| `policies` | Comma-separated list of Nomad policies |
| `global` | Create token valid in all regions |
| `type` | `client` (default) or `management` |

## API Endpoints

| Method | Path | Description |
|--------|------|-------------|
| POST | `/nomad/config/access` | Configure Nomad access |
| POST | `/nomad/config/lease` | Configure default lease |
| POST | `/nomad/roles/:name` | Create/update role |
| GET | `/nomad/roles/:name` | Read role |
| LIST | `/nomad/roles` | List roles |
| DELETE | `/nomad/roles/:name` | Delete role |
| GET | `/nomad/creds/:name` | Generate credentials |

## Token Response

```json
{
  "lease_id": "nomad/creds/role/abc123",
  "lease_duration": 3600,
  "renewable": true,
  "data": {
    "accessor_id": "uuid",
    "secret_id": "token-value"
  }
}
```

## Nomad Policy Syntax

```hcl
# Namespace permissions
namespace "default" {
  policy = "write"
  capabilities = ["submit-job", "read-logs"]
}

namespace "*" {
  policy = "read"
}

# Node permissions
node {
  policy = "read"
}

# Agent permissions
agent {
  policy = "read"
}

# Operator permissions
operator {
  policy = "read"
}
```

## Nomad Capabilities

| Capability | Description |
|------------|-------------|
| `submit-job` | Submit new jobs |
| `dispatch-job` | Dispatch parameterized jobs |
| `read-logs` | Read task logs |
| `alloc-exec` | Exec into allocations |
| `alloc-lifecycle` | Restart/stop allocations |
| `csi-write-volume` | Manage CSI volumes |
| `csi-mount-volume` | Mount CSI volumes |
| `list-jobs` | List all jobs |
| `parse-job` | Parse job files |
| `read-job` | Read job details |
