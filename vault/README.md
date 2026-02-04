# HashiCorp Vault Agent Skills

Agent skills for HashiCorp Vault identity-based secrets and encryption management.

## Overview

Vault secures, stores, and tightly controls access to tokens, passwords, certificates, encryption keys, and other sensitive data. These skills provide AI-assisted guidance organized around **jobs to be done**—the problems you're actually trying to solve.

## Available Plugins

| Plugin | Job to Be Done | Skills |
|--------|----------------|--------|
| [vault-credential-generation](credential-generation/) | Generate dynamic credentials for my app | `secrets-engines`, `vault-agent` |
| [vault-app-access](app-access/) | Give my app secure access to Vault | `auth-methods`, `policies`, `token-management`, `identity-system`, `response-wrapping` |
| [vault-deployment](deployment/) | Deploy and operate Vault | `kubernetes-integration`, `production-operations`, `troubleshooting` |
| [vault-multi-tenancy](multi-tenancy/) | Set up multi-tenant Vault | `enterprise-features` |
| [vault-ai-workflows](ai-workflows/) | Use AI to manage secrets | `vault-mcp-server`, `mcp-secrets-workflows` |
| [vault-hashicorp-secrets-engines](hashicorp-secrets-engines/) | Secrets engines for Consul, Nomad, TFC | `consul-secrets`, `nomad-secrets`, `terraform-cloud-secrets` |

## Installation

### Install All Vault Plugins

```bash
claude plugin install vault-credential-generation@hashicorp
claude plugin install vault-app-access@hashicorp
claude plugin install vault-deployment@hashicorp
claude plugin install vault-multi-tenancy@hashicorp
claude plugin install vault-ai-workflows@hashicorp
claude plugin install vault-hashicorp-secrets-engines@hashicorp
```

### Install Individual Skills

```bash
# Credential generation
npx skills add hashicorp/agent-skills/vault/credential-generation/skills/secrets-engines
npx skills add hashicorp/agent-skills/vault/credential-generation/skills/vault-agent

# App access (authentication, identity, and tokens)
npx skills add hashicorp/agent-skills/vault/app-access/skills/auth-methods
npx skills add hashicorp/agent-skills/vault/app-access/skills/policies
npx skills add hashicorp/agent-skills/vault/app-access/skills/token-management
npx skills add hashicorp/agent-skills/vault/app-access/skills/identity-system
npx skills add hashicorp/agent-skills/vault/app-access/skills/response-wrapping

# Deployment (operations)
npx skills add hashicorp/agent-skills/vault/deployment/skills/kubernetes-integration
npx skills add hashicorp/agent-skills/vault/deployment/skills/production-operations
npx skills add hashicorp/agent-skills/vault/deployment/skills/troubleshooting

# Multi-tenancy (enterprise)
npx skills add hashicorp/agent-skills/vault/multi-tenancy/skills/enterprise-features

# AI workflows (MCP integration)
npx skills add hashicorp/agent-skills/vault/ai-workflows/skills/vault-mcp-server
npx skills add hashicorp/agent-skills/vault/ai-workflows/skills/mcp-secrets-workflows

# HashiCorp secrets engines
npx skills add hashicorp/agent-skills/vault/hashicorp-secrets-engines/skills/consul-secrets
npx skills add hashicorp/agent-skills/vault/hashicorp-secrets-engines/skills/nomad-secrets
npx skills add hashicorp/agent-skills/vault/hashicorp-secrets-engines/skills/terraform-cloud-secrets
```

## MCP Server Integration

All Vault plugins include configuration for the [Vault MCP Server](https://github.com/hashicorp/vault-mcp-server):

```bash
export VAULT_ADDR="https://vault.example.com:8200"
export VAULT_TOKEN="hvs.xxxxx"
export VAULT_NAMESPACE="admin"  # Optional, for Enterprise
```

The MCP server enables Claude and other AI assistants to interact directly with Vault:
- Create and manage secrets engine mounts
- Read, write, and list secrets
- Manage KV v1 and v2 secrets

See [vault-ai-workflows](ai-workflows/) for setup and usage patterns.

## Plugin Overview

### Core Vault Skills

- **secrets-engines**: KV, Database, AWS, Transit, PKI, SSH engines
- **vault-agent**: Auto-auth, caching, templating, sidecar patterns

### Authentication and Identity Skills

- **auth-methods**: AppRole, Kubernetes, OIDC, AWS, Azure, GCP, LDAP
- **policies**: HCL syntax, templated policies, CI/CD patterns
- **token-management**: Service, batch, periodic, orphan tokens, accessors
- **identity-system**: Entities, aliases, groups, OIDC provider
- **response-wrapping**: Cubbyhole, wrapped tokens, secure secret distribution

### Operations Skills

- **kubernetes-integration**: VSO, Agent Injector, CSI Provider
- **production-operations**: HA, DR, monitoring, backup, upgrades
- **troubleshooting**: Diagnostics, debugging, anti-patterns

### Enterprise Skills (requires Vault Enterprise license)

- **enterprise-features**: Namespaces, replication, Sentinel, MFA, HSM

### MCP Integration Skills

- **vault-mcp-server**: Installation, configuration, IDE integration
- **mcp-secrets-workflows**: Tool usage patterns for AI workflows

### HashiCorp Integration Skills

- **consul-secrets**: Dynamic Consul ACL tokens
- **nomad-secrets**: Dynamic Nomad ACL tokens
- **terraform-cloud-secrets**: Dynamic Terraform Cloud/Enterprise API tokens

## Documentation

- [Vault Documentation](https://developer.hashicorp.com/vault)
- [Vault Enterprise](https://developer.hashicorp.com/vault/docs/enterprise)
- [Vault API Reference](https://developer.hashicorp.com/vault/api-docs)
- [Vault Tutorials](https://developer.hashicorp.com/vault/tutorials)
- [Vault MCP Server](https://github.com/hashicorp/vault-mcp-server)
- [HCP Vault](https://developer.hashicorp.com/hcp/docs/vault)
