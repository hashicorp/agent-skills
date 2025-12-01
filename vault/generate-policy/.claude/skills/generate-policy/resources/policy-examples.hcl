# Vault Policy Examples

## Table of Contents
1. [Application Policies](#application-policies)
2. [User Policies](#user-policies)
3. [Operator Policies](#operator-policies)
4. [CI/CD Policies](#cicd-policies)
5. [Advanced Patterns](#advanced-patterns)

---

## Application Policies

### Web Application (Database + KV Secrets)
```hcl
# Policy: webapp-prod
# Purpose: Production web application access to database credentials and configuration
# Environment: Production

# Read dynamic PostgreSQL credentials
path "database/creds/webapp-postgres-prod" {
  capabilities = ["read"]
}

# Read application configuration secrets
path "secret/data/applications/webapp/prod/config" {
  capabilities = ["read"]
}

# Read API keys
path "secret/data/applications/webapp/prod/api-keys/*" {
  capabilities = ["read", "list"]
}

# Read AWS credentials for S3 access
path "aws/creds/webapp-s3-access" {
  capabilities = ["read"]
}

# Renew own token
path "auth/token/renew-self" {
  capabilities = ["update"]
}

# Lookup own token
path "auth/token/lookup-self" {
  capabilities = ["read"]
}

# Revoke own token
path "auth/token/revoke-self" {
  capabilities = ["update"]
}

# Deny access to other applications
path "secret/data/applications/+/webapp/*" {
  capabilities = ["deny"]
}

# Deny administrative access
path "sys/*" {
  capabilities = ["deny"]
}
```

### Microservice with PKI Certificates
```hcl
# Policy: api-service-prod
# Purpose: Issue mTLS certificates for inter-service communication
# Environment: Production

# Issue certificates from PKI backend
path "pki_int/issue/api-service" {
  capabilities = ["create", "update"]
  
  # Restrict certificate parameters
  allowed_parameters = {
    "common_name" = ["api.prod.internal.example.com", "*.api.prod.internal.example.com"]
    "ttl" = ["24h", "48h", "72h"]
  }
  
  denied_parameters = {
    "ttl" = ["8760h"]  # Deny 1-year certificates
  }
  
  required_parameters = ["common_name", "ttl"]
}

# Read service-specific secrets
path "secret/data/services/api/prod/*" {
  capabilities = ["read", "list"]
}

# Read database credentials
path "database/creds/api-readonly-prod" {
  capabilities = ["read"]
}

# Deny write access
path "secret/data/*" {
  capabilities = ["deny"]
}

path "pki_int/config/*" {
  capabilities = ["deny"]
}
```

---

## User Policies

### Developer Policy
```hcl
# Policy: developer
# Purpose: Development team access to non-production secrets
# Scope: Read shared configs, manage personal dev secrets

# Full access to personal development namespace
path "secret/data/dev/{{identity.entity.name}}/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

path "secret/metadata/dev/{{identity.entity.name}}/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

# Read-only access to shared development configurations
path "secret/data/shared/dev/*" {
  capabilities = ["read", "list"]
}

# Read-only access to staging application configs
path "secret/data/applications/*/staging/*" {
  capabilities = ["read", "list"]
}

# Read development database credentials
path "database/creds/*-dev" {
  capabilities = ["read"]
}

# Issue development certificates
path "pki_int/issue/dev-servers" {
  capabilities = ["create", "update"]
  
  allowed_parameters = {
    "common_name" = ["*.dev.example.com"]
    "ttl" = ["24h"]
  }
}

# Explicitly deny production access
path "secret/data/applications/*/prod/*" {
  capabilities = ["deny"]
}

path "secret/data/shared/prod/*" {
  capabilities = ["deny"]
}

path "database/creds/*-prod" {
  capabilities = ["deny"]
}

# Deny access to other developers' namespaces
path "secret/data/dev/+/{{identity.entity.name}}/*" {
  capabilities = ["deny"]
}

# Token self-management
path "auth/token/lookup-self" {
  capabilities = ["read"]
}

path "auth/token/renew-self" {
  capabilities = ["update"]
}

# Deny system configuration access
path "sys/*" {
  capabilities = ["deny"]
}

path "auth/*" {
  capabilities = ["deny"]
}
```

### Security Team Policy
```hcl
# Policy: security-team
# Purpose: Security team administrative access with audit capabilities
# Scope: Read all secrets, manage policies, access audit logs

# Read-only access to all secrets
path "secret/data/*" {
  capabilities = ["read", "list"]
}

path "secret/metadata/*" {
  capabilities = ["read", "list"]
}

# Manage ACL policies
path "sys/policies/acl/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

# Deny modifying root policy
path "sys/policies/acl/root" {
  capabilities = ["deny"]
}

# Access audit configuration and logs
path "sys/audit" {
  capabilities = ["read", "list", "sudo"]
}

path "sys/audit/*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}

# Read authentication configuration
path "auth/*" {
  capabilities = ["read", "list"]
}

# View secret engine configuration
path "sys/mounts" {
  capabilities = ["read"]
}

path "sys/mounts/*" {
  capabilities = ["read"]
}

# Access identity information
path "identity/*" {
  capabilities = ["read", "list"]
}

# View encryption key status
path "sys/rotate" {
  capabilities = ["read"]
}

path "sys/key-status" {
  capabilities = ["read"]
}

# Access health endpoints
path "sys/health" {
  capabilities = ["read"]
}

path "sys/metrics" {
  capabilities = ["read"]
}

# Deny raw storage access
path "sys/raw/*" {
  capabilities = ["deny"]
}
```

---

## Operator Policies

### Platform Operator Policy
```hcl
# Policy: platform-operator
# Purpose: Infrastructure team access to configure Vault
# Scope: Manage secret engines, auth methods, policies

# Full access to secret engine management
path "sys/mounts/*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}

path "sys/mounts" {
  capabilities = ["read", "list"]
}

# Full access to authentication methods
path "sys/auth/*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}

path "sys/auth" {
  capabilities = ["read", "list"]
}

# Manage policies (except root)
path "sys/policies/acl/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

path "sys/policies/acl/root" {
  capabilities = ["deny"]
}

# Configure audit devices
path "sys/audit/*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}

# Manage leases
path "sys/leases/lookup/*" {
  capabilities = ["read", "list"]
}

path "sys/leases/revoke/*" {
  capabilities = ["update"]
}

path "sys/leases/revoke-prefix/*" {
  capabilities = ["update", "sudo"]
}

# Key rotation and rekey operations
path "sys/rotate" {
  capabilities = ["update", "sudo"]
}

path "sys/rekey/*" {
  capabilities = ["update", "sudo"]
}

# Manage identity entities and groups
path "identity/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

# Health and metrics
path "sys/health" {
  capabilities = ["read"]
}

path "sys/metrics" {
  capabilities = ["read"]
}

# Seal status
path "sys/seal-status" {
  capabilities = ["read"]
}

# Unseal (requires unseal keys, policy grants capability)
path "sys/unseal" {
  capabilities = ["update", "sudo"]
}

# Seal Vault (emergency)
path "sys/seal" {
  capabilities = ["update", "sudo"]
}

# Full access to infrastructure secrets
path "secret/data/infrastructure/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

path "secret/metadata/infrastructure/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

# Read-only access to application secrets
path "secret/data/applications/*" {
  capabilities = ["read", "list"]
}

# Configure database secret engine
path "database/config/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

path "database/roles/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

path "database/rotate-root/*" {
  capabilities = ["update"]
}

# Explicitly deny raw storage access
path "sys/raw/*" {
  capabilities = ["deny"]
}

# Deny generating root tokens
path "sys/generate-root/*" {
  capabilities = ["deny"]
}
```

---

## CI/CD Policies

### Deployment Pipeline Policy
```hcl
# Policy: deploy-staging
# Purpose: Automated deployment to staging environment
# Scope: Read secrets, issue certificates, access AWS credentials

# Read application secrets for deployment
path "secret/data/applications/*/staging/*" {
  capabilities = ["read", "list"]
}

# Read shared staging configuration
path "secret/data/shared/staging/*" {
  capabilities = ["read", "list"]
}

# Read staging database credentials
path "database/creds/*-staging" {
  capabilities = ["read"]
}

# Issue AWS credentials for staging deployment
path "aws/creds/deploy-staging" {
  capabilities = ["read"]
}

# Issue short-lived TLS certificates
path "pki_int/issue/staging-servers" {
  capabilities = ["create", "update"]
  
  allowed_parameters = {
    "common_name" = ["*.staging.example.com"]
    "ttl" = ["168h"]  # 7 days
  }
}

# Read Kubernetes auth role
path "auth/kubernetes/role/deploy-staging" {
  capabilities = ["read"]
}

# Token renewal
path "auth/token/renew-self" {
  capabilities = ["update"]
}

# Explicitly deny production access
path "secret/data/applications/*/prod/*" {
  capabilities = ["deny"]
}

path "database/creds/*-prod" {
  capabilities = ["deny"]
}

path "aws/creds/deploy-prod" {
  capabilities = ["deny"]
}

# Deny configuration changes
path "sys/*" {
  capabilities = ["deny"]
}

path "auth/kubernetes/config" {
  capabilities = ["deny"]
}
```

### Terraform Automation Policy
```hcl
# Policy: terraform-automation
# Purpose: Terraform automation for secret management
# Scope: Manage secrets, configure secret engines (non-production)

# Full access to Terraform-managed secrets
path "secret/data/terraform/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

path "secret/metadata/terraform/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

# Configure secret engines for non-prod
path "sys/mounts/secret" {
  capabilities = ["read"]
}

path "sys/mounts/database" {
  capabilities = ["read", "update"]
}

# Configure database secret engine
path "database/config/*" {
  capabilities = ["create", "read", "update", "delete"]
}

path "database/roles/*-dev" {
  capabilities = ["create", "read", "update", "delete"]
}

path "database/roles/*-staging" {
  capabilities = ["create", "read", "update", "delete"]
}

# Deny production database role configuration
path "database/roles/*-prod" {
  capabilities = ["deny"]
}

# Read policies to validate configuration
path "sys/policies/acl/*" {
  capabilities = ["read", "list"]
}

# Manage Terraform-specific policies
path "sys/policies/acl/terraform-*" {
  capabilities = ["create", "read", "update", "delete"]
}

# Token management
path "auth/token/create" {
  capabilities = ["create", "update"]
  
  allowed_parameters = {
    "policies" = ["terraform-automation"]
    "ttl" = ["1h"]
  }
}

path "auth/token/renew-self" {
  capabilities = ["update"]
}

# Deny administrative operations
path "sys/audit/*" {
  capabilities = ["deny"]
}

path "sys/auth/*" {
  capabilities = ["deny"]
}
```

---

## Advanced Patterns

### Multi-Tenant Isolation
```hcl
# Policy: tenant-{{identity.entity.metadata.tenant_id}}
# Purpose: Isolate secrets by tenant ID
# Scope: Access only to tenant-specific secrets

# Full access to tenant namespace
path "secret/data/tenants/{{identity.entity.metadata.tenant_id}}/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

path "secret/metadata/tenants/{{identity.entity.metadata.tenant_id}}/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

# Read shared resources
path "secret/data/shared/all-tenants/*" {
  capabilities = ["read", "list"]
}

# Deny access to other tenants
path "secret/data/tenants/+/{{identity.entity.metadata.tenant_id}}/*" {
  capabilities = ["deny"]
}

# Tenant-specific database credentials
path "database/creds/tenant-{{identity.entity.metadata.tenant_id}}-*" {
  capabilities = ["read"]
}
```

### Time-Based Access Control
```hcl
# Policy: business-hours-only
# Purpose: Restrict access to business hours (requires external validation)
# Scope: Conditional access based on time (Sentinel policy in Enterprise)

# Note: This requires Vault Enterprise with Sentinel
# Basic policy grants access; Sentinel EGP enforces time restrictions

path "secret/data/sensitive/*" {
  capabilities = ["read"]
  
  # Metadata for Sentinel policy
  # sentinel {
  #   enforcement_level = "hard-mandatory"
  #   policy_name = "business-hours-check"
  # }
}
```

### Dynamic Secret Versioning
```hcl
# Policy: version-controlled-access
# Purpose: Control access to specific secret versions
# Scope: Read current and previous versions only

# Read current version
path "secret/data/app/config" {
  capabilities = ["read"]
}

# Read metadata (all versions)
path "secret/metadata/app/config" {
  capabilities = ["read", "list"]
}

# Read specific versions
path "secret/data/app/config" {
  capabilities = ["read"]
  
  allowed_parameters = {
    "version" = ["0"]  # Current version
  }
}

# Destroy old versions
path "secret/destroy/app/config" {
  capabilities = ["update"]
  
  allowed_parameters = {
    "versions" = ["1", "2", "3", "4", "5"]  # Old versions only
  }
}

# Deny destroying current version
path "secret/destroy/app/config" {
  capabilities = ["deny"]
  
  denied_parameters = {
    "versions" = ["0"]  # Current version
  }
}
```

### Break-Glass Emergency Access
```hcl
# Policy: break-glass-admin
# Purpose: Emergency administrative access with audit trail
# Scope: Full access with mandatory wrapping for audit

# Full read access to secrets
path "secret/data/*" {
  capabilities = ["read", "list"]
  
  # Require response wrapping for audit
  min_wrapping_ttl = "1s"
  max_wrapping_ttl = "90s"
}

# Administrative capabilities
path "sys/*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}

path "auth/*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}

# Explicit denies for irreversible operations
path "sys/raw/*" {
  capabilities = ["deny"]
}

path "sys/step-down" {
  capabilities = ["deny"]
}
```

---

## Policy Composition Examples

### Combining Multiple Policies
```bash
# Create token with multiple policies
vault token create \
  -policy=developer \
  -policy=database-read \
  -policy=aws-s3-access \
  -ttl=8h
```

### Policy Inheritance
```hcl
# Base policy: base-user
path "auth/token/lookup-self" {
  capabilities = ["read"]
}

path "auth/token/renew-self" {
  capabilities = ["update"]
}

path "auth/token/revoke-self" {
  capabilities = ["update"]
}

# Extended policy: extended-developer
# Inherits base-user + adds developer access
# Apply both policies to token
```

---

## Testing Policies

```bash
#!/bin/bash

# Test policy before deployment
POLICY_FILE="policy.hcl"
TEST_PATH="secret/data/test/path"

# Write policy
vault policy write test-policy "$POLICY_FILE"

# Create test token
TOKEN=$(vault token create -policy=test-policy -format=json | jq -r '.auth.client_token')

# Test read access
VAULT_TOKEN="$TOKEN" vault kv get secret/test/path

# Test write access
VAULT_TOKEN="$TOKEN" vault kv put secret/test/path value=test

# Cleanup
vault token revoke "$TOKEN"
vault policy delete test-policy
```

---

## Best Practices Summary

1. **Least Privilege**: Grant minimum required access
2. **Explicit Deny**: Block sensitive paths explicitly
3. **Path Specificity**: Use precise paths, avoid wildcards
4. **Template Variables**: Leverage identity-based access
5. **Parameter Constraints**: Restrict allowed values
6. **Documentation**: Comment purpose and scope
7. **Testing**: Validate before production
8. **Audit**: Regular policy reviews
9. **Versioning**: Track policy changes in version control
10. **Separation**: Different policies for different environments
