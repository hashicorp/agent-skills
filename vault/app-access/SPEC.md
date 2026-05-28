# Specification: vault-app-access

**Status**: Published  
**Version**: 0.3.0

---

## Overview

This plugin helps you **give applications secure access to Vault**. Covers authentication methods (AppRole, Kubernetes, OIDC, AWS, Azure, GCP, LDAP), access control policies, token lifecycle management, unified identity, and secure secret distribution via response wrapping.

---

## User Stories

### US-1: Platform Engineer Configuring Kubernetes Authentication (P1)

A platform engineer needs to configure Kubernetes workloads to authenticate with Vault and retrieve secrets without manual token management.

**Why this priority**: Kubernetes is the dominant container orchestration platform. K8s-native auth is essential for cloud-native deployments.

**Acceptance Criteria**:
1. Given a user asks about Kubernetes auth, when the skill is invoked, then it provides Kubernetes auth method configuration including role binding and ClusterRoleBinding setup.
2. Given a user mentions service accounts, when queried, then the skill explains service account binding patterns and annotations_as_alias_metadata.
3. Given a Kubernetes 1.21+ question, when asked about token handling, then the skill explains short-lived bound service account token options.

### US-2: DevOps Engineer Setting Up CI/CD Authentication (P1)

A DevOps engineer needs to configure GitHub Actions/GitLab CI to authenticate with Vault for deployment secrets.

**Why this priority**: Secure CI/CD integration is critical for DevOps pipelines.

**Acceptance Criteria**:
1. Given a CI/CD authentication question, when the skill is invoked, then it provides AppRole or JWT auth configuration.
2. Given a trusted broker pattern question, when queried, then the skill explains response wrapping and secure credential distribution.
3. Given a response wrapping question, when asked about SecretID, then the skill explains wrapped SecretID workflow with TTL enforcement.

### US-3: Security Engineer Writing Access Policies (P1)

A security engineer needs to create fine-grained access control policies for multiple teams accessing different secrets paths.

**Why this priority**: Policies are the foundation of Vault's security model. Incorrect policies create security risks.

**Acceptance Criteria**:
1. Given a user requests policy creation, when the skill is invoked, then it generates valid HCL policy syntax with proper path patterns.
2. Given a user asks about templated policies, when queried, then the skill explains identity templating with {{identity.entity}} patterns.
3. Given a KV v2 question, when asked about paths, then the skill emphasizes /data/ path segment requirement.
4. Given a response wrapping policy question, when asked, then the skill shows min/max_wrapping_ttl enforcement.

### US-4: Identity Admin Configuring SSO (P2)

An identity administrator needs to configure OIDC authentication for human users via Okta/Azure AD.

**Acceptance Criteria**:
1. Given an OIDC configuration request, when the skill is invoked, then it provides complete OIDC auth setup including claims mapping.
2. Given a group-based access question, when queried, then the skill explains external groups and policy assignment.
3. Given an OIDC group mapping question, when asked about workflow, then the skill explains the full OIDC group mapping workflow.

### US-5: Security Engineer Implementing Trusted Broker (P2)

A security engineer needs to implement the AppRole trusted broker pattern for secure CI/CD secret distribution.

**Acceptance Criteria**:
1. Given a trusted broker question, when the skill is invoked, then it provides complete trusted broker architecture with workflow diagram.
2. Given a policy question, when asked about broker permissions, then the skill shows broker policy with wrapping TTL constraints.
3. Given a security configuration question, when asked, then the skill explains secret_id_num_uses, secret_id_ttl, and CIDR binding.

### US-6: Platform Engineer Managing Token Lifecycle (P1)

A platform engineer needs to understand and manage different token types for various workload patterns.

**Why this priority**: Token management is fundamental to Vault operations. Incorrect token usage causes outages.

**Acceptance Criteria**:
1. Given a token type question, when the skill is invoked, then it explains service vs batch tokens and when to use each.
2. Given a long-running service question, when queried, then the skill provides periodic token configuration.
3. Given a token renewal question, when asked, then the skill explains TTL, max TTL, and renewal strategies.

