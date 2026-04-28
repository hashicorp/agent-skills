---
name: auth-methods
description: Configure Vault authentication methods. Use when asked about AppRole, Kubernetes auth, OIDC/JWT, AWS IAM auth, Azure auth, GCP auth, LDAP, GitHub auth, or the trusted broker pattern. Covers identity verification and token generation.
---

# Vault Authentication Methods

## What Are You Trying to Solve?

### "I need my CI/CD pipeline to access Vault"
→ Use **AppRole** with response wrapping for secure bootstrap. [Jump to AppRole](#approle-recommended-for-automation)

### "I need my Kubernetes pods to get secrets"
→ Use **Kubernetes auth** bound to service accounts. [Jump to Kubernetes](#kubernetes)

### "I need human users to login via SSO"
→ Use **OIDC** with your identity provider (Okta, Azure AD). [Jump to OIDC](#oidc-human-users)

### "I have an AWS workload that needs secrets"
→ Use **AWS IAM auth** for EC2/Lambda/ECS. [Jump to AWS](#aws-iam)

### "I'm not sure which auth method to use"
→ See the [selection guide](#auth-method-selection) below.

---

## How Vault Authentication Works

1. **Authenticate** → Client presents credentials (role_id/secret_id, JWT, IAM signature)
2. **Validate** → Vault verifies with identity provider or trusted source
3. **Authorize** → Vault issues token with attached policies
4. **Access** → Client uses token for subsequent API calls (all operations audited)

---

## Auth Method Selection

| Your Workload | Recommended Auth | Why |
|---------------|------------------|-----|
| CI/CD (GitHub Actions, GitLab, Jenkins) | AppRole or JWT | Machine identity, short-lived |
| Kubernetes pods | Kubernetes | Native service account binding |
| Human users (Okta, Azure AD) | OIDC | SSO integration |
| AWS EC2/Lambda/ECS | AWS IAM | Cloud-native identity |
| Azure VMs/Functions | Azure | Managed identity |
| GCP GCE/Functions | GCP | Service account identity |
| Legacy LDAP directory | LDAP | Enterprise directory |

---

## Reference

- [Vault Auth Methods Documentation](https://developer.hashicorp.com/vault/docs/auth)
- [Detailed Auth Methods Reference](references/auth-methods.md)

---

## Quick Reference

### AppRole (Recommended for Automation)

```bash
# Enable AppRole
vault auth enable approle

# Create role
vault write auth/approle/role/my-app \
    token_policies="app-policy" \
    token_ttl=1h \
    secret_id_ttl=10m

# Get credentials
vault read auth/approle/role/my-app/role-id
vault write -f auth/approle/role/my-app/secret-id

# Login
vault write auth/approle/login \
    role_id="<role-id>" \
    secret_id="<secret-id>"
```

### Kubernetes

```bash
# Enable Kubernetes auth
vault auth enable kubernetes

# Configure with cluster info
vault write auth/kubernetes/config \
    kubernetes_host="https://kubernetes.default.svc:443"

# Create role bound to service account
vault write auth/kubernetes/role/my-app \
    bound_service_account_names=my-app-sa \
    bound_service_account_namespaces=default \
    policies=app-policy \
    ttl=1h
```

### OIDC (Human Users)

```bash
# Enable OIDC
vault auth enable oidc

# Configure provider (e.g., Okta)
vault write auth/oidc/config \
    oidc_discovery_url="https://your-org.okta.com" \
    oidc_client_id="vault-client-id" \
    oidc_client_secret="client-secret" \
    default_role="default"

# Create role
vault write auth/oidc/role/default \
    bound_audiences="vault-client-id" \
    allowed_redirect_uris="http://localhost:8250/oidc/callback" \
    user_claim="email" \
    policies="user-policy"

# Login
vault login -method=oidc
```

### AWS IAM

```bash
# Enable AWS auth
vault auth enable aws

# Configure
vault write auth/aws/config/client \
    access_key="ACCESS_KEY" \
    secret_key="SECRET_KEY"

# Create IAM role
vault write auth/aws/role/my-role \
    auth_type=iam \
    bound_iam_principal_arn="arn:aws:iam::123456789:role/my-role" \
    policies=aws-policy
```

---

## Common Patterns

### Trusted Broker Pattern

Securely distribute initial credentials using response wrapping:

```bash
# Wrap a secret ID for 60 seconds
vault write -wrap-ttl=60s -f auth/approle/role/my-app/secret-id

# Unwrap on the target machine (single use)
vault unwrap <wrapping-token>
```

### Multi-Method Authentication

```bash
# Enable multiple methods with mount paths
vault auth enable -path=okta oidc
vault auth enable -path=github-actions jwt

# Users can authenticate via either
vault login -method=oidc -path=okta
```

---

## Best Practices

- **Use AppRole** for machine-to-machine with short-lived secret IDs
- **Use Kubernetes auth** for K8s workloads (avoid mounting service account tokens)
- **Use OIDC** for human users (integrates with existing SSO)
- **Bind to specific identities** - never use wildcards in IAM principal ARNs
- **Set short TTLs** - 1h or less for tokens

---

For detailed configurations including Azure, GCP, LDAP, GitHub, and advanced patterns, see [references/auth-methods.md](references/auth-methods.md).
