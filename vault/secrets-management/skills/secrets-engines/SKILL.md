---
name: secrets-engines
description: Configure and use Vault secrets engines. Use when asked about KV secrets, database dynamic credentials, AWS/Azure/GCP credentials, Transit encryption, PKI certificates, SSH secrets, or TOTP. Covers static secrets, dynamic credentials, encryption-as-a-service, and secrets engine lifecycle.
---

# Vault Secrets Engines

Secrets engines are components that store, generate, or encrypt data. They provide a unified interface for managing static secrets (KV), dynamic credentials (Database, AWS, Azure, GCP), encryption (Transit), and certificates (PKI).

## Reference

- [Vault Secrets Engines Documentation](https://developer.hashicorp.com/vault/docs/secrets)
- [Detailed Secrets Engines Reference](references/secrets-engines.md)

---

## When to Use This Skill

- **KV secrets**: Store and retrieve API keys, passwords, configuration
- **Database credentials**: Generate short-lived PostgreSQL, MySQL, MongoDB credentials
- **Cloud credentials**: Generate AWS, Azure, or GCP IAM credentials
- **Encryption**: Encrypt/decrypt data via Transit engine without storing secrets
- **PKI certificates**: Issue TLS certificates from internal CA
- **SSH access**: Generate signed SSH certificates for secure access

---

## Secrets Engine Types

| Type | Examples | Use Case |
|------|----------|----------|
| **Static** | KV v1/v2 | Store arbitrary secrets with versioning |
| **Dynamic** | Database, AWS, Azure, GCP | Generate on-demand credentials with TTLs |
| **Encryption** | Transit | Encrypt/decrypt data without Vault storing it |
| **PKI** | PKI | Issue X.509 certificates |
| **SSH** | SSH | Issue signed SSH certificates |

---

## Quick Reference

### KV Secrets (v2)

```bash
# Enable KV v2
vault secrets enable -version=2 kv

# Write and read secrets
vault kv put secret/myapp key=value password=secret
vault kv get secret/myapp
vault kv get -field=password secret/myapp

# List and delete
vault kv list secret/
vault kv delete secret/myapp
vault kv undelete -versions=1 secret/myapp
```

### Database Dynamic Credentials

```bash
# Enable database secrets engine
vault secrets enable database

# Configure PostgreSQL connection
vault write database/config/postgres \
    plugin_name=postgresql-database-plugin \
    connection_url="postgresql://{{username}}:{{password}}@db:5432/mydb" \
    username="vault" password="vault-password"

# Create role for read-only access
vault write database/roles/readonly \
    db_name=postgres \
    creation_statements="CREATE ROLE \"{{name}}\" LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}'; GRANT SELECT ON ALL TABLES IN SCHEMA public TO \"{{name}}\";" \
    default_ttl=1h max_ttl=24h

# Get dynamic credentials
vault read database/creds/readonly
```

### Transit Encryption

```bash
# Enable Transit
vault secrets enable transit
vault write -f transit/keys/my-key

# Encrypt data
vault write transit/encrypt/my-key plaintext=$(echo "secret data" | base64)
# Returns: ciphertext="vault:v1:..."

# Decrypt data
vault write transit/decrypt/my-key ciphertext="vault:v1:..."
```

### PKI Certificates

```bash
# Enable and configure PKI
vault secrets enable pki
vault write pki/root/generate/internal \
    common_name="Internal Root CA" ttl=87600h

# Create role for issuing certs
vault write pki/roles/web-servers \
    allowed_domains="example.com" \
    allow_subdomains=true max_ttl=72h

# Issue certificate
vault write pki/issue/web-servers common_name="app.example.com"
```

---

## Common Patterns

### Lease Management

All dynamic secrets have leases that control their lifetime:

```bash
vault lease lookup <lease-id>    # Check lease status
vault lease renew <lease-id>     # Extend lease
vault lease revoke <lease-id>    # Revoke immediately
```

### Credential Rotation

```bash
# Rotate root credentials (database)
vault write -f database/rotate-root/postgres

# Rotate Transit key
vault write -f transit/keys/my-key/rotate
```

---

## Best Practices

- **Use dynamic secrets** over static KV when possible
- **Set appropriate TTLs** - short for sensitive credentials (1h or less)
- **Enable KV v2** for versioning and soft-delete capabilities
- **Use Transit** for encryption without secret storage
- **Rotate regularly** - root credentials, encryption keys

---

For detailed configuration examples including AWS, Azure, GCP, SSH, and TOTP engines, see [references/secrets-engines.md](references/secrets-engines.md).
