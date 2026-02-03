# HashiCorp Vault Agent Skills

Agent skills for HashiCorp Vault identity-based secrets and encryption management.

## Overview

Vault secures, stores, and tightly controls access to tokens, passwords, certificates, encryption keys, and other sensitive data. These skills provide AI-assisted guidance for secrets management, authentication, operational tasks, enterprise features, and HashiCorp product integrations.

## Available Plugins

| Plugin | Description | Skills |
|--------|-------------|--------|
| [vault-secrets-management](secrets-management/) | Generate and manage static and dynamic secrets | `secrets-engines`, `vault-agent` |
| [vault-authentication](authentication/) | Configure auth methods, policies, tokens, and identity | `auth-methods`, `policies`, `token-management`, `identity-system`, `response-wrapping` |
| [vault-operations](operations/) | Deploy, monitor, and troubleshoot Vault | `kubernetes-integration`, `production-operations`, `troubleshooting` |
| [vault-enterprise](enterprise/) | Vault Enterprise features | `enterprise-features` |
| [vault-mcp-integration](mcp-integration/) | Use Vault with MCP-enabled AI assistants | `vault-mcp-server`, `mcp-secrets-workflows` |
| [vault-hashicorp-integrations](hashicorp-integrations/) | Dynamic credentials for HashiCorp products | `consul-secrets`, `nomad-secrets`, `terraform-cloud-secrets` |

## Installation

### Install All Vault Plugins

```bash
claude plugin install vault-secrets-management@hashicorp
claude plugin install vault-authentication@hashicorp
claude plugin install vault-operations@hashicorp
claude plugin install vault-enterprise@hashicorp
claude plugin install vault-mcp-integration@hashicorp
claude plugin install vault-hashicorp-integrations@hashicorp
```

### Install Individual Skills

```bash
# Secrets management
npx skills add hashicorp/agent-skills/vault/secrets-management/skills/secrets-engines
npx skills add hashicorp/agent-skills/vault/secrets-management/skills/vault-agent

# Authentication, identity, and tokens
npx skills add hashicorp/agent-skills/vault/authentication/skills/auth-methods
npx skills add hashicorp/agent-skills/vault/authentication/skills/policies
npx skills add hashicorp/agent-skills/vault/authentication/skills/token-management
npx skills add hashicorp/agent-skills/vault/authentication/skills/identity-system
npx skills add hashicorp/agent-skills/vault/authentication/skills/response-wrapping

# Operations
npx skills add hashicorp/agent-skills/vault/operations/skills/kubernetes-integration
npx skills add hashicorp/agent-skills/vault/operations/skills/production-operations
npx skills add hashicorp/agent-skills/vault/operations/skills/troubleshooting

# Enterprise
npx skills add hashicorp/agent-skills/vault/enterprise/skills/enterprise-features

# MCP Integration
npx skills add hashicorp/agent-skills/vault/mcp-integration/skills/vault-mcp-server
npx skills add hashicorp/agent-skills/vault/mcp-integration/skills/mcp-secrets-workflows

# HashiCorp Integrations
npx skills add hashicorp/agent-skills/vault/hashicorp-integrations/skills/consul-secrets
npx skills add hashicorp/agent-skills/vault/hashicorp-integrations/skills/nomad-secrets
npx skills add hashicorp/agent-skills/vault/hashicorp-integrations/skills/terraform-cloud-secrets
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

See [vault-mcp-integration](mcp-integration/) for setup and usage patterns.

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
