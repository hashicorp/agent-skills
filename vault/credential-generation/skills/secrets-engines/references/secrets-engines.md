---
name: vault-secrets-engines
description: Detailed configuration for Vault secrets engines including KV, Database, AWS, Transit, PKI, and SSH
---

# Vault Secrets Engines

This reference provides detailed configuration for Vault's secrets engines.

---

## Overview

Secrets engines are components that store, generate, or encrypt data. They are enabled at **paths** and all operations are relative to that path.

### Types of Secrets Engines

- **Static secrets**: Store arbitrary data (KV engine)
- **Dynamic secrets**: Generate credentials on-demand with automatic revocation
- **Encryption**: Encrypt/decrypt without storing data (Transit)
- **Certificates**: Issue PKI certificates

---

## KV (Key-Value) Secrets Engine

Store arbitrary static secrets.

### KV Version 2 (Recommended)

Supports versioning, metadata, and check-and-set operations.

```bash
# Enable KV v2
vault secrets enable -path=secret kv-v2

# Write secret
vault kv put secret/myapp/config \
    username="admin" \
    password="secret123" \
    api_key="abc123"

# Read secret
vault kv get secret/myapp/config
vault kv get -field=password secret/myapp/config
vault kv get -format=json secret/myapp/config

# Read specific version
vault kv get -version=2 secret/myapp/config

# List secrets
vault kv list secret/
vault kv list secret/myapp/

# Update (creates new version)
vault kv put secret/myapp/config password="newpassword"

# Patch (update specific fields)
vault kv patch secret/myapp/config api_key="xyz789"

# Delete (soft delete current version)
vault kv delete secret/myapp/config

# Undelete
vault kv undelete -versions=3 secret/myapp/config

# Destroy (permanent)
vault kv destroy -versions=1,2 secret/myapp/config

# Metadata
vault kv metadata get secret/myapp/config
vault kv metadata put -max-versions=5 secret/myapp/config
vault kv metadata delete secret/myapp/config
```

### KV Version 1

Simple key-value without versioning.

```bash
vault secrets enable -path=kv -version=1 kv

vault write kv/myapp/config key=value
vault read kv/myapp/config
vault delete kv/myapp/config
```

---

## Database Secrets Engine

Generate dynamic database credentials with automatic expiration.

### Supported Databases

- PostgreSQL, MySQL, MariaDB, MongoDB
- Microsoft SQL Server, Oracle
- Cassandra, Couchbase, Elasticsearch
- Redis, Snowflake, InfluxDB

### PostgreSQL Configuration

```bash
# Enable database engine
vault secrets enable database

# Configure PostgreSQL connection
vault write database/config/my-postgres \
    plugin_name=postgresql-database-plugin \
    allowed_roles="readonly,readwrite" \
    connection_url="postgresql://{{username}}:{{password}}@db.example.com:5432/mydb?sslmode=require" \
    username="vault_admin" \
    password="vault_password"

# Rotate root credentials (recommended)
vault write -f database/rotate-root/my-postgres
```

### Create Roles

```bash
# Read-only role
vault write database/roles/readonly \
    db_name=my-postgres \
    creation_statements="CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}'; GRANT SELECT ON ALL TABLES IN SCHEMA public TO \"{{name}}\";" \
    revocation_statements="DROP ROLE IF EXISTS \"{{name}}\";" \
    default_ttl="1h" \
    max_ttl="24h"

# Read-write role
vault write database/roles/readwrite \
    db_name=my-postgres \
    creation_statements="CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}'; GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO \"{{name}}\";" \
    default_ttl="1h" \
    max_ttl="24h"
```

### Generate Credentials

```bash
# Get dynamic credentials (new user created)
vault read database/creds/readonly

# Output:
# Key                Value
# ---                -----
# lease_id           database/creds/readonly/abcd1234
# lease_duration     1h
# username           v-token-readonly-xyz123
# password           A1b2C3d4E5f6G7h8
```

### MySQL Configuration

