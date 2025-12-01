# Skill: Generate Vault Policy

## Overview
This skill enables AI agents to generate HashiCorp Vault policies following the principle of least privilege, with proper path-based access control, capabilities, and deny rules.

## Capability Statement
The agent will analyze access requirements and generate Vault policies that:
- Grant minimum necessary permissions
- Use specific path-based rules instead of wildcards
- Include appropriate capabilities (read, create, update, delete, list, sudo, deny)
- Implement deny rules for sensitive paths
- Follow organizational security standards
- Include comprehensive documentation

## Prerequisites
- Understanding of Vault architecture and secret engines
- Knowledge of target secret engine types (KV, Database, PKI, etc.)
- Awareness of organizational security policies
- Familiarity with Vault ACL policy syntax

## Input Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `policy_name` | string | Yes | Descriptive name for the policy |
| `persona` | string | Yes | User role (developer, operator, admin, application) |
| `secret_engines` | array | Yes | List of secret engines to access |
| `paths` | array | Yes | Specific secret paths requiring access |
| `capabilities` | array | No | Allowed capabilities per path |
| `deny_paths` | array | No | Explicitly denied paths |
| `environment` | string | Yes | Target environment (dev, staging, prod) |

## Execution Steps

### 1. Requirements Analysis
```markdown
**Identify Access Patterns**
- What secrets does this persona need to read?
- Do they need to create/update secrets?
- Should they be able to delete or destroy secret versions?
- Do they need list capabilities for secret discovery?
- Are there administrative operations required?

**Determine Scope**
- Which secret engines are in scope?
- What are the specific path patterns?
- Are there environment-specific restrictions?
- What operations should be explicitly denied?
```

### 2. Policy Structure Design

```hcl
# Policy Template Structure
# path "secret_engine/path/pattern" {
#   capabilities = ["capability1", "capability2"]
#   
#   # Optional: parameter constraints
#   allowed_parameters = {
#     "parameter" = ["value1", "value2"]
#   }
#   
#   # Optional: required parameters
#   required_parameters = ["param"]
#   
#   # Optional: denied parameters
#   denied_parameters = {
#     "parameter" = ["forbidden_value"]
#   }
#   
#   # Optional: min/max wrapping TTL
#   min_wrapping_ttl = "1s"
#   max_wrapping_ttl = "90s"
# }
```

### 3. Capability Selection Matrix

| Capability | Use Case | Risk Level |
|------------|----------|------------|
| `read` | Retrieve secret values | Low |
| `list` | Enumerate secrets at path | Low |
| `create` | Create new secrets | Medium |
| `update` | Modify existing secrets | Medium |
| `delete` | Delete secret metadata | High |
| `sudo` | Administrative operations | Critical |
| `deny` | Explicitly forbid access | N/A |

### 4. Policy Generation

## Output Format

### Example 1: Developer Policy (KV Secrets)
```hcl
# Developer policy for application secrets
# Environment: Development
# Scope: Read application configurations, write development secrets

# Read-only access to shared application configurations
path "secret/data/app/config/*" {
  capabilities = ["read", "list"]
}

# Full access to personal development secrets
path "secret/data/dev/{{identity.entity.name}}/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

# Read access to metadata for all dev secrets
path "secret/metadata/dev/*" {
  capabilities = ["read", "list"]
}

# Explicitly deny access to production secrets
path "secret/data/prod/*" {
  capabilities = ["deny"]
}

# Explicitly deny access to other developers' secrets
path "secret/data/dev/+/{{identity.entity.name}}/*" {
  capabilities = ["deny"]
}

# Allow reading database credentials for development environment
path "database/creds/dev-*" {
  capabilities = ["read"]
}

# Deny access to production database credentials
path "database/creds/prod-*" {
  capabilities = ["deny"]
}
```

### Example 2: Application Policy (Database Credentials)
```hcl
# Application policy for web service
# Environment: Production
# Scope: Dynamic database credentials, limited KV access

# Read dynamic database credentials
path "database/creds/webapp-prod" {
  capabilities = ["read"]
}

# Read application-specific secrets
path "secret/data/app/webapp/prod/*" {
  capabilities = ["read"]
}

# List available secrets (metadata only)
path "secret/metadata/app/webapp/prod/*" {
  capabilities = ["list"]
}

# Deny write access to application secrets
path "secret/data/app/webapp/prod/*" {
  capabilities = ["deny"]
  # Note: Deny takes precedence, but we already have read above
  # This documents the intent to prevent writes
}

# Read AWS credentials
path "aws/creds/webapp-prod" {
  capabilities = ["read"]
}

# Explicitly deny access to other applications' secrets
path "secret/data/app/+/webapp/*" {
  capabilities = ["deny"]
}

# Deny access to admin paths
path "auth/token/create" {
  capabilities = ["deny"]
}

path "sys/*" {
  capabilities = ["deny"]
}
```

