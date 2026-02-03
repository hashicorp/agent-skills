---
name: consul-secrets
description: Use when generating dynamic Consul ACL tokens through Vault, configuring the Consul secrets engine, or managing Consul credentials. Covers policies, service identities, and node identities.
---

# Consul Secrets Engine

Generate dynamic Consul ACL tokens through Vault with automatic lease management.

## Reference

- [Consul Secrets Engine](https://developer.hashicorp.com/vault/docs/secrets/consul)
- [Vault Consul Tutorial](https://developer.hashicorp.com/consul/tutorials/vault-secure/vault-consul-secrets)
- For complete role configuration and Enterprise features, see [references/consul-secrets.md](references/consul-secrets.md)

## Overview

The Consul secrets engine generates dynamic Consul ACL tokens based on:
- Consul ACL policies
- Service identities (Consul 1.5+)
- Node identities (Consul 1.8+)

Tokens are automatically revoked when leases expire.

## Setup

### Enable the Engine

```bash
vault secrets enable consul
```

### Configure Access

```bash
# Option 1: Let Vault bootstrap Consul ACL system
vault write consul/config/access \
  address="127.0.0.1:8500"

# Option 2: Use existing management token
vault write consul/config/access \
  address="https://consul.example.com:8501" \
  token="$CONSUL_MANAGEMENT_TOKEN" \
  ca_cert="@/path/to/ca.crt"
```

### TLS Configuration

```bash
vault write consul/config/access \
  address="https://consul.example.com:8501" \
  token="$CONSUL_MANAGEMENT_TOKEN" \
  ca_cert="@ca.crt" \
  client_cert="@client.crt" \
  client_key="@client.key"
```

## Role Configuration

### Policy-Based Roles (Consul 1.4+)

```bash
# Create Consul ACL policy first
consul acl policy create -name readonly \
  -rules='key_prefix "" { policy = "read" }'

# Create Vault role using policy
vault write consul/roles/readonly \
  consul_policies="readonly"
```

### Service Identity Roles (Consul 1.5+)

```bash
# Role with service identity
vault write consul/roles/web-service \
  service_identities="web:dc1" \
  service_identities="api:dc1,dc2"
```

### Node Identity Roles (Consul 1.8+)

```bash
# Role with node identity
vault write consul/roles/server-nodes \
  node_identities="server-1:dc1" \
  node_identities="server-2:dc1"
```

### Combined Role

```bash
vault write consul/roles/platform \
  consul_policies="platform-policy" \
  service_identities="platform-svc:dc1" \
  node_identities="platform-node:dc1" \
  ttl=1h \
  max_ttl=24h
```

## Generate Credentials

```bash
# Read credentials for a role
vault read consul/creds/readonly

# Key                 Value
# lease_id            consul/creds/readonly/abc123
# lease_duration      768h
# lease_renewable     true
# accessor            a715994d-f5fd-1194-73df
# token               b31fb56c-0936-5428-8c5f
```

### Use the Token

```bash
# Set environment variable
export CONSUL_HTTP_TOKEN=$(vault read -field=token consul/creds/readonly)

# Verify token
consul acl token read -self
```

## Consul Enterprise Features

### Namespace-Scoped Roles (Consul 1.7+)

```bash
vault write consul/roles/team-a \
  consul_roles="team-a-role" \
  consul_namespace="team-a"
```

### Partition-Scoped Roles (Consul 1.11+)

```bash
vault write consul/roles/admin-partition \
  consul_roles="admin-management" \
  partition="admin1"
```

## Lease Management

### Configure Default Lease

```bash
vault write consul/config/access \
  address="127.0.0.1:8500" \
  token="$CONSUL_TOKEN"

# Set default TTL
vault secrets tune -default-lease-ttl=1h consul/
vault secrets tune -max-lease-ttl=24h consul/
```

### Renew Lease

```bash
vault lease renew consul/creds/readonly/abc123
```

### Revoke Lease

```bash
vault lease revoke consul/creds/readonly/abc123
```

## Integration Pattern

```
┌──────────┐   1. Request creds   ┌───────────┐
│   App    │ ──────────────────►  │   Vault   │
└────┬─────┘                      └─────┬─────┘
     │                                  │
     │                           2. Create ACL token
     │                                  │
     │                                  ▼
     │                           ┌───────────┐
     │ 3. Use token              │  Consul   │
     └──────────────────────────►│  Cluster  │
                                 └───────────┘
```

## Policy Examples

### Read-Only Policy

```hcl
key_prefix "" {
  policy = "read"
}
service_prefix "" {
  policy = "read"
}
node_prefix "" {
  policy = "read"
}
```

### Service-Specific Policy

```hcl
service "web" {
  policy = "write"
}
service_prefix "" {
  policy = "read"
}
key_prefix "web/" {
  policy = "write"
}
```

## API Examples

### Create Role

```bash
curl -X POST \
  -H "X-Vault-Token: $VAULT_TOKEN" \
  -d '{"consul_policies":"readonly","ttl":"1h"}' \
  $VAULT_ADDR/v1/consul/roles/my-role
```

### Generate Credentials

```bash
curl -X GET \
  -H "X-Vault-Token: $VAULT_TOKEN" \
  $VAULT_ADDR/v1/consul/creds/my-role
```

## Troubleshooting

| Issue | Cause | Resolution |
|-------|-------|------------|
| "ACL not found" | Policy doesn't exist in Consul | Create policy in Consul first |
| "Permission denied" | Vault token lacks Consul management | Use management token for config |
| Token not working | Consul ACLs not enabled | Enable ACLs in Consul config |
| Stale credentials | Consul agent config issue | Check Consul replication status |
