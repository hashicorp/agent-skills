---
name: vault-agent
description: Configure Vault Agent for automatic authentication, caching, and secret templating. Use when asked about sidecar patterns, auto-auth, token caching, secret file templating, or integrating applications with Vault without SDK changes.
---

# Vault Agent

Vault Agent is a client daemon that automates authentication, token renewal, and secret templating. It runs alongside your application as a sidecar or daemon, eliminating the need for applications to implement Vault SDK integration.

## Reference

- [Vault Agent Documentation](https://developer.hashicorp.com/vault/docs/agent-and-proxy/agent)
- [Detailed Vault Agent Reference](references/vault-agent.md)

---

## When to Use This Skill

- **Automatic authentication**: Applications need Vault tokens without implementing auth logic
- **Secret file templating**: Render secrets to config files that applications can read
- **Token caching**: Reduce Vault server load with local token/secret caching
- **Sidecar patterns**: Kubernetes pods need secrets injected without code changes
- **Legacy applications**: Integrate apps that can't use Vault SDKs

---

## Core Concepts

### Agent Capabilities

| Feature | Description |
|---------|-------------|
| **Auto-Auth** | Authenticate to Vault and manage token lifecycle |
| **Caching** | Cache tokens and secrets locally |
| **Templating** | Render secrets to files using consul-template syntax |
| **API Proxy** | Proxy Vault API requests with automatic token injection |

---

## Quick Reference

### Basic Configuration

```hcl
# vault-agent.hcl
vault {
  address = "https://vault.example.com:8200"
}

auto_auth {
  method "kubernetes" {
    mount_path = "auth/kubernetes"
    config = {
      role = "my-app"
    }
  }

  sink "file" {
    config = {
      path = "/home/vault/.vault-token"
    }
  }
}

cache {
  use_auto_auth_token = true
}
```

### Template Configuration

```hcl
template {
  source      = "/etc/vault/templates/config.ctmpl"
  destination = "/app/config.txt"
  command     = "systemctl reload myapp"
}
```

### Template Syntax

```text
{{- with secret "secret/data/myapp/config" -}}
DB_HOST={{ .Data.data.host }}
DB_USER={{ .Data.data.username }}
DB_PASS={{ .Data.data.password }}
{{- end }}
```

---

## Common Patterns

### Kubernetes Sidecar

```yaml
# Pod spec with Vault Agent sidecar
containers:
  - name: vault-agent
    image: hashicorp/vault:latest
    args:
      - agent
      - -config=/etc/vault/agent.hcl
    volumeMounts:
      - name: vault-agent-config
        mountPath: /etc/vault
      - name: shared-data
        mountPath: /vault/secrets
  - name: app
    image: myapp:latest
    volumeMounts:
      - name: shared-data
        mountPath: /vault/secrets
        readOnly: true
```

### Auto-Auth Methods

```hcl
# Kubernetes (most common for K8s)
method "kubernetes" {
  mount_path = "auth/kubernetes"
  config = { role = "my-app" }
}

# AppRole (for non-K8s automation)
method "approle" {
  config = {
    role_id_file_path   = "/etc/vault/role-id"
    secret_id_file_path = "/etc/vault/secret-id"
    remove_secret_id_file_after_reading = true
  }
}

# AWS (for EC2/Lambda)
method "aws" {
  config = { role = "aws-role" }
}
```

### Caching Configuration

```hcl
cache {
  use_auto_auth_token = true
  persist {
    type = "kubernetes"
    path = "/vault/cache"
  }
}

listener "tcp" {
  address     = "127.0.0.1:8200"
  tls_disable = true
}
```

---

## Best Practices

- **Use file sinks** to write tokens where applications expect them
- **Enable caching** to reduce Vault server load
- **Set template `command`** to reload apps when secrets change
- **Use `exec` mode** for one-shot secret injection at startup
- **Run as sidecar** in Kubernetes for pod-level isolation

---

For complete auto-auth method configurations, advanced templating, and production deployment patterns, see [references/vault-agent.md](references/vault-agent.md).
