---
name: vault-mcp-server-reference
description: Detailed configuration reference for the Vault MCP Server including installation, transport modes, environment variables, and IDE integration
---

# Vault MCP Server Reference

This reference provides detailed configuration for the HashiCorp Vault MCP Server.

---

## Overview

The Vault MCP Server implements the [Model Context Protocol (MCP)](https://modelcontextprotocol.io) to enable AI assistants to interact with HashiCorp Vault. It supports both stdio and StreamableHTTP transports.

---

## Installation

### Docker (Recommended)

```bash
# Pull latest image
docker pull hashicorp/vault-mcp-server

# Verify installation
docker run --rm hashicorp/vault-mcp-server --version
```

### From Source

```bash
# Clone repository
git clone https://github.com/hashicorp/vault-mcp-server.git
cd vault-mcp-server

# Build (requires Go 1.24+)
make build

# Build Docker image
make docker-build

# Build with custom registry
make docker-build DOCKER_REGISTRY=your-registry.com
```

---

## Transport Modes

### Stdio Mode (Default)

Standard input/output mode for subprocess communication.

```bash
# Run in stdio mode
./vault-mcp-server
# or explicitly
./vault-mcp-server stdio

# With Docker
docker run -i --rm \
  -e VAULT_ADDR='http://host.docker.internal:8200' \
  -e VAULT_TOKEN='<token>' \
  hashicorp/vault-mcp-server
```

**When to use:**
- Claude Desktop integration
- VS Code with Docker
- Local development
- Single-user scenarios

### StreamableHTTP Mode

HTTP server mode for multi-client access.

```bash
# Run in HTTP mode
./vault-mcp-server http --transport-port 8080

# With Docker
docker run --rm -p 8080:8080 \
  -e TRANSPORT_MODE='http' \
  -e TRANSPORT_PORT='8080' \
  -e VAULT_ADDR='http://vault:8200' \
  -e VAULT_TOKEN='<token>' \
  hashicorp/vault-mcp-server
```

**When to use:**
- Shared development environments
- Multiple clients connecting
- Custom tooling integration

---

## Environment Variables Reference

### Vault Connection

| Variable | Default | Required | Description |
|----------|---------|----------|-------------|
| `VAULT_ADDR` | `http://127.0.0.1:8200` | No | Vault server URL |
| `VAULT_TOKEN` | - | **Yes** | Authentication token |
| `VAULT_NAMESPACE` | - | No | Enterprise namespace |

### Transport Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `TRANSPORT_MODE` | `stdio` | `stdio` or `http` |
| `TRANSPORT_HOST` | `127.0.0.1` | HTTP bind address |
| `TRANSPORT_PORT` | `8080` | HTTP bind port |
| `MCP_ENDPOINT` | `/mcp` | HTTP endpoint path |

### Security Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `MCP_ALLOWED_ORIGINS` | `""` | CORS allowed origins (comma-separated) |
| `MCP_CORS_MODE` | `strict` | `strict`, `development`, `disabled` |
| `MCP_TLS_CERT_FILE` | `""` | TLS certificate file path |
| `MCP_TLS_KEY_FILE` | `""` | TLS private key file path |

### Rate Limiting

| Variable | Default | Description |
|----------|---------|-------------|
| `MCP_RATE_LIMIT_GLOBAL` | `10:20` | Global limit (requests/sec:burst) |
| `MCP_RATE_LIMIT_SESSION` | `5:10` | Per-session limit (requests/sec:burst) |

---

## IDE Integration

### Visual Studio Code

Create `.vscode/mcp.json` in your workspace:

#### Stdio Mode with Docker

```json
{
  "inputs": [
    {
      "type": "promptString",
      "id": "vault_addr",
      "description": "Vault Address (e.g., http://127.0.0.1:8200)",
      "password": false
    },
    {
      "type": "promptString",
      "id": "vault_token",
      "description": "Vault Token",
      "password": true
    },
    {
      "type": "promptString",
      "id": "vault_namespace",
      "description": "Vault Namespace (optional)",
      "password": false
    }
  ],
  "servers": {
    "vault-mcp-server": {
      "command": "docker",
      "args": [
        "run", "-i", "--rm",
        "-e", "VAULT_ADDR=${input:vault_addr}",
        "-e", "VAULT_TOKEN=${input:vault_token}",
        "-e", "VAULT_NAMESPACE=${input:vault_namespace}",
        "hashicorp/vault-mcp-server"
      ]
    }
  }
}
```

#### HTTP Mode

```json
{
  "inputs": [
    {
      "type": "promptString",
      "id": "vault_token",
      "description": "Vault Token",
      "password": true
    },
    {
      "type": "promptString",
      "id": "vault_namespace",
      "description": "Vault Namespace (optional)",
      "password": false
    }
  ],
  "servers": {
    "vault-mcp-server": {
      "url": "http://localhost:8080/mcp?VAULT_ADDR=http://127.0.0.1:8200",
      "headers": {
        "X-Vault-Token": "${input:vault_token}",
        "X-Vault-Namespace": "${input:vault_namespace}"
      }
    }
  }
}
```

### Claude Desktop

Add to Claude Desktop configuration:

```json
{
  "mcpServers": {
    "vault": {
      "command": "docker",
      "args": [
        "run", "-i", "--rm",
        "-e", "VAULT_ADDR=http://host.docker.internal:8200",
        "-e", "VAULT_TOKEN=<your-token>",
        "hashicorp/vault-mcp-server"
      ]
    }
  }
}
```

### Gemini Extensions

```bash
# Create environment file
cat > ~/.gemini/.env << EOF
VAULT_ADDR=http://127.0.0.1:8200
VAULT_TOKEN=<your-token>
VAULT_NAMESPACE=admin
EOF

# Install and run
gemini extensions install https://github.com/hashicorp/vault-mcp-server
gemini
```

---

## HTTP Mode Configuration Details

### CORS Configuration

```bash
# Strict mode (default) - requires explicit origins
docker run -p 8080:8080 \
  -e TRANSPORT_MODE='http' \
  -e MCP_CORS_MODE='strict' \
  -e MCP_ALLOWED_ORIGINS='http://localhost:3000,https://myapp.example.com' \
  hashicorp/vault-mcp-server

# Development mode - allows localhost automatically
docker run -p 8080:8080 \
  -e TRANSPORT_MODE='http' \
  -e MCP_CORS_MODE='development' \
  hashicorp/vault-mcp-server

# Disabled - no CORS headers (not recommended)
docker run -p 8080:8080 \
  -e TRANSPORT_MODE='http' \
  -e MCP_CORS_MODE='disabled' \
  hashicorp/vault-mcp-server
```

### TLS Configuration

```bash
# Generate self-signed certificate (development)
openssl req -x509 -newkey rsa:4096 -keyout key.pem -out cert.pem -days 365 -nodes

# Run with TLS
docker run -p 8443:8443 \
  -v $(pwd)/certs:/certs:ro \
  -e TRANSPORT_MODE='http' \
  -e TRANSPORT_PORT='8443' \
  -e MCP_TLS_CERT_FILE='/certs/cert.pem' \
  -e MCP_TLS_KEY_FILE='/certs/key.pem' \
  hashicorp/vault-mcp-server
```

### Rate Limiting

```bash
# Configure rate limits
# Format: requests_per_second:burst_size
docker run -p 8080:8080 \
  -e TRANSPORT_MODE='http' \
  -e MCP_RATE_LIMIT_GLOBAL='20:50' \
  -e MCP_RATE_LIMIT_SESSION='10:25' \
  hashicorp/vault-mcp-server
```

---

## Vault Configuration in HTTP Mode

In HTTP mode, Vault configuration can be provided through multiple methods (in order of precedence):

1. **HTTP Query Parameters**: `?VAULT_ADDR=...`
2. **HTTP Headers**: `X-Vault-Token`, `X-Vault-Namespace`
3. **Environment Variables**: Standard Vault env vars

### Example Request

```bash
curl -X POST http://localhost:8080/mcp \
  -H "Content-Type: application/json" \
  -H "X-Vault-Token: hvs.xxx" \
  -H "X-Vault-Namespace: admin" \
  -d '{"method": "list_mounts"}'
```

---

## Docker Networking

### macOS / Windows

Use `host.docker.internal` to access host network:

```bash
docker run -i --rm \
  -e VAULT_ADDR='http://host.docker.internal:8200' \
  hashicorp/vault-mcp-server
```

### Linux

Use `--network=host` or explicit IP:

```bash
# Option 1: Host network
docker run --network=host -i --rm \
  -e VAULT_ADDR='http://127.0.0.1:8200' \
  hashicorp/vault-mcp-server

# Option 2: Docker network with Vault container
docker network create mcp
docker run --network=mcp -i --rm \
  -e VAULT_ADDR='http://vault:8200' \
  hashicorp/vault-mcp-server
```

---

## Security Considerations

### Token Permissions

Create a dedicated token with minimal permissions:

```hcl
# Minimal policy for MCP operations
path "sys/mounts" {
  capabilities = ["read", "list"]
}

path "sys/mounts/*" {
  capabilities = ["create", "delete"]
}

path "secret/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}
```

```bash
vault policy write mcp-user mcp-policy.hcl
vault token create -policy=mcp-user -ttl=8h
```

### Audit Logging

All MCP operations are logged in Vault audit logs:

```bash
# Enable audit logging
vault audit enable file file_path=/var/log/vault/audit.log

# View MCP operations
grep "mcp" /var/log/vault/audit.log
```

---

## Troubleshooting

### Connection Issues

```bash
# Test Vault connectivity
curl $VAULT_ADDR/v1/sys/health

# Check Docker can reach Vault
docker run --rm curlimages/curl \
  curl -s http://host.docker.internal:8200/v1/sys/health
```

### Token Issues

```bash
# Verify token
vault token lookup

# Check capabilities
vault token capabilities $VAULT_TOKEN sys/mounts
vault token capabilities $VAULT_TOKEN secret/data/test
```

### Debug Logging

```bash
# Enable debug output
docker run -i --rm \
  -e VAULT_ADDR='http://host.docker.internal:8200' \
  -e VAULT_TOKEN='<token>' \
  -e LOG_LEVEL='debug' \
  hashicorp/vault-mcp-server
```

---

## Additional Resources

- [Vault MCP Server GitHub](https://github.com/hashicorp/vault-mcp-server)
- [Model Context Protocol Specification](https://modelcontextprotocol.io/specification)
- [VS Code MCP Integration](https://code.visualstudio.com/docs/copilot/chat/mcp-servers)

---

## Related

- [mcp-secrets-workflows.md](../mcp-secrets-workflows/references/mcp-secrets-workflows.md) - MCP tool usage patterns
- [auth-methods.md](../../../authentication/skills/auth-methods/references/auth-methods.md) - Token authentication