```bash
vault write database/config/my-mysql \
    plugin_name=mysql-database-plugin \
    allowed_roles="app" \
    connection_url="{{username}}:{{password}}@tcp(mysql.example.com:3306)/" \
    username="vault" \
    password="password"

vault write database/roles/app \
    db_name=my-mysql \
    creation_statements="CREATE USER '{{name}}'@'%' IDENTIFIED BY '{{password}}'; GRANT SELECT, INSERT, UPDATE ON mydb.* TO '{{name}}'@'%';" \
    default_ttl="1h" \
    max_ttl="24h"
```

### MongoDB Configuration

```bash
vault write database/config/my-mongodb \
    plugin_name=mongodb-database-plugin \
    allowed_roles="app" \
    connection_url="mongodb://{{username}}:{{password}}@mongo.example.com:27017/admin" \
    username="vault" \
    password="password"

vault write database/roles/app \
    db_name=my-mongodb \
    creation_statements='{"db": "mydb", "roles": [{"role": "readWrite"}]}' \
    default_ttl="1h"
```

### Database Engine Best Practices

Based on production deployments across enterprises:

| Practice | Recommendation | Why |
| ---------- | --------------- | ----- |
| Root Rotation | Always rotate after configuration | Vault owns only credential |
| Dedicated Users | One Vault user per database connection | Isolation and audit trail |
| TTL Strategy | 1h default, 24h max for applications | Balance security vs. overhead |
| Static Roles | Use for legacy apps that can't handle dynamic | Only when necessary |
| Connection Pooling | Configure pool size based on expected load | Prevent connection exhaustion |

#### Dedicated Vault User Setup (PostgreSQL)

```sql
-- Create a dedicated Vault admin user (NEVER use DBA account)
CREATE ROLE vault_admin WITH LOGIN PASSWORD 'initial_password';

-- Grant minimum required permissions
GRANT CREATE ROLE TO vault_admin;
GRANT CONNECT ON DATABASE mydb TO vault_admin;

-- For revoking dynamic users
ALTER DEFAULT PRIVILEGES IN SCHEMA public 
  GRANT ALL ON TABLES TO vault_admin;
```

#### Static Roles (When Dynamic Not Possible)

```bash
# For legacy applications that cache connections
vault write database/static-roles/legacy-app \
    db_name=my-postgres \
    username="legacy_app_user" \
    rotation_period="24h"

# Vault rotates password on schedule
# Application must reconnect after rotation
```

#### Dynamic vs Static Role Decision

| Factor | Dynamic Roles | Static Roles |
| -------- | -------------- | -------------- |
| Application Type | Modern, cloud-native | Legacy, long-lived connections |
| Rotation Frequency | Per-connection | Scheduled interval |
| Audit Granularity | Per-request attribution | Shared user attribution |
| Complexity | Requires lease management | Simpler, less secure |

---

## AWS Secrets Engine

Generate dynamic AWS credentials.

### Configuration

```bash
vault secrets enable aws

# Configure root credentials
vault write aws/config/root \
    access_key=<access-key> \
    secret_key=<secret-key> \
    region=us-east-1

# Configure lease settings
vault write aws/config/lease \
    lease=30m \
    lease_max=1h
```

### IAM User Credentials

```bash
vault write aws/roles/deploy \
    credential_type=iam_user \
    policy_document=-<<EOF
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Action": ["s3:*", "ec2:Describe*"],
    "Resource": "*"
  }]
}
EOF

# Generate credentials
vault read aws/creds/deploy
```

### Assumed Role Credentials

```bash
vault write aws/roles/app-role \
    credential_type=assumed_role \
    role_arns="arn:aws:iam::ACCOUNT:role/AppRole" \
    default_sts_ttl=1h \
    max_sts_ttl=4h

vault read aws/creds/app-role
```

### Web Identity Federation (WIF)

Use OIDC identity providers instead of static credentials:

```bash
# Configure with WIF (no static credentials needed)
vault write aws/config/root \
    identity_token_audience="sts.amazonaws.com" \
    role_arn="arn:aws:iam::ACCOUNT:role/VaultRole"
```

