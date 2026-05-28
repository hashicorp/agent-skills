---
name: vault-agent
description: Comprehensive guidance on Vault Agent configuration including auto-auth, caching, and templating
---

# Vault Agent

This reference provides comprehensive guidance on Vault Agent configuration for automatic authentication, secret caching, and secret templating.

---

## Overview

Vault Agent is a client daemon that provides:

- **Auto-Auth**: Automatic authentication to Vault
- **Caching**: Local caching of tokens and secrets
- **Templating**: Render secrets to files using templates
- **Process Management**: Run applications with secrets injected

### When to Use Vault Agent

| Scenario | Vault Agent? | Alternative |
| ---------- | -------------- | ------------- |
| Legacy apps can't integrate Vault SDK | ✅ Yes | - |
| Kubernetes pods needing secrets | ✅ Yes | VSO, CSI Provider |
| Token renewal management | ✅ Yes | SDK auto-renewal |
| Local secret caching | ✅ Yes | - |
| Sidecar pattern | ✅ Yes | - |
| High-frequency secret access | ✅ Yes (with cache) | Direct API |

---

## Basic Configuration

### Minimal Configuration

```hcl
# vault-agent.hcl
vault {
  address = "https://vault.example.com:8200"
  retry {
    num_retries = 5
  }
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
      path = "/home/app/.vault-token"
    }
  }
}
```

### Run Vault Agent

```bash
# Run in foreground
vault agent -config=vault-agent.hcl

# Run as daemon
vault agent -config=vault-agent.hcl &

# Systemd service
sudo systemctl start vault-agent
```

---

## Auto-Auth Methods

### Kubernetes Auto-Auth

```hcl
auto_auth {
  method "kubernetes" {
    mount_path = "auth/kubernetes"
    config = {
      role = "my-app"
      
      # Optional: specify service account token path
      token_path = "/var/run/secrets/kubernetes.io/serviceaccount/token"
    }
  }

  sink "file" {
    config = {
      path = "/home/app/.vault-token"
      mode = 0640
    }
  }
}
```

### AppRole Auto-Auth

```hcl
auto_auth {
  method "approle" {
    mount_path = "auth/approle"
    config = {
      role_id_file_path   = "/etc/vault.d/role-id"
      secret_id_file_path = "/etc/vault.d/secret-id"
      
      # Remove secret-id file after reading
      remove_secret_id_file_after_reading = true
    }
  }

  sink "file" {
    config = {
      path = "/home/app/.vault-token"
    }
  }
}
```

### AWS Auto-Auth

```hcl
auto_auth {
  method "aws" {
    mount_path = "auth/aws"
    config = {
      type = "iam"
      role = "my-app"
      
      # Optional: for cross-account
      # header_value = "vault.example.com"
    }
  }

  sink "file" {
    config = {
      path = "/home/app/.vault-token"
    }
  }
}
```

### Azure Auto-Auth

```hcl
auto_auth {
  method "azure" {
    mount_path = "auth/azure"
    config = {
      role     = "my-app"
      resource = "https://management.azure.com/"
    }
  }

  sink "file" {
    config = {
      path = "/home/app/.vault-token"
    }
  }
}
```

### GCP Auto-Auth

```hcl
auto_auth {
  method "gcp" {
    mount_path = "auth/gcp"
    config = {
      type = "gce"
      role = "my-app"
    }
  }

  sink "file" {
    config = {
      path = "/home/app/.vault-token"
    }
  }
}
```

### JWT Auto-Auth (for OIDC/CI-CD)

```hcl
auto_auth {
  method "jwt" {
    mount_path = "auth/jwt"
    config = {
      role = "ci-runner"
      path = "/var/run/secrets/jwt/token"
    }
  }

  sink "file" {
    config = {
      path = "/home/app/.vault-token"
    }
  }
}
```

---

## Token Sinks

### File Sink

```hcl
sink "file" {
  config = {
    path = "/home/app/.vault-token"
    mode = 0640
  }
  
  # Wrap token before writing
  wrap_ttl = "5m"
}
```

### Multiple Sinks

