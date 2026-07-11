---
name: vault-auth-methods
description: Detailed configuration for Vault authentication methods including AppRole, Kubernetes, OIDC, AWS, Azure, GCP, and LDAP
---

# Vault Authentication Methods

This reference provides detailed configuration for Vault's authentication methods.

---

## Overview

Authentication methods verify user or machine identity before granting access. After successful authentication, Vault issues a **token** tied to policies that define permissions.

### Authentication Flow

1. Client presents credentials to an auth method endpoint
2. Vault validates credentials with the identity provider
3. Vault issues a token with attached policies
4. Client uses token for subsequent API calls

---

## AppRole (Recommended for Applications)

AppRole is designed for machine-to-machine authentication with two-factor security (RoleID + SecretID).

### Enable and Configure AppRole

```bash
# Enable AppRole auth
vault auth enable approle

# Create a role with policies and TTL
vault write auth/approle/role/my-app \
    token_policies="app-policy" \
    token_ttl=1h \
    token_max_ttl=4h \
    secret_id_ttl=10m \
    secret_id_num_uses=1
```

### Get Credentials

```bash
# Get RoleID (can be embedded in configuration)
vault read auth/approle/role/my-app/role-id

# Generate SecretID (deliver securely, often via response wrapping)
vault write -f auth/approle/role/my-app/secret-id

# Response wrapping for secure SecretID delivery
vault write -wrap-ttl=60s -f auth/approle/role/my-app/secret-id
```

### AppRole Application Login

```bash
# CLI login
vault write auth/approle/login \
    role_id="<role-id>" \
    secret_id="<secret-id>"

# API login
curl --request POST \
    --data '{"role_id": "<role-id>", "secret_id": "<secret-id>"}' \
    $VAULT_ADDR/v1/auth/approle/login
```

### Best Practices

- Use `secret_id_num_uses=1` for single-use SecretIDs
- Deliver SecretID via response wrapping
- Use short TTLs and implement token renewal
- Separate RoleID (less sensitive) from SecretID (highly sensitive)

---

## AppRole Trusted Broker Pattern (CI/CD)

> **Core Principle**: RoleID and SecretID should ONLY ever be together on the end-user system that consumes the secret.

### Architecture

```text
┌─────────┐                    ┌─────────┐                    ┌─────────┐
│   CI    │ 1.Auth ──────────► │  Vault  │ ◄──── 8.Auth ─────│  Runner │
│ Worker  │ ◄──── 2.Token ──── │         │ ──── 9.Token ───► │Container│
│(Broker) │ 3.Wrapped SecretID │         │ ◄── 10.Get Secret │         │
│         │ ◄──── 4.Return ─── │         │ ──── 11.Secret ──►│         │
│         │ 5.Spawn+Pass ─────────────────────────────────────►         │
└─────────┘                    └─────────┘     6.Unwrap       └─────────┘
                                               7.SecretID
```

### Workflow Steps

1. CI Worker authenticates to Vault (using its own identity)
2. Vault returns token with limited policy
3. Worker requests **wrapped** SecretID for the runner role
4. Vault returns wrapped SecretID (single-use wrapping token)
5. Worker spawns runner container, passes wrapped SecretID as env var
6. Runner unwraps the SecretID
7. Runner uses RoleID + SecretID to authenticate
8. Vault returns token with runner-specific policies
9. Runner retrieves secrets

### Worker Policy (Trusted Broker)

```hcl
# Worker can only create wrapped SecretIDs, not access secrets directly
path "auth/approle/role/+/secret*" {
  capabilities = ["create", "read", "update"]
  min_wrapping_ttl = "100s"
  max_wrapping_ttl = "300s"
}
```

### Runner Policy (Scoped to Specific Secrets)

```hcl
path "secret/data/{{identity.entity.metadata.app}}/*" {
  capabilities = ["read"]
}
```

### Jenkins Pipeline Example