### Static Roles (Cross-Account Management)

Manage static IAM user credentials with automatic rotation:

```bash
# Create static role for existing IAM user
vault write aws/static-roles/ops-user \
    username="operations-user" \
    rotation_period="24h"

# Get current credentials (auto-rotated)
vault read aws/static-creds/ops-user

# Configure cross-account access
vault write aws/config/sts/target-account-id \
    sts_role="arn:aws:iam::TARGET-ACCOUNT:role/VaultCrossAccountRole"
```

### Federation Token

```bash
vault write aws/roles/fed-token \
    credential_type=federation_token \
    policy_document=-<<EOF
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Action": "s3:GetObject",
    "Resource": "arn:aws:s3:::mybucket/*"
  }]
}
EOF
```

---

## Azure Secrets Engine

Generate dynamic Azure credentials.

```bash
vault secrets enable azure

vault write azure/config \
    subscription_id=<subscription-id> \
    tenant_id=<tenant-id> \
    client_id=<client-id> \
    client_secret=<client-secret>

vault write azure/roles/contributor \
    azure_roles=-<<EOF
[{
  "role_name": "Contributor",
  "scope": "/subscriptions/<subscription-id>/resourceGroups/myRG"
}]
EOF

vault read azure/creds/contributor
```

---

## GCP Secrets Engine

Generate dynamic GCP credentials.

```bash
vault secrets enable gcp

vault write gcp/config credentials=@gcp-credentials.json

# Service account key
vault write gcp/roleset/my-app \
    project="my-project" \
    secret_type="service_account_key" \
    bindings=-<<EOF
resource "//cloudresourcemanager.googleapis.com/projects/my-project" {
  roles = ["roles/storage.objectViewer"]
}
EOF

vault read gcp/key/my-app

# Access token
vault write gcp/roleset/token-app \
    project="my-project" \
    secret_type="access_token" \
    bindings=-<<EOF
resource "//cloudresourcemanager.googleapis.com/projects/my-project" {
  roles = ["roles/compute.viewer"]
}
EOF

vault read gcp/token/token-app
```

---

## Transit Secrets Engine (Encryption-as-a-Service)

Encrypt/decrypt data without storing it in Vault.

### Enable and Create Keys

```bash
vault secrets enable transit

# Create encryption key
vault write -f transit/keys/my-key

# Create key with specific type
vault write -f transit/keys/rsa-key type=rsa-4096

# Key types: aes256-gcm96, chacha20-poly1305, 
#            ed25519, ecdsa-p256, rsa-2048, rsa-4096
```

### Encrypt/Decrypt

```bash
# Encrypt (plaintext must be base64 encoded)
vault write transit/encrypt/my-key \
    plaintext=$(echo "my secret data" | base64)

# Returns: ciphertext = vault:v1:xyz...

# Decrypt
vault write transit/decrypt/my-key \
    ciphertext="vault:v1:xyz..."

# Returns base64-encoded plaintext
echo "<base64-plaintext>" | base64 -d
```

### Key Rotation

```bash
# Rotate key (new version for encryption)
vault write -f transit/keys/my-key/rotate

# Set minimum decryption version
vault write transit/keys/my-key/config \
    min_decryption_version=2

# Rewrap ciphertext with latest key version
vault write transit/rewrap/my-key \
    ciphertext="vault:v1:xyz..."
```

### Bring Your Own Key (BYOK)

Import existing keys into Transit:

```bash
# Get wrapping key from Vault
vault read -field=public_key transit/wrapping_key > wrapping_key.pem

# Wrap your key material (external process)
# Then import the wrapped key
vault write transit/keys/imported-key/import \
    ciphertext=@wrapped_key.txt \
    type=aes256-gcm96

# Import plaintext key (not recommended for production)
vault write transit/keys/imported-key/import \
    key="base64-encoded-key" \
    type=aes256-gcm96
```

### Additional Operations