### Example 3: Operator Policy (Administrative Tasks)
```hcl
# Operator policy for infrastructure team
# Environment: All environments
# Scope: Manage secrets, configure secret engines

# Full access to secret engines configuration
path "sys/mounts/*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}

# Manage KV secrets across environments
path "secret/data/infra/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

path "secret/metadata/infra/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

# Read-only access to application secrets
path "secret/data/app/*" {
  capabilities = ["read", "list"]
}

# Manage database secret engine
path "database/config/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

path "database/roles/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

# Rotate database credentials
path "database/rotate-root/*" {
  capabilities = ["update"]
}

# Manage authentication methods
path "auth/*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}

# View Vault health and metrics
path "sys/health" {
  capabilities = ["read"]
}

path "sys/metrics" {
  capabilities = ["read"]
}

# Manage policies (but not the root policy)
path "sys/policies/acl/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

path "sys/policies/acl/root" {
  capabilities = ["deny"]
}

# Access to audit logs
path "sys/audit" {
  capabilities = ["read", "list"]
}

path "sys/audit/*" {
  capabilities = ["create", "read", "update", "delete", "sudo"]
}

# Token management (limited)
path "auth/token/create" {
  capabilities = ["create", "update"]
  allowed_parameters = {
    "ttl" = ["1h", "2h", "4h"]
  }
}

path "auth/token/lookup-self" {
  capabilities = ["read"]
}

path "auth/token/renew-self" {
  capabilities = ["update"]
}
```

### Example 4: CI/CD Pipeline Policy
```hcl
# CI/CD pipeline policy
# Environment: Staging
# Scope: Deploy secrets to staging environment

# Read application secrets for deployment
path "secret/data/app/*/staging/*" {
  capabilities = ["read", "list"]
}

# Read database credentials
path "database/creds/*-staging" {
  capabilities = ["read"]
}

# Read AWS credentials for deployment
path "aws/creds/deploy-staging" {
  capabilities = ["read"]
}

# Read PKI certificates
path "pki/issue/staging-servers" {
  capabilities = ["create", "update"]
  allowed_parameters = {
    "common_name" = ["*.staging.example.com"]
    "ttl" = ["720h"]  # 30 days max
  }
}

# Explicitly deny production access
path "secret/data/app/*/prod/*" {
  capabilities = ["deny"]
}

path "database/creds/*-prod" {
  capabilities = ["deny"]
}

path "aws/creds/deploy-prod" {
  capabilities = ["deny"]
}

# Deny access to secret engine configuration
path "sys/mounts/*" {
  capabilities = ["deny"]
}

# Allow token self-management
path "auth/token/lookup-self" {
  capabilities = ["read"]
}

path "auth/token/renew-self" {
  capabilities = ["update"]
}
```

## Advanced Features

### Path Templating with Identity
```hcl
# Use identity information in path templates

# Access based on entity name
path "secret/data/users/{{identity.entity.name}}/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

# Access based on entity metadata
path "secret/data/teams/{{identity.entity.metadata.team}}/*" {
  capabilities = ["read", "list"]
}

# Access based on group membership
path "secret/data/groups/{{identity.groups.names}}/*" {
  capabilities = ["read"]
}

# Access based on alias metadata
path "secret/data/env/{{identity.entity.aliases.auth_kubernetes_*.metadata.namespace}}/*" {
  capabilities = ["read"]
}
```

### Parameter Constraints
```hcl
# Restrict secret versions that can be accessed
path "secret/data/app/config" {
  capabilities = ["read"]
  
  # Only allow reading specific versions
  allowed_parameters = {
    "version" = ["1", "2", "3"]
  }
}

# Constrain token creation parameters
path "auth/token/create" {
  capabilities = ["create", "update"]
  
  allowed_parameters = {
    "policies" = ["dev-policy", "app-policy"]
    "ttl" = ["1h", "2h"]
  }
  
  denied_parameters = {
    "period" = ["*"]  # Deny periodic tokens
  }
  
  required_parameters = ["ttl"]
}
```

### Fine-Grained Capabilities
```hcl
# Read specific fields from a secret
path "secret/data/app/database" {
  capabilities = ["read"]
  
  allowed_parameters = {
    "fields" = ["username", "host", "port"]
  }
  
  denied_parameters = {
    "fields" = ["password"]
  }
}

# Limit secret size
path "secret/data/app/*" {
  capabilities = ["create", "update"]
  
  # Max secret size (implementation depends on secret engine)
  max_wrapping_ttl = "90s"
}
```

## Policy Testing