```groovy
pipeline {
  environment {
    WRAPPED_SID = sh(
      returnStdout: true,
      script: '''
        curl --silent \
          --header "X-Vault-Token: ${VAULT_TOKEN}" \
          --header "X-Vault-Wrap-TTL: 300s" \
          --request POST \
          ${VAULT_ADDR}/v1/auth/approle/role/${JOB_NAME}/secret-id \
          | jq -r '.wrap_info.token'
      '''
    ).trim()
  }
  stages {
    stage('Run') {
      steps {
        // Pass wrapped SecretID to container
        sh 'docker run -e WRAPPED_SID=${WRAPPED_SID} myapp:latest'
      }
    }
  }
}
```

### Security Configurations

| Setting | Recommended Value | Purpose |
| --------- | ------------------- | --------- |
| `secret_id_num_uses` | 1 | Single-use SecretIDs |
| `secret_id_ttl` | 120s | Short-lived SecretIDs |
| `secret_id_bound_cidrs` | Network range | Restrict login location |
| `wrap_ttl` | 100-300s | Response wrapping for delivery |

### Anti-Patterns to Avoid

| Anti-Pattern | Risk | Correct Approach |
| -------------- | ------ | ------------------ |
| CI Worker retrieves secrets directly | Worker has access to many secrets | Use trusted broker pattern |
| Passing RoleID AND SecretID together | Full auth credentials exposed | Separate delivery mechanisms |
| Passing Vault tokens to runners | Token can access all permitted secrets | Use AppRole per-runner |
| Storing SecretID in CI/CD config | Credential exposure | Generate per-run with wrapping |

### Security Monitoring

Alert on these conditions in audit logs:

- Wrapped SecretID requested when no job is running
- Unwrap attempt fails (token already used = potential compromise)
- SecretID generated without corresponding job execution

---

## Kubernetes Authentication

Authenticates Kubernetes pods using their ServiceAccount tokens.

### Enable and Configure Kubernetes Auth

```bash
# Enable Kubernetes auth
vault auth enable kubernetes

# Configure Vault to communicate with Kubernetes API
vault write auth/kubernetes/config \
    kubernetes_host="https://kubernetes.default.svc:443" \
    kubernetes_ca_cert=@/var/run/secrets/kubernetes.io/serviceaccount/ca.crt

# For external Vault accessing K8s cluster
vault write auth/kubernetes/config \
    kubernetes_host="https://cluster-api.example.com:6443" \
    kubernetes_ca_cert=@ca.crt \
    token_reviewer_jwt=@reviewer-jwt.txt
```

### Handling Kubernetes 1.21+ Short-Lived Tokens

Kubernetes 1.21+ uses short-lived bound service account tokens. Configure one of these options:

```bash
# Option 1: Use local token reviewer JWT (recommended when Vault runs in K8s)
vault write auth/kubernetes/config \
    kubernetes_host="https://kubernetes.default.svc:443" \
    kubernetes_ca_cert=@/var/run/secrets/kubernetes.io/serviceaccount/ca.crt

# Option 2: Disable issuer validation (for cross-cluster auth)
vault write auth/kubernetes/config \
    kubernetes_host="https://kubernetes.example.com:6443" \
    kubernetes_ca_cert=@ca.crt \
    disable_iss_validation=true

# Option 3: Use explicit issuer (for specific OIDC issuers)
vault write auth/kubernetes/config \
    kubernetes_host="https://kubernetes.example.com:6443" \
    issuer="https://kubernetes.default.svc.cluster.local"
```

### Use Annotations as Alias Metadata

Enable templated policies using ServiceAccount metadata:

```bash
vault write auth/kubernetes/config \
    kubernetes_host="https://kubernetes.default.svc:443" \
    use_annotations_as_alias_metadata=true
```

This allows policies like:

```hcl
path "secret/data/{{identity.entity.aliases.auth_kubernetes.metadata.service_account_namespace}}/*" {
  capabilities = ["read"]
}
```

### Create Roles

