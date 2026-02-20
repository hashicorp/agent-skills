---
name: kubernetes-integration
description: Integrate Vault with Kubernetes. Use when asked about Vault Secrets Operator (VSO), Agent Injector, CSI Provider, Kubernetes auth, syncing secrets to Kubernetes, or pod-level secret injection patterns.
---

# Vault Kubernetes Integration

## What Are You Trying to Solve?

### "I want Vault secrets synced to Kubernetes Secrets"
→ Use **Vault Secrets Operator (VSO)**—recommended for new apps. [Jump to VSO](#vault-secrets-operator-vso---recommended)

### "I need secrets injected without changing my app code"
→ Use **Agent Injector** with pod annotations. [Jump to Agent Injector](#agent-injector)

### "Kubernetes Secrets are not acceptable for security reasons"
→ Use **CSI Provider** for ephemeral volume mounts. [Jump to CSI Provider](#csi-provider)

### "I'm not sure which integration to use"
→ See the [comparison table](#method-comparison) below.

---

## How Kubernetes Integration Works

1. **Configure Kubernetes Auth** → Vault trusts your cluster's service accounts
2. **Deploy Integration** → Install VSO, Agent Injector, or CSI Provider
3. **Create Resources** → Define which secrets your pods need
4. **Pods Consume Secrets** → Secrets appear as K8s Secrets, files, or volumes

---

## Method Comparison

| Decision Factor | VSO | Agent Injector | CSI Provider |
|-----------------|-----|----------------|--------------|
| **Secret storage** | K8s Secret | In-memory files | Ephemeral volume |
| **Auto-rotation** | ✅ Yes | ✅ Yes | ❌ Needs restart |
| **Complexity** | Low | Medium | Low |
| **Pod overhead** | None (controller) | Sidecar per pod | DaemonSet |
| **Best for** | K8s-native apps | Legacy apps, templating | Security-first orgs |

**Quick decision:**
- **New apps** → VSO
- **Existing apps that read files** → Agent Injector
- **Can't use K8s Secrets** → CSI Provider

---

## Reference

- [Vault Kubernetes Documentation](https://developer.hashicorp.com/vault/docs/platform/k8s)
- [Detailed Kubernetes Reference](references/kubernetes.md)

---

## Vault Secrets Operator (VSO) - Recommended

VSO syncs Vault secrets to native Kubernetes Secrets.

### Installation

```bash
helm repo add hashicorp https://helm.releases.hashicorp.com
helm install vault-secrets-operator hashicorp/vault-secrets-operator \
    --namespace vault-secrets-operator-system \
    --create-namespace
```

### Configure Authentication

```yaml
apiVersion: secrets.hashicorp.com/v1beta1
kind: VaultAuth
metadata:
  name: vault-auth
spec:
  method: kubernetes
  mount: kubernetes
  kubernetes:
    role: my-app
    serviceAccount: my-app-sa
  vaultConnectionRef: vault-connection
```

### Sync Static Secrets

```yaml
apiVersion: secrets.hashicorp.com/v1beta1
kind: VaultStaticSecret
metadata:
  name: my-app-secrets
spec:
  vaultAuthRef: vault-auth
  mount: secret
  path: myapp/config
  type: kv-v2
  refreshAfter: 60s
  destination:
    name: my-app-secret
    create: true
```

### Sync Dynamic Secrets

```yaml
apiVersion: secrets.hashicorp.com/v1beta1
kind: VaultDynamicSecret
metadata:
  name: db-creds
spec:
  vaultAuthRef: vault-auth
  mount: database
  path: creds/readonly
  destination:
    name: db-credentials
    create: true
  renewalPercent: 67
```

---

## Agent Injector

Injects secrets via sidecar container using annotations.

### Installation

```bash
helm install vault hashicorp/vault \
    --set "injector.enabled=true" \
    --set "server.enabled=false"
```

### Pod Annotations

```yaml
apiVersion: v1
kind: Pod
metadata:
  annotations:
    vault.hashicorp.com/agent-inject: "true"
    vault.hashicorp.com/role: "my-app"
    vault.hashicorp.com/agent-inject-secret-config.txt: "secret/data/myapp/config"
spec:
  serviceAccountName: my-app-sa
  containers:
    - name: app
      image: myapp:latest
      volumeMounts:
        - name: vault-secrets
          mountPath: /vault/secrets
          readOnly: true
```

### Template Annotations

```yaml
annotations:
  vault.hashicorp.com/agent-inject: "true"
  vault.hashicorp.com/role: "my-app"
  vault.hashicorp.com/agent-inject-secret-config.txt: "secret/data/myapp/config"
  vault.hashicorp.com/agent-inject-template-config.txt: |
    {{- with secret "secret/data/myapp/config" -}}
    DB_HOST={{ .Data.data.host }}
    DB_USER={{ .Data.data.username }}
    DB_PASS={{ .Data.data.password }}
    {{- end }}
```

---

## CSI Provider

Mounts secrets as ephemeral volumes.

### SecretProviderClass

```yaml
apiVersion: secrets-store.csi.x-k8s.io/v1
kind: SecretProviderClass
metadata:
  name: vault-db-creds
spec:
  provider: vault
  parameters:
    vaultAddress: "https://vault.example.com:8200"
    roleName: "my-app"
    objects: |
      - objectName: "db-password"
        secretPath: "secret/data/myapp/db"
        secretKey: "password"
```

### Pod Usage

```yaml
spec:
  containers:
    - name: app
      volumeMounts:
        - name: secrets-store
          mountPath: "/mnt/secrets"
          readOnly: true
  volumes:
    - name: secrets-store
      csi:
        driver: secrets-store.csi.k8s.io
        readOnly: true
        volumeAttributes:
          secretProviderClass: vault-db-creds
```

---

## Best Practices

- **Use VSO** for new Kubernetes-native applications
- **Use Agent Injector** for legacy apps or complex templating
- **Use CSI Provider** when K8s Secrets are not acceptable
- **Enable Kubernetes auth** in Vault for all methods
- **Use separate service accounts** per application role

---

For complete configurations including RBAC setup, multi-cluster patterns, and troubleshooting, see [references/kubernetes.md](references/kubernetes.md).
