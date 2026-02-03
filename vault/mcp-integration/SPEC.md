# Specification: vault-mcp-integration

**Status**: Published  
**Version**: 0.1.0

---

## Overview

This plugin provides skills for using the HashiCorp Vault MCP (Model Context Protocol) Server to enable AI assistants like Claude to interact with Vault for secrets management. It covers server setup, configuration, and common workflow patterns using MCP tools.

---

## User Stories

### US-1: Developer Setting Up Vault MCP Server (P1)

A developer wants to configure the Vault MCP Server so Claude or another AI assistant can help manage secrets in their development Vault instance.

**Acceptance Criteria**:
1. Given a setup request, when the skill is invoked, then it provides Docker and from-source installation options.
2. Given a VS Code question, when asked about integration, then the skill provides mcp.json configuration.
3. Given a security question, when asked about production use, then the skill explains security considerations and CORS configuration.

### US-2: Platform Engineer Configuring MCP for Team (P1)

A platform engineer needs to configure the Vault MCP Server for team use with appropriate security controls.

**Acceptance Criteria**:
1. Given a multi-user question, when the skill is invoked, then it explains rate limiting and session management.
2. Given a transport question, when asked about stdio vs HTTP, then the skill provides trade-offs for each mode.
3. Given a TLS question, when asked about secure connections, then the skill provides certificate configuration.

### US-3: Developer Managing Secrets via MCP (P1)

A developer wants to use Claude with the Vault MCP Server to create, read, and manage secrets in a KV secrets engine.

**Acceptance Criteria**:
1. Given a KV management request, when the skill is invoked, then it provides workflow patterns for create_mount, write_secret, read_secret.
2. Given a listing question, when asked how to explore secrets, then the skill shows list_mounts and list_secrets patterns.
3. Given a cleanup question, when asked about deletion, then the skill explains delete_secret and delete_mount usage.

### US-4: DevOps Engineer Automating Mount Management (P2)

A DevOps engineer wants to use AI-assisted workflows to create and configure secrets engine mounts.

**Acceptance Criteria**:
1. Given a mount creation request, when the skill is invoked, then it provides create_mount patterns for KV v1/v2.
2. Given a mount listing question, when asked about discovery, then the skill shows list_mounts usage.
3. Given a cleanup question, when asked about mount removal, then the skill explains delete_mount with warnings.

---

## Functional Requirements

| ID | Requirement |
|----|-------------|
| FR-001 | Skill MUST cover Vault MCP Server installation (Docker, source) |
| FR-002 | Skill MUST explain transport modes (stdio, StreamableHTTP) |
| FR-003 | Skill MUST cover environment variables (VAULT_ADDR, VAULT_TOKEN, VAULT_NAMESPACE) |
| FR-004 | Skill MUST include VS Code/Claude Desktop integration |
| FR-005 | Skill MUST cover rate limiting configuration |
| FR-006 | Skill MUST explain CORS and security considerations |
| FR-007 | Skill MUST cover all MCP tools: create_mount, list_mounts, delete_mount |
| FR-008 | Skill MUST cover all MCP tools: write_secret, read_secret, list_secrets, delete_secret |
| FR-009 | Skill MUST include example workflows for common tasks |
| FR-010 | Skill MUST differentiate KV v1 vs v2 patterns with MCP |

---

## Skills Included

| Skill | Description |
|-------|-------------|
| `vault-mcp-server` | Install and configure the Vault MCP Server |
| `mcp-secrets-workflows` | Use MCP tools for secrets management workflows |

---

## MCP Tools Reference

### Mount Management Tools

| Tool | Parameters | Description |
|------|------------|-------------|
| `create_mount` | type, path, description | Create KV v1, KV v2, or PKI mount |
| `list_mounts` | (none) | List all mounts in Vault |
| `delete_mount` | path | Delete a mount |

### Key-Value Tools

| Tool | Parameters | Description |
|------|------------|-------------|
| `write_secret` | mount, path, key, value | Write a secret to KV mount |
| `read_secret` | mount, path | Read a secret from KV mount |
| `list_secrets` | mount, path | List secrets under a path |
| `delete_secret` | mount, path, key (optional) | Delete secret or specific key |

---

## Non-Functional Requirements

### NFR-1: Security Awareness

Skills MUST include security notes about not using MCP server with untrusted clients or LLMs.

### NFR-2: Local-Only Recommendation

Skills MUST note the MCP server is intended for local development use at this stage.

---

## References

- [Vault MCP Server GitHub](https://github.com/hashicorp/vault-mcp-server)
- [Model Context Protocol](https://modelcontextprotocol.io/introduction)
- [VS Code MCP Integration](https://code.visualstudio.com/docs/copilot/chat/mcp-servers)
