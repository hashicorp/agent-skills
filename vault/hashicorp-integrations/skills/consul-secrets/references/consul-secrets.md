---
name: consul-secrets
description: Reference documentation for Vault Consul secrets engine configuration and role types.
---

# Consul Secrets Engine Reference

## Configuration

| Parameter | Description |
|-----------|-------------|
| `address` | Consul agent address (host:port) |
| `token` | Consul management token |
| `scheme` | http or https |
| `ca_cert` | CA certificate for TLS |
| `client_cert` | Client certificate for mTLS |
| `client_key` | Client private key for mTLS |

## Role Types

### Policy-Based (Consul 1.4+)

```bash
vault write consul/roles/<name> \
  consul_policies="policy1,policy2" \
  ttl=1h \
  max_ttl=24h
```

### Service Identity (Consul 1.5+)

```bash
vault write consul/roles/<name> \
  service_identities="svc:dc1" \
  service_identities="svc:dc1,dc2"
```

### Node Identity (Consul 1.8+)

```bash
vault write consul/roles/<name> \
  node_identities="node:dc1"
```

### Consul Roles (Consul 1.5+)

```bash
vault write consul/roles/<name> \
  consul_roles="consul-role-name"
```

## Enterprise Parameters

| Parameter | Consul Version | Description |
|-----------|----------------|-------------|
| `consul_namespace` | 1.7+ | Namespace for token |
| `partition` | 1.11+ | Admin partition for token |

## API Endpoints

| Method | Path | Description |
|--------|------|-------------|
| POST | `/consul/config/access` | Configure Consul access |
| POST | `/consul/roles/:name` | Create/update role |
| GET | `/consul/roles/:name` | Read role |
| LIST | `/consul/roles` | List roles |
| DELETE | `/consul/roles/:name` | Delete role |
| GET | `/consul/creds/:name` | Generate credentials |

## Token Response

```json
{
  "lease_id": "consul/creds/role/abc123",
  "lease_duration": 3600,
  "renewable": true,
  "data": {
    "accessor": "uuid",
    "token": "secret-token",
    "local": false,
    "consul_namespace": "ns1",
    "partition": "default"
  }
}
```

## Consul Policy Syntax

```hcl
# Key-value access
key_prefix "" { policy = "read" }
key "specific/key" { policy = "write" }

# Service registration
service_prefix "" { policy = "read" }
service "web" { policy = "write" }

# Node access
node_prefix "" { policy = "read" }

# Agent operations
agent_prefix "" { policy = "read" }
```