```bash
# Sign data
vault write transit/sign/my-key \
    input=$(echo "data to sign" | base64)

# Verify signature
vault write transit/verify/my-key \
    input=$(echo "data to sign" | base64) \
    signature="vault:v1:xyz..."

# Generate random bytes
vault write -f transit/random/32

# Hash data
vault write transit/hash/sha2-256 \
    input=$(echo "data to hash" | base64)
```

---

## PKI Secrets Engine (Certificate Authority)

Issue TLS certificates.

### Root CA Setup

```bash
vault secrets enable pki

# Set max TTL
vault secrets tune -max-lease-ttl=87600h pki

# Generate root CA
vault write pki/root/generate/internal \
    common_name="My Root CA" \
    issuer_name="root-2024" \
    ttl=87600h

# Configure URLs
vault write pki/config/urls \
    issuing_certificates="https://vault.example.com:8200/v1/pki/ca" \
    crl_distribution_points="https://vault.example.com:8200/v1/pki/crl"
```

### Intermediate CA Setup

```bash
vault secrets enable -path=pki_int pki
vault secrets tune -max-lease-ttl=43800h pki_int

# Generate CSR
vault write -format=json pki_int/intermediate/generate/internal \
    common_name="My Intermediate CA" \
    issuer_name="intermediate-2024" \
    | jq -r '.data.csr' > pki_int.csr

# Sign with root
vault write -format=json pki/root/sign-intermediate \
    csr=@pki_int.csr \
    format=pem_bundle \
    ttl=43800h \
    | jq -r '.data.certificate' > signed_int.pem

# Import signed certificate
vault write pki_int/intermediate/set-signed \
    certificate=@signed_int.pem
```

### Create Roles and Issue Certificates

```bash
# Create role
vault write pki_int/roles/web-servers \
    allowed_domains="example.com" \
    allow_subdomains=true \
    allow_bare_domains=false \
    max_ttl=720h

# Issue certificate
vault write pki_int/issue/web-servers \
    common_name="web.example.com" \
    alt_names="www.example.com" \
    ttl=72h

# Output includes: certificate, issuing_ca, private_key
```

### PKI Performance & Storage Optimization

Based on production deployments issuing millions of certificates:

| Setting | Value | Impact |
| --------- | ------- | -------- |
| `no_store` | true | Don't store issued certs (massive storage savings) |
| `generate_lease` | false | Skip lease tracking for certs (performance) |
| TTL Strategy | Short (24-72h) | Reduces CRL size, forces rotation |

#### High-Volume PKI Configuration

```bash
# Role optimized for high-volume issuance
vault write pki_int/roles/high-volume \
    allowed_domains="example.com" \
    allow_subdomains=true \
    max_ttl=72h \
    no_store=true \
    generate_lease=false

# When NOT to use no_store=true:
# - Need to list/revoke individual certificates
# - Compliance requires certificate inventory
# - Using CRL-based revocation
```

#### Certificate Revocation Strategies

| Strategy | When to Use | Configuration |
| ---------- | ------------- | --------------- |
| Short TTLs | Modern microservices | TTL < 24h, no revocation needed |
| OCSP | Standard PKI requirements | Enable OCSP responder |
| CRL | Legacy systems | Keep CRLs small with short TTLs |
| Delta CRL | Large deployments | Reduces CRL transfer size |

```bash
# Configure OCSP responder
vault write pki_int/config/urls \
    ocsp_servers="https://vault.example.com:8200/v1/pki_int/ocsp"

# Configure CRL settings
vault write pki_int/config/crl \
    expiry="72h" \
    disable=false
```

---

## SSH Secrets Engine

Manage SSH access using OTP or signed certificates.

### Signed Certificates (Recommended)