```hcl
auto_auth {
  method "kubernetes" {
    config = {
      role = "my-app"
    }
  }

  # Main token file
  sink "file" {
    config = {
      path = "/home/app/.vault-token"
    }
  }

  # Wrapped token for handoff
  sink "file" {
    wrap_ttl = "5m"
    config = {
      path = "/tmp/wrapped-token"
    }
  }
}
```

---

## Caching

### Enable Caching

```hcl
cache {
  use_auto_auth_token = true
  
  # Persist cache across restarts
  persist = {
    type = "kubernetes"
    path = "/vault/agent-cache"
    keep_after_import = true
    exit_on_err = true
  }
}

listener "tcp" {
  address     = "127.0.0.1:8200"
  tls_disable = true
}
```

### Caching Configuration Options

```hcl
cache {
  # Use token from auto_auth
  use_auto_auth_token = true
  
  # Force use of auto-auth token (ignore VAULT_TOKEN)
  use_auto_auth_token_strict = true
  
  # Cache static secrets (not just tokens)
  cache_static_secrets = true
  
  # Persist cache to disk
  persist = {
    type = "kubernetes"
    path = "/vault/agent-cache"
    keep_after_import = true
    exit_on_err = true
  }
}

# Local listener for cached requests
listener "tcp" {
  address     = "127.0.0.1:8200"
  tls_disable = true
  
  # Optional: require role for access
  # require_request_header = true
}

listener "unix" {
  address     = "/var/run/vault-agent.sock"
  tls_disable = true
}
```

### Cache Benefits

| Benefit | Description |
| --------- | ------------- |
| Reduced latency | Local cache eliminates network round-trip |
| Reduced Vault load | Fewer requests to Vault cluster |
| Offline resilience | Cached secrets available if Vault temporarily unavailable |
| Token management | Agent handles renewal automatically |

---

## Templating

### Basic Template Configuration

```hcl
template {
  source      = "/etc/vault-templates/app.ctmpl"
  destination = "/etc/app/config.json"
  
  # File permissions
  perms = 0640
  
  # Run command after render
  command = "systemctl reload app"
}

template {
  # Inline template (no source file)
  contents = <<EOF
{
  "database": {
    "host": "{{ with secret "database/creds/readonly" }}{{ .Data.host }}{{ end }}",
    "username": "{{ with secret "database/creds/readonly" }}{{ .Data.username }}{{ end }}",
    "password": "{{ with secret "database/creds/readonly" }}{{ .Data.password }}{{ end }}"
  }
}
EOF
  destination = "/etc/app/db-config.json"
}
```

### Template Syntax (Consul-Template)

```gotpl
{{/* Read KV v2 secret */}}
{{ with secret "secret/data/myapp/config" }}
USERNAME={{ .Data.data.username }}
PASSWORD={{ .Data.data.password }}
{{ end }}

{{/* Read dynamic database credentials */}}
{{ with secret "database/creds/readonly" }}
DB_USER={{ .Data.username }}
DB_PASS={{ .Data.password }}
{{ end }}

{{/* Read PKI certificate */}}
{{ with pkiCert "pki_int/issue/web-server" "common_name=web.example.com" }}
{{ .Cert }}{{ end }}

{{/* Loop over secrets */}}
{{ range secrets "secret/metadata/myapp/" }}
{{ with secret (printf "secret/data/myapp/%s" .) }}
{{ .Data.data.value }}
{{ end }}
{{ end }}

{{/* Conditional logic */}}
{{ with secret "secret/data/myapp/config" }}
{{ if .Data.data.debug }}
DEBUG=true
{{ else }}
DEBUG=false
{{ end }}
{{ end }}
```

### Template Options

```hcl
template {
  source      = "/etc/vault-templates/app.ctmpl"
  destination = "/etc/app/config.json"
  
  # File permissions
  perms       = 0640
  
  # Create parent directories
  create_dest_dirs = true
  
  # Error handling
  error_on_missing_key = true
  
  # Command to run after rendering
  command         = "systemctl reload app"
  command_timeout = "30s"
  
  # Render settings
  wait {
    min = "5s"
    max = "10s"
  }
  
  # Backup before overwrite
  backup = true
  
  # Left/right delimiters (if {{ conflicts)
  left_delimiter  = "[["
  right_delimiter = "]]"
}
```

### Template Environment Variable