```bash
# Bind role to specific ServiceAccount and namespace
vault write auth/kubernetes/role/my-app \
    bound_service_account_names=my-app-sa \
    bound_service_account_namespaces=default,staging \
    policies=app-policy \
    ttl=1h \
    audience=vault

# Wildcard bindings
vault write auth/kubernetes/role/any-app \
    bound_service_account_names="*" \
    bound_service_account_namespaces=apps \
    policies=read-only
```

### Pod Authentication

Pods authenticate using their mounted ServiceAccount token:

```bash
# From within pod
JWT=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)
curl --request POST \
    --data "{\"jwt\": \"$JWT\", \"role\": \"my-app\"}" \
    $VAULT_ADDR/v1/auth/kubernetes/login
```

### Kubernetes RBAC Requirements

```yaml
# ClusterRoleBinding for token review
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: vault-tokenreview
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: system:auth-delegator
subjects:
- kind: ServiceAccount
  name: vault
  namespace: vault
```

---

## JWT/OIDC Authentication

Authenticate using JSON Web Tokens from OIDC providers (Okta, Auth0, Azure AD, Google).

### OIDC Configuration (Interactive)

```bash
# Enable OIDC
vault auth enable oidc

# Configure with OIDC provider
vault write auth/oidc/config \
    oidc_discovery_url="https://accounts.google.com" \
    oidc_client_id="<client-id>" \
    oidc_client_secret="<client-secret>" \
    default_role="default"

# Create role with claims mapping
vault write auth/oidc/role/default \
    allowed_redirect_uris="http://localhost:8250/oidc/callback" \
    allowed_redirect_uris="https://vault.example.com:8200/ui/vault/auth/oidc/oidc/callback" \
    user_claim="email" \
    policies="default" \
    oidc_scopes="openid,email,profile" \
    bound_claims='{"groups": ["engineering"]}'
```

### JWT Configuration (Non-Interactive)

```bash
# For JWT tokens (CI/CD, service accounts)
vault auth enable jwt

vault write auth/jwt/config \
    oidc_discovery_url="https://token.actions.githubusercontent.com" \
    bound_issuer="https://token.actions.githubusercontent.com"

# GitHub Actions role
vault write auth/jwt/role/github-actions \
    role_type="jwt" \
    user_claim="actor" \
    bound_claims_type="glob" \
    bound_claims='{"repository": "myorg/*"}' \
    policies="ci-policy" \
    ttl=15m
```

### OIDC Login

```bash
# Interactive browser login
vault login -method=oidc

# With specific role
vault login -method=oidc role=admin
```

---

## AWS IAM Authentication

Authenticate EC2 instances or IAM principals using AWS credentials.

### Enable and Configure AWS Auth

```bash
vault auth enable aws

# Configure AWS credentials for Vault
vault write auth/aws/config/client \
    access_key=<access-key> \
    secret_key=<secret-key> \
    region=us-east-1

# For STS with assumed role
vault write auth/aws/config/sts/account-id \
    sts_role=arn:aws:iam::ACCOUNT:role/VaultVerifyRole
```

### IAM Role (Recommended)

```bash
# Create IAM auth role
vault write auth/aws/role/web-app \
    auth_type=iam \
    bound_iam_principal_arn="arn:aws:iam::ACCOUNT:role/WebAppRole" \
    policies=app-policy \
    ttl=1h
```

### EC2 Role

```bash
vault write auth/aws/role/ec2-app \
    auth_type=ec2 \
    bound_ami_id="ami-12345678" \
    bound_vpc_id="vpc-abcdef12" \
    policies=app-policy
```

### AWS Application Login

```bash
# IAM auth from AWS environment
vault login -method=aws role=web-app

# Using explicit credentials
vault write auth/aws/login \
    role=web-app \
    iam_http_request_method=POST \
    iam_request_url=<base64-encoded-url> \
    iam_request_body=<base64-encoded-body> \
    iam_request_headers=<base64-encoded-headers>
```

---

## Azure Authentication

Authenticate Azure VMs and managed identities.

