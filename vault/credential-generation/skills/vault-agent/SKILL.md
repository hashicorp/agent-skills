---
name: vault-agent
description: Configure Vault Agent for automatic authentication, caching, and secret templating. Use when asked about sidecar patterns, auto-auth, token caching, secret file templating, or integrating applications with Vault without SDK changes.
---

# Vault Agent

## What Are You Trying to Solve?

### "My app can't implement Vault SDK integration"
→ Use Vault Agent for **automatic authentication** and token management. [Jump to Basic Config](#basic-configuration)

### "I need secrets rendered to config files"
→ Use **templating** to render secrets to files your app reads. [Jump to Templating](#template-configuration)

### "I want to reduce load on my Vault server"
→ Enable **caching** to store tokens and secrets locally. [Jump to Caching](#caching-configuration)

### "I need secrets injected into Kubernetes pods"
→ Use Agent as a **sidecar** in your pod spec. [Jump to Kubernetes Sidecar](#kubernetes-sidecar)

### "I need to bootstrap an app with secrets once"
→ Use **exec mode** for one-shot injection at startup. [Jump to Best Practices](#best-practices)

---

## How Vault Agent Works

1. **Auto-Auth** → Agent authenticates to Vault using configured method (K8s, AppRole, AWS)
2. **Token Management** → Agent renews token automatically, writes to sink file
3. **Caching** → Agent caches tokens and lease responses locally
4. **Templating** → Agent renders secrets to config files, reloads app when secrets change

**Key insight:** Your app reads files or environment variables—no Vault SDK needed.

---

## Agent Feature Selection

| What You Need | Feature | Configuration |
|---------------|---------|---------------|
| Automatic Vault login | Auto-Auth | `method "kubernetes"` block |
| Token for app to use | Sink | `sink "file"` block |
| Reduce Vault requests | Cache | `cache {}` block |
| Render secrets to files | Template | `template {}` block |
| Proxy API requests | Listener | `listener "tcp"` block |

---

## Reference

- [Vault Agent Documentation](https://developer.hashicorp.com/vault/docs/agent-and-proxy/agent)
- [Detailed Vault Agent Reference](references/vault-agent.md)

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