```hcl
# Allow empty secrets (don't error)
template {
  contents    = "{{ with secret \"secret/data/myapp\" }}{{ .Data.data.value }}{{ end }}"
  destination = "/etc/app/secret"
  
  # Don't error on missing key
  error_on_missing_key = false
}
```

Alternatively, use environment variable:

```bash
export VAULT_AGENT_TEMPLATING_EMPTY_SECRET_ALLOW=true
```

### Debugging Templates

```gotpl
{{/* Print all keys in secret */}}
{{ with secret "secret/data/myapp/config" }}
{{ range $k, $v := .Data.data }}
Key: {{ $k }}
{{ end }}
{{ end }}

{{/* Print raw data structure */}}
{{ with secret "secret/data/myapp/config" }}
{{ .Data | toJSON }}
{{ end }}
```

---

## Process Management (Exec Mode)

### Run Application with Secrets

```hcl
exec {
  command                   = ["/usr/bin/myapp", "--config", "/etc/app/config.json"]
  restart_on_secret_changes = "always"
  restart_stop_signal       = "SIGTERM"
}
```

### Exec with Environment Variables

```hcl
template {
  contents    = "{{ with secret \"secret/data/myapp\" }}{{ .Data.data.api_key }}{{ end }}"
  destination = "/tmp/api_key"
}

env_template "API_KEY" {
  contents = "{{ with secret \"secret/data/myapp\" }}{{ .Data.data.api_key }}{{ end }}"
}

exec {
  command = ["/usr/bin/myapp"]
  
  # Inject environment variables
  env {
    MY_VAR = "value"
  }
  
  # Restart on secret changes
  restart_on_secret_changes = "always"
}
```

### Restart Behaviors

| Mode | Behavior |
| ------ | ---------- |
| `always` | Restart on any secret change |
| `never` | Never restart (signal only) |

---

## Sidecar Patterns

### Kubernetes Sidecar (Manual)

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: myapp
spec:
  serviceAccountName: myapp-sa
  
  volumes:
    - name: vault-token
      emptyDir:
        medium: Memory
    - name: secrets
      emptyDir:
        medium: Memory
    - name: vault-config
      configMap:
        name: vault-agent-config
  
  initContainers:
    - name: vault-agent-init
      image: hashicorp/vault:latest
      args:
        - agent
        - -config=/etc/vault/vault-agent.hcl
        - -exit-after-auth
      volumeMounts:
        - name: vault-config
          mountPath: /etc/vault
        - name: secrets
          mountPath: /etc/secrets
  
  containers:
    - name: myapp
      image: myapp:latest
      volumeMounts:
        - name: secrets
          mountPath: /etc/secrets
          readOnly: true
    
    - name: vault-agent
      image: hashicorp/vault:latest
      args:
        - agent
        - -config=/etc/vault/vault-agent.hcl
      volumeMounts:
        - name: vault-config
          mountPath: /etc/vault
        - name: secrets
          mountPath: /etc/secrets
```

### Vault Agent ConfigMap

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: vault-agent-config
data:
  vault-agent.hcl: |
    vault {
      address = "https://vault.example.com:8200"
    }
    
    auto_auth {
      method "kubernetes" {
        mount_path = "auth/kubernetes"
        config = {
          role = "myapp"
        }
      }
    }
    
    template {
      contents = <<EOF
    {{ with secret "secret/data/myapp/config" }}
    {{ .Data.data.database_url }}
    {{ end }}
    EOF
      destination = "/etc/secrets/database-url"
    }
```

---

## Cloud Foundry Sidecar Pattern

```yaml
# manifest.yml
applications:
  - name: myapp
    memory: 512M
    
    sidecars:
      - name: vault-agent
        process_types:
          - web
        command: |
          vault agent -config=/home/vcap/app/vault-agent.hcl
```

```hcl
# vault-agent.hcl for CF
vault {
  address = "https://vault.example.com:8200"
}

auto_auth {
  method "cf" {
    mount_path = "auth/cf"
    config = {
      role = "myapp"
    }
  }
}

template {
  contents    = "{{ with secret \"secret/data/myapp\" }}{{ .Data.data | toJSON }}{{ end }}"
  destination = "/home/vcap/app/secrets.json"
}
```

