---
name: vault-kubernetes
description: Comprehensive guidance on Vault Kubernetes integration including VSO, Agent Injector, and CSI Provider
---

# Vault Kubernetes Integration

This reference provides comprehensive guidance on integrating Vault with Kubernetes.

---

## Supported Kubernetes Versions

| Component | Supported Versions |
| ----------- | ------------------- |
| VSO | Kubernetes 1.29 - 1.33 |
| Agent Injector | Kubernetes 1.16+ |
| CSI Provider | Kubernetes 1.16+ |

VSO also supports Red Hat OpenShift 4.10+.

---

## Integration Options

| Method | Use Case | Complexity |
| -------- | ---------- | ------------ |
| **Vault Secrets Operator (VSO)** | Modern K8s-native, CRD-based | Low |
| **Vault Agent Injector** | Sidecar injection via annotations | Medium |
| **CSI Provider** | Mount secrets as volumes | Medium |
| **Direct API** | Custom integration | High |

---

## Vault Secrets Operator (VSO)

Kubernetes-native operator that syncs Vault secrets to Kubernetes Secrets.

### Installation

```bash
# Add HashiCorp Helm repo
helm repo add hashicorp https://helm.releases.hashicorp.com
helm repo update

# Install VSO
helm install vault-secrets-operator hashicorp/vault-secrets-operator \
    -n vault-secrets-operator-system \
    --create-namespace
```

### Configure Vault Connection

```yaml
# VaultConnection CRD
apiVersion: secrets.hashicorp.com/v1beta1
kind: VaultConnection
metadata:
  name: vault-connection
  namespace: default
spec:
  address: https://vault.example.com:8200
  caCertSecretRef: vault-ca-cert  # Optional: custom CA
  skipTLSVerify: false
```

### Configure Authentication

```yaml
# VaultAuth CRD - Kubernetes auth
apiVersion: secrets.hashicorp.com/v1beta1
kind: VaultAuth
metadata:
  name: vault-auth
  namespace: default
spec:
  vaultConnectionRef: vault-connection
  method: kubernetes
  mount: kubernetes
  kubernetes:
    role: my-app
    serviceAccount: my-app-sa
    audiences:
      - vault
```

### Sync Static Secrets

```yaml
# VaultStaticSecret - sync KV secrets
apiVersion: secrets.hashicorp.com/v1beta1
kind: VaultStaticSecret
metadata:
  name: my-app-secrets
  namespace: default
spec:
  vaultAuthRef: vault-auth
  mount: secret
  path: myapp/config
  type: kv-v2
  refreshAfter: 60s
  destination:
    name: my-app-secret
    create: true
    labels:
      app: my-app
    transformation:
      excludeRaw: true
      templates:
        username:
          text: "{{ .Secrets.username }}"
        password:
          text: "{{ .Secrets.password }}"
```

### Sync Dynamic Secrets

```yaml
# VaultDynamicSecret - database credentials
apiVersion: secrets.hashicorp.com/v1beta1
kind: VaultDynamicSecret
metadata:
  name: db-creds
  namespace: default
spec:
  vaultAuthRef: vault-auth
  mount: database
  path: creds/readonly
  destination:
    name: db-credentials
    create: true
  renewalPercent: 75
```

### Sync PKI Certificates

```yaml
# VaultPKISecret - TLS certificates
apiVersion: secrets.hashicorp.com/v1beta1
kind: VaultPKISecret
metadata:
  name: web-tls
  namespace: default
spec:
  vaultAuthRef: vault-auth
  mount: pki_int
  role: web-servers
  commonName: web.example.com
  altNames:
    - www.example.com
  ttl: 72h
  destination:
    name: web-tls-secret
    create: true
    type: kubernetes.io/tls
```

---

## Vault Agent Injector

Sidecar injection using Kubernetes MutatingWebhook.

### Agent Injector Installation

```bash
helm install vault hashicorp/vault \
    --set "injector.enabled=true" \
    --set "injector.externalVaultAddr=https://vault.example.com:8200"
```