### Test Script
```bash
#!/bin/bash

POLICY_NAME="developer-policy"
POLICY_FILE="policies/${POLICY_NAME}.hcl"

# Write policy to Vault
vault policy write "$POLICY_NAME" "$POLICY_FILE"

# Create test token with policy
TEST_TOKEN=$(vault token create \
  -policy="$POLICY_NAME" \
  -ttl=1h \
  -format=json | jq -r '.auth.client_token')

echo "Test token: $TEST_TOKEN"

# Test allowed operations
echo "Testing allowed read..."
VAULT_TOKEN="$TEST_TOKEN" vault kv get secret/dev/testuser/myapp

# Test denied operations
echo "Testing denied read (should fail)..."
VAULT_TOKEN="$TEST_TOKEN" vault kv get secret/prod/myapp || echo "✓ Correctly denied"

# Test list capability
echo "Testing list capability..."
VAULT_TOKEN="$TEST_TOKEN" vault kv list secret/dev/testuser/

# Cleanup
vault token revoke "$TEST_TOKEN"
```

### Automated Policy Validation
```bash
#!/bin/bash

# Validate policy syntax
vault policy fmt -check "$POLICY_FILE"

# Check for common issues
check_policy_issues() {
  local policy=$1
  
  # Check for overly permissive wildcards
  if grep -q 'path "\*"' "$policy"; then
    echo "⚠️  Warning: Policy uses '*' wildcard"
  fi
  
  # Check for sudo capability without justification
  if grep -q 'capabilities.*sudo' "$policy"; then
    echo "⚠️  Warning: Policy grants sudo capability"
  fi
  
  # Check for root token creation
  if grep -q 'auth/token/create-orphan' "$policy"; then
    echo "❌ Error: Policy allows orphan token creation"
  fi
  
  # Ensure deny rules exist for sensitive paths
  if ! grep -q 'capabilities.*deny' "$policy"; then
    echo "ℹ️  Info: No explicit deny rules found"
  fi
}

check_policy_issues "$POLICY_FILE"
```

## Common Patterns

### Read-Only Application Access
```hcl
path "secret/data/{{identity.entity.metadata.app_name}}/*" {
  capabilities = ["read", "list"]
}
```

### Developer Namespace Isolation
```hcl
path "secret/data/dev/{{identity.entity.name}}/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

path "secret/data/dev/+/{{identity.entity.name}}/*" {
  capabilities = ["deny"]
}
```

### Environment-Based Restrictions
```hcl
# Grant access to non-prod environments
path "secret/data/app/{{identity.entity.metadata.app_name}}/dev/*" {
  capabilities = ["read"]
}

path "secret/data/app/{{identity.entity.metadata.app_name}}/staging/*" {
  capabilities = ["read"]
}

# Deny production access
path "secret/data/app/{{identity.entity.metadata.app_name}}/prod/*" {
  capabilities = ["deny"]
}
```

## Best Practices

1. **Principle of Least Privilege**: Grant only required permissions
2. **Explicit Deny**: Use deny rules for sensitive paths
3. **Path Specificity**: Avoid broad wildcards, use specific paths
4. **Template Variables**: Use identity-based templating for dynamic access
5. **Capability Precision**: Grant specific capabilities, not blanket access
6. **Documentation**: Comment policies with purpose and scope
7. **Regular Review**: Audit and update policies periodically
8. **Testing**: Validate policies before production deployment

## Error Handling

### Common Issues

**Issue: Policy too permissive**
```hcl
# ❌ Bad: Overly broad access
path "secret/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

# ✅ Good: Specific path access
path "secret/data/app/myapp/{{identity.entity.metadata.env}}/*" {
  capabilities = ["read", "list"]
}
```

**Issue: Missing deny rules**
```hcl
# ✅ Always include explicit denies for sensitive paths
path "secret/data/prod/*" {
  capabilities = ["deny"]
}

path "sys/raw/*" {
  capabilities = ["deny"]
}
```

**Issue: Conflicting rules**
```hcl
# ❌ Conflicting capabilities (deny wins)
path "secret/data/app/*" {
  capabilities = ["read"]
}

path "secret/data/app/*" {
  capabilities = ["deny"]  # This denies all access
}
```

## Related Skills
- [Read Secret Securely](../read-secret-securely/SKILL.md)
- [Policy Auditing](../audit-policies/SKILL.md)

## Resources
- [Policy Examples](./resources/policy-examples.hcl)
- [Vault ACL Documentation](https://developer.hashicorp.com/vault/docs/concepts/policies)

## Success Metrics
- Policy grants minimum necessary access
- All sensitive paths have explicit deny rules
- Policy uses specific paths, not broad wildcards
- Template variables used for dynamic access
- Policy tested with actual tokens
- Documentation includes scope and purpose

## Revision History

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | 2025-11-07 | Initial skill definition |