---

## Complete Example Configuration

```hcl
# Full-featured vault-agent.hcl

pid_file = "/var/run/vault-agent.pid"

vault {
  address = "https://vault.example.com:8200"
  
  retry {
    num_retries = 5
    backoff = {
      initial = "1s"
      max     = "30s"
    }
  }
}

auto_auth {
  method "kubernetes" {
    mount_path = "auth/kubernetes"
    namespace  = "my-namespace"
    config = {
      role = "my-app"
    }
  }

  sink "file" {
    config = {
      path = "/home/app/.vault-token"
      mode = 0640
    }
  }
}

cache {
  use_auto_auth_token = true
  
  persist = {
    type = "kubernetes"
    path = "/vault/agent-cache"
    keep_after_import = true
  }
}

listener "tcp" {
  address     = "127.0.0.1:8200"
  tls_disable = true
}

# Database credentials template
template {
  source      = "/etc/vault-templates/db.ctmpl"
  destination = "/etc/app/db-credentials"
  perms       = 0600
  command     = "pkill -HUP myapp"
}

# Application config template
template {
  contents = <<EOF
{
  "api_key": "{{ with secret "secret/data/myapp" }}{{ .Data.data.api_key }}{{ end }}",
  "environment": "production"
}
EOF
  destination = "/etc/app/config.json"
  perms       = 0644
}

# PKI certificate
template {
  source      = "/etc/vault-templates/tls.ctmpl"
  destination = "/etc/ssl/app/cert.pem"
  perms       = 0644
  command     = "systemctl reload nginx"
}

# Environment variables for exec mode
env_template "DATABASE_URL" {
  contents = "{{ with secret \"database/creds/readonly\" }}postgres://{{ .Data.username }}:{{ .Data.password }}@db.example.com:5432/mydb{{ end }}"
}

exec {
  command = ["/usr/bin/myapp"]
  restart_on_secret_changes = "always"
}
```

---

## Troubleshooting

### Common Issues

| Issue | Cause | Solution |
| ------- | ------- | ---------- |
| Template renders empty | Secret path incorrect | Check path, verify secret exists |
| Auth fails | Role misconfigured | Verify role bindings, service account |
| Agent exits immediately | Config error | Check logs, validate config syntax |
| Secrets not updating | Cache stale | Check lease TTLs, restart agent |

### Debug Commands

```bash
# Validate configuration
vault agent -config=vault-agent.hcl -verify-only

# Run with debug logging
vault agent -config=vault-agent.hcl -log-level=debug

# Check agent logs
journalctl -u vault-agent -f
```

### Template Debugging

```gotpl
{{/* Check if secret exists */}}
{{ with secret "secret/data/myapp" }}
Secret found: {{ .Data.data | toJSON }}
{{ else }}
Secret not found or access denied
{{ end }}

{{/* List available keys */}}
{{ with secret "secret/data/myapp" }}
Keys: {{ .Data.data | keys }}
{{ end }}
```

---

## Best Practices

### Security

- Use `mode` to restrict file permissions
- Clean up secret files on exit
- Use memory-backed volumes in Kubernetes
- Remove secret-id file after reading (AppRole)
- Use short token TTLs with renewal

### Performance

- Enable caching for high-frequency access
- Use persistent cache for restarts
- Set appropriate template render wait times
- Monitor agent resource usage

### Reliability

- Configure retries with backoff
- Use multiple Vault addresses if available
- Handle template errors gracefully
- Monitor agent health

---

## Additional Resources

- [Vault Agent Documentation](https://developer.hashicorp.com/vault/docs/agent-and-proxy/agent)
- [Vault Agent Templates](https://developer.hashicorp.com/vault/docs/agent-and-proxy/agent/template)
- [Auto-Auth Methods](https://developer.hashicorp.com/vault/docs/agent-and-proxy/autoauth/methods)
- [Caching Configuration](https://developer.hashicorp.com/vault/docs/agent-and-proxy/agent/caching)

---

## Related

- [Auth Methods](auth-methods.md) - Auto-auth method configuration
- [Kubernetes Integration](kubernetes.md) - Agent Injector patterns
- [Troubleshooting](troubleshooting.md) - Agent-specific debugging