### Pod Annotations

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: my-app
  annotations:
    # Enable injection
    vault.hashicorp.com/agent-inject: "true"
    
    # Vault role for authentication
    vault.hashicorp.com/role: "my-app"
    
    # Secret to inject
    vault.hashicorp.com/agent-inject-secret-config.txt: "secret/data/myapp/config"
    
    # Template for secret format
    vault.hashicorp.com/agent-inject-template-config.txt: |
      {{- with secret "secret/data/myapp/config" -}}
      DATABASE_URL=postgresql://{{ .Data.data.username }}:{{ .Data.data.password }}@db:5432/mydb
      {{- end }}
spec:
  serviceAccountName: my-app-sa
  containers:
    - name: app
      image: my-app:latest
      # Secrets available at /vault/secrets/config.txt
```

### Common Annotations

```yaml
annotations:
  # Authentication
  vault.hashicorp.com/agent-inject: "true"
  vault.hashicorp.com/role: "my-app"
  vault.hashicorp.com/auth-path: "auth/kubernetes"
  
  # Secret injection
  vault.hashicorp.com/agent-inject-secret-<name>: "<path>"
  vault.hashicorp.com/agent-inject-template-<name>: "<template>"
  
  # File permissions
  vault.hashicorp.com/agent-inject-perms-<name>: "0400"
  
  # Container configuration
  vault.hashicorp.com/agent-pre-populate: "true"
  vault.hashicorp.com/agent-pre-populate-only: "false"
  
  # Resource limits
  vault.hashicorp.com/agent-limits-cpu: "250m"
  vault.hashicorp.com/agent-limits-mem: "128Mi"
  vault.hashicorp.com/agent-requests-cpu: "50m"
  vault.hashicorp.com/agent-requests-mem: "64Mi"
  
  # Init container only (no sidecar)
  vault.hashicorp.com/agent-pre-populate-only: "true"
```

### Template Examples

```yaml
# JSON format
vault.hashicorp.com/agent-inject-template-config.json: |
  {{- with secret "secret/data/myapp/config" -}}
  {
    "username": "{{ .Data.data.username }}",
    "password": "{{ .Data.data.password }}"
  }
  {{- end }}

# Environment file
vault.hashicorp.com/agent-inject-template-env: |
  {{- with secret "secret/data/myapp/config" -}}
  export DB_USER="{{ .Data.data.username }}"
  export DB_PASS="{{ .Data.data.password }}"
  {{- end }}

# Database credentials (dynamic)
vault.hashicorp.com/agent-inject-template-db-creds: |
  {{- with secret "database/creds/readonly" -}}
  DB_USER={{ .Data.username }}
  DB_PASS={{ .Data.password }}
  {{- end }}
```

---

## Vault CSI Provider

Mount secrets as Kubernetes volumes using Container Storage Interface.

### CSI Provider Installation

```bash
# Install Secrets Store CSI Driver
helm install csi-secrets-store secrets-store-csi-driver/secrets-store-csi-driver \
    -n kube-system \
    --set syncSecret.enabled=true

# Install Vault CSI Provider
helm install vault hashicorp/vault \
    --set "csi.enabled=true" \
    --set "injector.enabled=false" \
    --set "server.enabled=false"
```

### SecretProviderClass

```yaml
apiVersion: secrets-store.csi.x-k8s.io/v1
kind: SecretProviderClass
metadata:
  name: vault-secrets
spec:
  provider: vault
  parameters:
    vaultAddress: "https://vault.example.com:8200"
    roleName: "my-app"
    objects: |
      - objectName: "db-password"
        secretPath: "secret/data/myapp/config"
        secretKey: "password"
      - objectName: "api-key"
        secretPath: "secret/data/myapp/config"
        secretKey: "api_key"
  # Sync to Kubernetes Secret
  secretObjects:
    - secretName: my-app-secrets
      type: Opaque
      data:
        - objectName: db-password
          key: password
        - objectName: api-key
          key: api_key
```

### Pod Configuration

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: my-app
spec:
  serviceAccountName: my-app-sa
  containers:
    - name: app
      image: my-app:latest
      volumeMounts:
        - name: secrets
          mountPath: "/mnt/secrets"
          readOnly: true
      env:
        - name: DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: my-app-secrets
              key: password
  volumes:
    - name: secrets
      csi:
        driver: secrets-store.csi.k8s.io
        readOnly: true
        volumeAttributes:
          secretProviderClass: vault-secrets
```

