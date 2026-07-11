# Specification: vault-hashicorp-secrets-engines

**Status**: Published  
**Version**: 0.2.0

---

## Overview

This plugin provides Vault secrets engines for **generating dynamic tokens for HashiCorp products**. Covers Consul ACL tokens, Nomad ACL tokens, and Terraform Cloud/Enterprise API tokens with automatic lease management and revocation.

## User Stories

### Consul Secrets Engine

**US-1**: As a platform engineer, I want Vault to generate dynamic Consul ACL tokens, so that my services have just-in-time access to Consul without long-lived credentials.

**US-2**: As a security engineer, I want Consul tokens to be automatically revoked when leases expire, so that credential sprawl is eliminated.

**US-3**: As a developer, I want to request Consul tokens scoped to specific services and nodes, so that my application has least-privilege access.

### Nomad Secrets Engine

**US-4**: As a platform engineer, I want Vault to generate dynamic Nomad ACL tokens, so that job submissions use ephemeral credentials.

**US-5**: As an SRE, I want to map Vault roles to Nomad ACL policies, so that token permissions are consistently defined.

**US-6**: As a developer, I want to request Nomad tokens for specific environments, so that I can deploy to staging without production access.

### Terraform Cloud Secrets Engine

**US-7**: As a DevOps engineer, I want Vault to generate dynamic Terraform Cloud API tokens, so that CI/CD pipelines don't need long-lived tokens.

**US-8**: As a platform engineer, I want to generate team-scoped TFC tokens, so that automation can manage specific workspaces.

**US-9**: As an administrator, I want to rotate organization tokens through Vault, so that compromise recovery is automated.

## Functional Requirements

### Consul Secrets Engine (FR-1 through FR-6)

| ID | Requirement |
|----|-------------|
| FR-1 | Document Consul secrets engine setup and configuration |
| FR-2 | Provide role definitions for policies, node identities, and service identities |
| FR-3 | Include dynamic token generation and lease management |
| FR-4 | Document Consul Enterprise namespace and partition support |
| FR-5 | Provide ACL bootstrap integration with Vault |
| FR-6 | Include token TTL and automatic rotation patterns |

### Nomad Secrets Engine (FR-7 through FR-11)

| ID | Requirement |
|----|-------------|
| FR-7 | Document Nomad secrets engine setup and configuration |
| FR-8 | Provide role mapping to Nomad ACL policies |
| FR-9 | Include dynamic token generation workflows |
| FR-10 | Document management token requirements |
| FR-11 | Provide lease configuration and renewal patterns |

### Terraform Cloud Secrets Engine (FR-12 through FR-18)

| ID | Requirement |
|----|-------------|
| FR-12 | Document Terraform Cloud secrets engine setup |
| FR-13 | Provide organization, team, and user role types |
| FR-14 | Include dynamic team token generation |
| FR-15 | Document user token management |
| FR-16 | Provide organization token rotation workflows |
| FR-17 | Include Terraform Enterprise on-prem configuration |
| FR-18 | Document token expiration and max_ttl behavior |

## Skills Matrix

| Skill | Product | Credential Types |
|-------|---------|------------------|
| consul-secrets | HashiCorp Consul | ACL tokens (policies, service identities, node identities) |
| nomad-secrets | HashiCorp Nomad | ACL tokens (client tokens mapped to policies) |
| terraform-cloud-secrets | Terraform Cloud/Enterprise | API tokens (organization, team, user) |

## Integration Architecture

```
┌─────────────────────────────────────────────────────────┐
│                     HashiCorp Vault                      │
├─────────────────┬─────────────────┬─────────────────────┤
│ consul/         │ nomad/          │ terraform/          │
│ secrets engine  │ secrets engine  │ secrets engine      │
└────────┬────────┴────────┬────────┴──────────┬──────────┘
         │                 │                   │
         ▼                 ▼                   ▼
   ┌───────────┐    ┌───────────┐    ┌─────────────────┐
   │  Consul   │    │   Nomad   │    │ Terraform Cloud │
   │  Cluster  │    │  Cluster  │    │   / Enterprise  │
   └───────────┘    └───────────┘    └─────────────────┘
```

## References

- [Consul Secrets Engine](https://developer.hashicorp.com/vault/docs/secrets/consul)
- [Nomad Secrets Engine](https://developer.hashicorp.com/vault/docs/secrets/nomad)
- [Terraform Cloud Secrets Engine](https://developer.hashicorp.com/vault/docs/secrets/terraform)
- [Administer Consul ACL Tokens with Vault](https://developer.hashicorp.com/consul/tutorials/vault-secure/vault-consul-secrets)
- [Generate Nomad Tokens with Vault](https://developer.hashicorp.com/nomad/tutorials/integrate-vault/vault-nomad-secrets)
