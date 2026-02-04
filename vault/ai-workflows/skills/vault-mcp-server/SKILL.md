---
name: vault-mcp-server
description: Install and configure the Vault MCP Server for AI-assisted secrets management. Use when asked about setting up MCP for Vault, configuring Claude or VS Code to use Vault, or integrating AI assistants with HashiCorp Vault. Covers Docker setup, transport modes, environment variables, and security configuration.
---

# Vault MCP Server

## What Are You Trying to Solve?

### "I want Claude or VS Code to manage Vault secrets"
→ Install **Vault MCP Server** via Docker. [Jump to Quick Start](#quick-start-docker)

### "I need to configure VS Code for Vault integration"
→ Create **mcp.json** configuration. [Jump to VS Code Integration](#vs-code-integration)

### "I want to run the server as an HTTP service"
→ Use **StreamableHTTP mode** with CORS. [Jump to HTTP Mode](#streamablehttp-mode)

### "I'm having connection issues"
→ Check **Docker networking and token**. [Jump to Troubleshooting](#troubleshooting)

---

## How Vault MCP Server Works

1. **Start Server** → Run as Docker container or binary (stdio or HTTP mode)
2. **Connect Client** → Claude Desktop or VS Code connects via MCP protocol
3. **Authenticate** → Server uses provided VAULT_TOKEN for all operations
4. **AI Uses Tools** → AI can create mounts, read/write secrets, list paths

**Key insight:** The MCP server proxies AI requests to Vault—AI gets Vault capabilities without direct API access.

---

## Security Notes

> **Warning**: The MCP server is intended for **local development use**. The server may expose Vault data to the connected MCP client and LLM. Do not use with untrusted MCP clients or LLMs.

> **Important**: For HTTP mode, always configure `MCP_ALLOWED_ORIGINS` to prevent DNS rebinding attacks.

---

## Reference

- [Vault MCP Server GitHub](https://github.com/hashicorp/vault-mcp-server)
- [Detailed MCP Server Reference](references/vault-mcp-server.md)

---

## Quick Start (Docker)

```bash
# Start Vault MCP Server with Docker
docker run -i --rm \
  -e VAULT_ADDR='http://host.docker.internal:8200' \
  -e VAULT_TOKEN='<your-token>' \
  hashicorp/vault-mcp-server
```

---

## Installation Options

### Docker (Recommended)

```bash
# Pull the official image
docker pull hashicorp/vault-mcp-server

# Run in stdio mode (for Claude Desktop, VS Code)
docker run -i --rm \
  -e VAULT_ADDR='http://host.docker.internal:8200' \
  -e VAULT_TOKEN='<your-token>' \
  -e VAULT_NAMESPACE='admin' \
  hashicorp/vault-mcp-server

# Run in HTTP mode
docker run --rm -p 8080:8080 \
  -e VAULT_ADDR='http://vault:8200' \
  -e VAULT_TOKEN='<your-token>' \
  -e TRANSPORT_MODE='http' \
  -e MCP_ALLOWED_ORIGINS='http://localhost:3000' \
  hashicorp/vault-mcp-server
```

### From Source

```bash
git clone https://github.com/hashicorp/vault-mcp-server.git
cd vault-mcp-server

# Build
make build

# Run stdio mode
./vault-mcp-server

# Run HTTP mode  
./vault-mcp-server http --transport-port 8080
```

---

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `VAULT_ADDR` | `http://127.0.0.1:8200` | Vault server address |
| `VAULT_TOKEN` | (required) | Vault authentication token |
| `VAULT_NAMESPACE` | (optional) | Vault Enterprise namespace |
| `TRANSPORT_MODE` | `stdio` | `stdio` or `http` |
| `TRANSPORT_HOST` | `127.0.0.1` | HTTP bind host |
| `TRANSPORT_PORT` | `8080` | HTTP bind port |
| `MCP_ENDPOINT` | `/mcp` | HTTP endpoint path |
| `MCP_ALLOWED_ORIGINS` | `""` | CORS allowed origins (comma-separated) |
| `MCP_CORS_MODE` | `strict` | `strict`, `development`, or `disabled` |
| `MCP_TLS_CERT_FILE` | `""` | TLS certificate path |
| `MCP_TLS_KEY_FILE` | `""` | TLS key path |
| `MCP_RATE_LIMIT_GLOBAL` | `10:20` | Global rate limit (rps:burst) |
| `MCP_RATE_LIMIT_SESSION` | `5:10` | Per-session rate limit (rps:burst) |

---

## VS Code Integration

Create `.vscode/mcp.json` in your workspace:

### Stdio Mode (Recommended)

```json
{
  "inputs": [
    {
      "type": "promptString",
      "id": "vault_addr",
      "description": "Vault Address",
      "password": false
    },
    {
      "type": "promptString",
      "id": "vault_token",
      "description": "Vault Token",
      "password": true
    }
  ],
  "servers": {
    "vault-mcp-server": {
      "command": "docker",
      "args": [
        "run", "-i", "--rm",
        "-e", "VAULT_ADDR=${input:vault_addr}",
        "-e", "VAULT_TOKEN=${input:vault_token}",
        "hashicorp/vault-mcp-server"
      ]
    }
  }
}
```

### HTTP Mode

```json
{
  "inputs": [
    {
      "type": "promptString",
      "id": "vault_token",
      "description": "Vault Token",
      "password": true
    }
  ],
  "servers": {
    "vault-mcp-server": {
      "url": "http://localhost:8080/mcp?VAULT_ADDR=http://127.0.0.1:8200",
      "headers": {
        "X-Vault-Token": "${input:vault_token}"
      }
    }
  }
}
```

---

## Transport Modes

### Stdio Mode (Default)

- Used by Claude Desktop, VS Code with Docker
- MCP server runs as subprocess
- Communication via stdin/stdout
- Best for local development

### StreamableHTTP Mode

- Server runs as HTTP service
- Multiple clients can connect
- Requires CORS configuration for security
- Use for shared development environments

---

## Rate Limiting

Control request rates to protect your Vault server:

```bash
# Global: 10 requests/second, burst of 20
# Session: 5 requests/second, burst of 10
docker run -i --rm \
  -e VAULT_ADDR='http://vault:8200' \
  -e VAULT_TOKEN='<token>' \
  -e MCP_RATE_LIMIT_GLOBAL='10:20' \
  -e MCP_RATE_LIMIT_SESSION='5:10' \
  hashicorp/vault-mcp-server
```

---

## TLS Configuration

For secure HTTP transport:

```bash
docker run --rm -p 8443:8443 \
  -v /path/to/certs:/certs:ro \
  -e TRANSPORT_MODE='http' \
  -e TRANSPORT_PORT='8443' \
  -e MCP_TLS_CERT_FILE='/certs/cert.pem' \
  -e MCP_TLS_KEY_FILE='/certs/key.pem' \
  hashicorp/vault-mcp-server
```

---

## Available MCP Tools

Once connected, the following tools are available:

| Tool | Description |
|------|-------------|
| `create_mount` | Create KV, KV v2, or PKI mount |
| `list_mounts` | List all mounts |
| `delete_mount` | Delete a mount |
| `write_secret` | Write secret to KV mount |
| `read_secret` | Read secret from KV mount |
| `list_secrets` | List secrets in path |
| `delete_secret` | Delete secret or key |

For detailed tool usage patterns, see [mcp-secrets-workflows](../mcp-secrets-workflows/SKILL.md).

---

## Troubleshooting

### Connection Refused

```bash
# Check Vault is accessible
curl $VAULT_ADDR/v1/sys/health

# For Docker, use host.docker.internal (macOS/Windows)
# or --network=host (Linux)
docker run --network=host -i --rm \
  -e VAULT_ADDR='http://127.0.0.1:8200' \
  hashicorp/vault-mcp-server
```

### Token Errors

```bash
# Verify token is valid
vault token lookup

# Check token has required policies
vault token capabilities $VAULT_TOKEN sys/mounts
```

---

For detailed configuration examples and advanced patterns, see [references/vault-mcp-server.md](references/vault-mcp-server.md).