---

## Vault Agent Sidecar (Manual)

For advanced customization, configure Vault Agent directly.

### ConfigMap

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: vault-agent-config
data:
  config.hcl: |
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

    template {
      source      = "/vault/templates/config.ctmpl"
      destination = "/vault/secrets/config.txt"
    }

  config.ctmpl: |
    {{- with secret "secret/data/myapp/config" -}}
    DATABASE_URL=postgresql://{{ .Data.data.username }}:{{ .Data.data.password }}@db:5432/mydb
    {{- end }}
```

### Pod with Vault Agent Sidecar

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: my-app
spec:
  serviceAccountName: my-app-sa
  initContainers:
    - name: vault-agent-init
      image: hashicorp/vault:latest
      args:
        - agent
        - -config=/vault/config/config.hcl
        - -exit-after-auth
      volumeMounts:
        - name: vault-config
          mountPath: /vault/config
        - name: vault-secrets
          mountPath: /vault/secrets
        - name: vault-templates
          mountPath: /vault/templates
  containers:
    - name: app
      image: my-app:latest
      volumeMounts:
        - name: vault-secrets
          mountPath: /vault/secrets
          readOnly: true
    - name: vault-agent
      image: hashicorp/vault:latest
      args:
        - agent
        - -config=/vault/config/config.hcl
      volumeMounts:
        - name: vault-config
          mountPath: /vault/config
        - name: vault-secrets
          mountPath: /vault/secrets
        - name: vault-templates
          mountPath: /vault/templates
  volumes:
    - name: vault-config
      configMap:
        name: vault-agent-config
    - name: vault-secrets
      emptyDir:
        medium: Memory
    - name: vault-templates
      configMap:
        name: vault-agent-config
        items:
          - key: config.ctmpl
            path: config.ctmpl
```

---

## Kubernetes Auth Method Setup

### Vault Server Configuration

```bash
# Enable Kubernetes auth
vault auth enable kubernetes

# Get Kubernetes host
KUBE_HOST=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')

# Get Kubernetes CA cert
kubectl get configmap kube-root-ca.crt -n kube-system -o jsonpath='{.data.ca\.crt}' > ca.crt

# Configure auth method
vault write auth/kubernetes/config \
    kubernetes_host="$KUBE_HOST" \
    kubernetes_ca_cert=@ca.crt

# Create role
vault write auth/kubernetes/role/my-app \
    bound_service_account_names=my-app-sa \
    bound_service_account_namespaces=default \
    policies=app-policy \
    ttl=1h
```

### Kubernetes RBAC

```yaml
# ServiceAccount
apiVersion: v1
kind: ServiceAccount
metadata:
  name: my-app-sa
  namespace: default
---
# Required for Vault to validate tokens
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: vault-auth-delegator
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: system:auth-delegator
subjects:
  - kind: ServiceAccount
    name: vault
    namespace: vault
```

---

## Vault Agent Sidecar Production Patterns

Based on production Kubernetes deployments across enterprises:

### Sidecar vs Init-Only Decision

| Scenario | Pattern | Configuration |
| ---------- | --------- | --------------- |
| Static secrets only | Init-only | `agent-pre-populate-only: "true"` |
| Dynamic secrets (database, AWS) | Full sidecar | Default configuration |
| Lease renewal required | Full sidecar | Default configuration |
| Minimize pod overhead | Init-only | `agent-pre-populate-only: "true"` |

### Resource Sizing Guidelines

| Cluster Size | CPU Request | CPU Limit | Memory Request | Memory Limit |
| ------------- | ------------- | ----------- | ---------------- | -------------- |
| Small (<50 pods) | 25m | 100m | 32Mi | 64Mi |
| Medium (50-200 pods) | 50m | 250m | 64Mi | 128Mi |
| Large (>200 pods) | 100m | 500m | 128Mi | 256Mi |

### Production Annotation Set