### Enable and Configure Azure Auth

```bash
vault auth enable azure

vault write auth/azure/config \
    tenant_id="<tenant-id>" \
    resource="https://management.azure.com/" \
    client_id="<client-id>" \
    client_secret="<client-secret>"
```

### Create Role

```bash
vault write auth/azure/role/web-app \
    policies="app-policy" \
    bound_subscription_ids="<subscription-id>" \
    bound_resource_groups="my-rg" \
    bound_service_principal_ids="<sp-id>"
```

---

## GCP Authentication

Authenticate GCP service accounts and compute instances.

### Enable and Configure GCP Auth

```bash
vault auth enable gcp

vault write auth/gcp/config \
    credentials=@gcp-credentials.json
```

### IAM Role

```bash
vault write auth/gcp/role/web-app \
    type="iam" \
    policies="app-policy" \
    bound_service_accounts="sa@project.iam.gserviceaccount.com"
```

### GCE Role

```bash
vault write auth/gcp/role/gce-app \
    type="gce" \
    policies="app-policy" \
    bound_projects="my-project" \
    bound_zones="us-central1-a" \
    bound_labels="env:prod"
```

---

## LDAP Authentication

Authenticate against LDAP/Active Directory.

### Enable and Configure LDAP Auth

```bash
vault auth enable ldap

vault write auth/ldap/config \
    url="ldaps://ldap.example.com:636" \
    binddn="cn=vault,ou=services,dc=example,dc=com" \
    bindpass="<password>" \
    userdn="ou=users,dc=example,dc=com" \
    userattr="sAMAccountName" \
    groupdn="ou=groups,dc=example,dc=com" \
    groupattr="cn" \
    insecure_tls=false \
    starttls=false
```

### Map Groups to Policies

```bash
# Map LDAP group to Vault policies
vault write auth/ldap/groups/engineering \
    policies="engineering-policy,read-only"

vault write auth/ldap/groups/admins \
    policies="admin-policy"
```

### Login

```bash
vault login -method=ldap username=jdoe
# Prompts for password
```

---

## Token Authentication

Direct token authentication (often used after other methods issue tokens).

### Create Tokens

```bash
# Create token with policies
vault token create -policy=app-policy -ttl=1h

# Create orphan token (no parent)
vault token create -orphan -policy=app-policy

# Create periodic token (renewable indefinitely)
vault token create -policy=app-policy -period=24h

# Create batch token (lightweight, no storage)
vault token create -type=batch -policy=app-policy
```

### Token Types

| Type | Storage | Renewal | Use Case |
| ------ | --------- | --------- | ---------- |
| **Service** | Yes | Yes | Long-running apps |
| **Batch** | No | No | Short-lived, high-volume |
| **Periodic** | Yes | Indefinite | Services needing long uptime |

---

## Comparison Table

| Method | Use Case | Security Level | Complexity |
| -------- | ---------- | ---------------- | ------------ |
| **AppRole** | Applications, CI/CD | High | Medium |
| **Kubernetes** | K8s pods | High | Medium |
| **JWT/OIDC** | SSO, CI/CD tokens | High | Medium |
| **AWS** | AWS workloads | High | Low |
| **Azure** | Azure workloads | High | Low |
| **GCP** | GCP workloads | High | Low |
| **LDAP** | Enterprise users | Medium | Medium |
| **Token** | Direct auth | Varies | Low |

---

## Additional Resources

- [Auth Methods Documentation](https://developer.hashicorp.com/vault/docs/auth)
- [AppRole Tutorial](https://developer.hashicorp.com/vault/tutorials/auth-methods/approle)
- [Kubernetes Auth Tutorial](https://developer.hashicorp.com/vault/tutorials/kubernetes/kubernetes-sidecar)

---

## Related

- [Policies](policies.md) - Define permissions for authenticated identities
- [Kubernetes Integration](kubernetes.md) - K8s-specific auth and secret delivery
- [Vault Agent](vault-agent.md) - Auto-auth configuration for applications