### US-7: Administrator Configuring Unified Identity (P2)

An administrator needs to map users from multiple auth methods to a single identity for consistent policy application.

**Acceptance Criteria**:
1. Given an identity configuration question, when the skill is invoked, then it explains entities, aliases, and group membership.
2. Given an OIDC provider question, when queried, then the skill provides Vault-as-OIDC-provider configuration.
3. Given a policy inheritance question, when asked, then the skill explains entity and group policy assignment.

### US-8: Developer Implementing Secure Secret Handoff (P2)

A developer needs to securely pass secrets to another service using response wrapping.

**Acceptance Criteria**:
1. Given a response wrapping question, when the skill is invoked, then it explains cubbyhole and wrapped token patterns.
2. Given a malfeasance detection question, when queried, then the skill explains single-use tokens and detection.
3. Given a bootstrap question, when asked, then the skill provides wrapped token bootstrap workflow.

---

## Functional Requirements

| ID | Requirement |
|----|-------------|
| FR-001 | Skill MUST cover AppRole authentication with trusted broker pattern |
| FR-002 | Skill MUST cover Kubernetes auth with 1.21+ token handling |
| FR-003 | Skill MUST cover OIDC auth with group mapping workflow |
| FR-004 | Skill MUST cover AWS IAM auth with server ID header |
| FR-005 | Skill MUST cover Azure AD, GCP IAM, LDAP auth methods |
| FR-006 | Skill MUST explain Identity system and entities |
| FR-007 | Skill MUST cover HCL policy syntax with all capabilities |
| FR-008 | Skill MUST explain KV v2 /data/ path requirement |
| FR-009 | Skill MUST cover templated policies with identity tokens |
| FR-010 | Skill MUST cover response wrapping TTL enforcement |
| FR-011 | Skill MUST explain CI/CD pipeline policy patterns |
| FR-012 | Skill MUST cover Sentinel policies (Enterprise) |
| FR-013 | Skill MUST explain service vs batch token differences |
| FR-014 | Skill MUST cover periodic token configuration |
| FR-015 | Skill MUST explain token accessor usage patterns |
| FR-016 | Skill MUST cover orphan token creation and implications |
| FR-017 | Skill MUST explain entity and alias creation |
| FR-018 | Skill MUST cover internal and external group types |
| FR-019 | Skill MUST explain identity token (OIDC) generation |
| FR-020 | Skill MUST cover cubbyhole secrets engine |
| FR-021 | Skill MUST explain wrap/unwrap operations |
| FR-022 | Skill MUST cover wrapped token bootstrap patterns |

---

## Skills Included

| Skill | Description |
|-------|-------------|
| `auth-methods` | Configure AppRole, Kubernetes, OIDC, AWS, Azure, GCP, LDAP auth |
| `policies` | Write HCL policies, templated policies, and debug permissions |
| `token-management` | Manage service, batch, periodic, orphan tokens and accessors |
| `identity-system` | Configure entities, aliases, groups, and OIDC provider |
| `response-wrapping` | Implement cubbyhole wrapping and secure secret distribution |

---

## Content Sources

- HashiCorp Vault Documentation
- Vault Tutorials
- CSA Enterprise Patterns (genericized)

---

## References

- [Vault Auth Methods](https://developer.hashicorp.com/vault/docs/auth)
- [AppRole Auth](https://developer.hashicorp.com/vault/docs/auth/approle)
- [Kubernetes Auth](https://developer.hashicorp.com/vault/docs/auth/kubernetes)
- [Vault Policies](https://developer.hashicorp.com/vault/docs/concepts/policies)
- [Token Concepts](https://developer.hashicorp.com/vault/docs/concepts/tokens)
- [Identity Secrets Engine](https://developer.hashicorp.com/vault/docs/secrets/identity)
- [Response Wrapping](https://developer.hashicorp.com/vault/docs/concepts/response-wrapping)