```bash
vault secrets enable ssh

# Generate CA key pair
vault write ssh/config/ca generate_signing_key=true

# Get public key (add to target servers)
vault read -field=public_key ssh/config/ca > vault-ssh-ca.pub

# On target servers, add to /etc/ssh/sshd_config:
# TrustedUserCAKeys /etc/ssh/vault-ssh-ca.pub

# Create role
vault write ssh/roles/admin \
    key_type=ca \
    allowed_users="ubuntu,admin" \
    default_user=ubuntu \
    allowed_extensions="permit-pty,permit-agent-forwarding" \
    ttl=30m \
    max_ttl=4h

# Sign user's public key
vault write ssh/sign/admin \
    public_key=@~/.ssh/id_rsa.pub

# SSH with signed certificate
ssh -i ~/.ssh/id_rsa -i ~/.ssh/id_rsa-cert.pub user@host
```

### One-Time Password (OTP)

```bash
vault write ssh/roles/otp-role \
    key_type=otp \
    default_user=ubuntu \
    cidr_list="10.0.0.0/8"

# Generate OTP
vault write ssh/creds/otp-role ip=10.0.0.5

# Use vault ssh helper
vault ssh -role=otp-role -mode=otp user@10.0.0.5
```

### SSH CA Migration Best Practices

When migrating to Vault SSH CA, follow this approach:

#### Phase 1: Parallel Operation

```bash
# 1. Configure Vault CA on target servers (alongside existing auth)
echo "TrustedUserCAKeys /etc/ssh/vault-ssh-ca.pub" >> /etc/ssh/sshd_config

# 2. Keep authorized_keys files temporarily
# Both methods will work during transition

# 3. Create Vault roles matching existing access patterns
vault write ssh/roles/admin \
    key_type=ca \
    allowed_users="ubuntu,admin,deploy" \
    default_user=ubuntu \
    ttl=30m \
    max_ttl=4h
```

#### Phase 2: Remove Static Keys

```bash
# CRITICAL: Only after verifying Vault SSH CA works

# Remove authorized_keys files
rm /home/*/.ssh/authorized_keys
rm /root/.ssh/authorized_keys

# Prevent new authorized_keys files
echo "AuthorizedKeysFile none" >> /etc/ssh/sshd_config

# Restart SSH
systemctl restart sshd
```

#### SSH CA Role Security Settings

| Setting | Recommended | Why |
| --------- | ------------- | ----- |
| `ttl` | 30m | Short-lived certificates |
| `max_ttl` | 4h | Limit maximum extension |
| `allowed_users` | Explicit list | No wildcards in production |
| `allowed_extensions` | Minimal set | Only required features |
| `default_extensions` | Empty or minimal | Security by default |

---

## TOTP Secrets Engine

Generate time-based one-time passwords.

```bash
vault secrets enable totp

# Create key (returns QR code URL)
vault write totp/keys/my-app \
    url="otpauth://totp/Vault:myuser@example.com?secret=BASE32SECRET&issuer=Vault"

# Or generate a new key
vault write totp/keys/my-app \
    generate=true \
    issuer="MyApp" \
    account_name="user@example.com"

# Generate code
vault read totp/code/my-app

# Validate code
vault write totp/code/my-app code=123456
```

---

## Comparison Table

| Engine | Type | Use Case | Rotation |
| -------- | ------ | ---------- | ---------- |
| **KV** | Static | Arbitrary secrets | Manual |
| **Database** | Dynamic | DB credentials | Automatic |
| **AWS** | Dynamic | AWS access | Automatic |
| **Azure** | Dynamic | Azure access | Automatic |
| **GCP** | Dynamic | GCP access | Automatic |
| **Transit** | Encryption | Encrypt/decrypt | Key versioning |
| **PKI** | Certificates | TLS certs | By TTL |
| **SSH** | Access | SSH credentials | Automatic |

---

## Additional Resources

- [Secrets Engines Documentation](https://developer.hashicorp.com/vault/docs/secrets)
- [Dynamic Secrets Tutorial](https://developer.hashicorp.com/vault/tutorials/db-credentials)
- [PKI Tutorial](https://developer.hashicorp.com/vault/tutorials/secrets-management/pki-engine)

---

## Related

- [Policies](policies.md) - Control access to secrets engines
- [Production Operations](production-operations.md) - Monitoring and performance tuning
- [Enterprise](enterprise.md) - Namespace isolation for secrets