```yaml
annotations:
  vault.hashicorp.com/agent-inject: "true"
  vault.hashicorp.com/role: "my-app"
  
  # Resource management
  vault.hashicorp.com/agent-limits-cpu: "250m"
  vault.hashicorp.com/agent-limits-mem: "128Mi"
  vault.hashicorp.com/agent-requests-cpu: "50m"
  vault.hashicorp.com/agent-requests-mem: "64Mi"
  
  # Cache configuration (reduce Vault load)
  vault.hashicorp.com/agent-cache-enable: "true"
  vault.hashicorp.com/agent-cache-use-auto-auth-token: "true"
  
  # Template error handling
  vault.hashicorp.com/agent-inject-command-<name>: "sh -c 'kill -HUP $(pidof myapp)'"
  
  # Security
  vault.hashicorp.com/agent-run-as-user: "1000"
  vault.hashicorp.com/agent-run-as-group: "1000"
  vault.hashicorp.com/agent-set-security-context: "true"
```

### Multi-Secret Template Pattern

For applications needing multiple secrets in one file:

```yaml
vault.hashicorp.com/agent-inject-template-app-config: |
  {{- with secret "secret/data/myapp/database" -}}
  DB_HOST={{ .Data.data.host }}
  DB_PORT={{ .Data.data.port }}
  {{- end }}
  {{- with secret "secret/data/myapp/api" -}}
  API_KEY={{ .Data.data.key }}
  API_SECRET={{ .Data.data.secret }}
  {{- end }}
  {{- with secret "database/creds/myapp-role" -}}
  DB_USER={{ .Data.username }}
  DB_PASS={{ .Data.password }}
  {{- end }}
```

### Application Signal Pattern

Notify application when secrets change:

```yaml
annotations:
  # Execute command after rendering secrets
  vault.hashicorp.com/agent-inject-command-secrets: |
    sh -c 'kill -HUP $(cat /var/run/myapp.pid) || true'
```

### Kubernetes Init Container Ordering

When using init-only mode with other init containers:

```yaml
annotations:
  vault.hashicorp.com/agent-pre-populate-only: "true"
  vault.hashicorp.com/agent-init-first: "true"  # Run before other inits
```

### Anti-Patterns to Avoid

| Anti-Pattern | Problem | Solution |
| -------------- | --------- | ---------- |
| Sidecar for static secrets | Wasted resources | Use init-only mode |
| No resource limits | Resource exhaustion | Always set limits |
| Single shared role | Over-privileged | One role per app |
| Caching disabled | Vault overload | Enable agent caching |
| No template error handling | Silent failures | Use error_on_missing_key |

---

## Comparison Matrix

| Feature | VSO | Agent Injector | CSI |
| --------- | ----- | ---------------- | ----- |
| Secrets as K8s Secrets | ✅ | ❌ | ✅ |
| Secrets as files | ✅ | ✅ | ✅ |
| Dynamic secrets | ✅ | ✅ | ✅ |
| Auto-renewal | ✅ | ✅ | ⚠️ |
| No sidecar | ✅ | ❌ | ✅ |
| CRD-based | ✅ | ❌ | ✅ |
| Works with existing apps | ✅ | ✅ | ⚠️ |

---

## Best Practices

1. **Use VSO** for new deployments - most Kubernetes-native
2. **Use Agent Injector** for legacy apps that read config files
3. **Use CSI** when you need volume-mounted secrets
4. **Short TTLs**: Use 1h or less for tokens
5. **Namespace isolation**: Create separate roles per namespace
6. **Least privilege**: Bind to specific ServiceAccounts
7. **Use secret rotation**: Leverage dynamic secrets
8. **Monitor**: Enable Vault audit logs

---

## Additional Resources

- [VSO Documentation](https://developer.hashicorp.com/vault/docs/platform/k8s/vso)
- [Agent Injector Documentation](https://developer.hashicorp.com/vault/docs/platform/k8s/injector)
- [CSI Provider Documentation](https://developer.hashicorp.com/vault/docs/platform/k8s/csi)
- [Kubernetes Auth Tutorial](https://developer.hashicorp.com/vault/tutorials/kubernetes/kubernetes-sidecar)

---

## Related

- [Auth Methods](auth-methods.md) - Kubernetes authentication configuration
- [Vault Agent](vault-agent.md) - Agent sidecar patterns
- [Troubleshooting](troubleshooting.md) - Kubernetes-specific issues
