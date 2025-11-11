# Vault Skills & Workflows

This directory contains AI agent instructions for secure secrets management, policy creation, and zero-trust security patterns using HashiCorp Vault.

## Directory Structure

```
vault/
├── README.md (this file)
├── skills/
│   ├── generate-policy/        # Create least-privilege ACL policies
│   └── read-secret-securely/   # Secure secret access patterns
├── workflows/
│   └── new-kv-engine-setup.md  # Initialize new KV secrets engine
└── prompts/
    └── system-prompt-vault.md  # AI system prompt for Vault work
```

---

## What's Inside

### Skills

**Skills** are discrete, reusable capabilities that teach AI agents specific Vault tasks.

*** For Claude Desktop (Native SKILL.md Support) ***

  ```bash
  # No setup needed! Claude auto-discovers SKILL.md files
  # Just use natural language:

  "Using the generate-policy skill, create a policy for my web application"

  "Using the read-secret-securely skill, show me how to retrieve database credentials"
  ```

**Why this works**: Claude Desktop natively supports Anthropic's SKILL.md format with progressive disclosure. It automatically finds and loads relevant skills.

#### [generate-policy](skills/generate-policy/)
**Purpose**: Create least-privilege Vault ACL policies with explicit deny rules

**Use when**:
- Creating new application access policies
- Need zero-trust secret access
- Implementing compliance requirements
- Setting up CI/CD authentication

**Example**:
```
@workspace Using vault/skills/generate-policy/, create:

Application: web-app-prod
Authentication: AppRole
Access needed:
  - Read secrets at secret/data/web-app/*
  - Write to database/creds/web-app-role
  - NO access to other apps' secrets
Compliance: SOC2, least-privilege
```

**Key Features**:
- Principle of least privilege by default
- Explicit deny rules for sensitive paths
- Path-based authorization
- Capability-specific permissions (read, write, delete, list, sudo)
- Compliance documentation (SOC2, HIPAA, PCI DSS)

---

#### [read-secret-securely](skills/read-secret-securely/)
**Purpose**: Retrieve secrets from Vault following security best practices

**Use when**:
- Applications need runtime secrets
- CI/CD pipelines require credentials
- Secure database connection strings
- API keys, certificates, tokens

**Example**:
```
@workspace Using vault/skills/read-secret-securely/:

Application: payment-service
Secret path: secret/data/payments/stripe
Authentication: Kubernetes service account
Security:
  - Never log secret values
  - In-memory only (no disk write)
  - Rotate credentials after read
  - Audit all access
```

**Key Features**:
- Multiple authentication methods (AppRole, Kubernetes, JWT, AWS IAM)
- Secure secret handling (no logging, no disk persistence)
- Credential rotation
- Audit trail integration
- Error handling without exposing secrets

---

### Workflows

**Workflows** are multi-step processes that combine multiple skills and tools.

#### [new-kv-engine-setup](workflows/new-kv-engine-setup.md)
**Purpose**: Initialize and configure new Key-Value secrets engine

**Phases**:
1. **Enable Engine**: Mount new KV v2 secrets engine
2. **Configure Settings**: Versioning, max versions, CAS required
3. **Create Policies**: Admin, read-only, write policies
4. **Setup Auth**: Configure authentication methods
5. **Test Access**: Verify permissions
6. **Document**: Create usage guide

**Use when**:
- New application requires secrets storage
- Isolating secrets by team/environment
- Setting up multi-tenant Vault
- Migrating from external secrets manager

**Integration**: Works with HCP Vault, Vault Enterprise, Vault OSS

---

### Prompts

**Prompts** are specialized instructions for specific AI agent scenarios.

#### [system-prompt-vault](prompts/system-prompt-vault.md)
**Purpose**: Define AI agent behavior for Vault security work

**Use when**:
- Starting new AI agent session for Vault
- Need security-first context
- Autonomous secret management
- Policy generation tasks

**Sets expectations for**:
- Zero-trust security model
- Least-privilege access
- Secret handling best practices
- Audit requirements
- Compliance considerations

---

## Quick Start

### For GitHub Copilot Users

**Method 1: Direct reference** (no setup)
```
@workspace Using vault/skills/generate-policy/, create AppRole policy for my app
```

**Method 2: Custom Agent** (specialized)
Create `.github/agents/vault-security.md`:
```markdown
---
name: vault-security
description: Zero-trust secrets management expert
tools: ["read", "edit", "search", "terminal"]
---

Load instructions from vault/skills/generate-policy/SKILL.md
Always apply principle of least privilege...
```

**Method 3: Repository Instructions** (team-wide)
Add to `.github/copilot-instructions.md`:
```markdown
## Vault Standards
Reference vault/skills/generate-policy/ for all policy creation.
Never log secret values in application code.
Always use explicit deny rules for sensitive paths.
```

---

### For Claude Users

**Install as Skills**:
```bash
# Link to Claude's skills directory
mkdir -p ~/.claude/skills
ln -s ~/path/to/vault/skills/generate-policy ~/.claude/skills/vault-generate-policy
ln -s ~/path/to/vault/skills/read-secret-securely ~/.claude/skills/vault-read-secret
```

**Usage**:
```
Using the vault-generate-policy skill, create a policy for my payment service
```

Claude will apply zero-trust patterns automatically.

---

### For VS Code / JetBrains Users

**Create Prompt File**: `.github/prompts/vault-policy.prompt.md`
```markdown
Generate Vault policy following zero-trust principles:

1. Load: #file:../../agent-instructions-library-man/vault/skills/generate-policy/SKILL.md
2. Apply least privilege
3. Add explicit deny rules
4. Document access rationale
```

**Usage**: Attach prompt in Copilot Chat

---

### For AGENTS.md Compatible Tools (Cursor, Jules, Gemini CLI)

**Add to AGENTS.md**:
```markdown
## Vault Security Standards

### Policy Generation
Use: agent-instructions-library-man/vault/skills/generate-policy/

Always:
- Apply principle of least privilege
- Use explicit deny for sensitive paths
- Document all capabilities granted
- Include compliance notes (SOC2, HIPAA)

### Secret Access
Use: agent-instructions-library-man/vault/skills/read-secret-securely/

Never:
- Log secret values to stdout/stderr
- Write secrets to disk (temp files, logs)
- Store secrets in environment variables (prefer runtime fetch)
- Use root token in production
```

---

## Learning Path

### Beginners
1. Start with **generate-policy** skill
2. Study least-privilege access patterns
3. Review authentication methods (AppRole, Kubernetes)
4. Practice with KV secrets engine

### Intermediate
1. Use **read-secret-securely** in applications
2. Practice **new-kv-engine-setup** workflow
3. Learn dynamic secrets (databases, cloud providers)
4. Study policy templating

### Advanced
1. Implement multi-tenant Vault architectures
2. Create custom authentication backends
3. Build automated secret rotation
4. Integrate with CI/CD pipelines

---

## Common Use Cases

### Use Case 1: Create Application Policy
```
@workspace Using vault/skills/generate-policy/, create:

Application: web-api-prod
Authentication: AppRole
Access requirements:
  - Read: secret/data/web-api/database (DB credentials)
  - Read: secret/data/web-api/api-keys (3rd party API keys)
  - Write: secret/metadata/web-api/* (update secret metadata only)
  - NO access to: secret/data/other-apps/*
  - NO sudo capabilities
Compliance: SOC2 Type 2
```

**Generated Policy**:
```hcl
# Policy: web-api-prod-policy
# Purpose: Least-privilege access for web-api production application
# Compliance: SOC2 Type 2 - Principle of Least Privilege

# Allow reading database credentials
path "secret/data/web-api/database" {
  capabilities = ["read"]
}

# Allow reading API keys
path "secret/data/web-api/api-keys" {
  capabilities = ["read"]
}

# Allow updating metadata (versioning, custom metadata)
path "secret/metadata/web-api/*" {
  capabilities = ["update"]
}

# Explicit deny for other applications' secrets
path "secret/data/other-apps/*" {
  capabilities = ["deny"]
}

# Explicit deny for sensitive admin paths
path "sys/policies/*" {
  capabilities = ["deny"]
}

path "auth/token/create" {
  capabilities = ["deny"]
}

path "sys/mounts/*" {
  capabilities = ["deny"]
}
```

---

### Use Case 2: Secure Secret Reading in App
```
@workspace Using vault/skills/read-secret-securely/:

Language: Python
Application: payment-processor
Secret path: secret/data/payments/stripe
Authentication: Kubernetes service account
Security:
  - Never print secret values
  - In-memory only
  - Rotate after reading
  - Audit all reads
```

**Generated Code**:
```python
import hvac
import logging

# Configure logging to NEVER log secrets
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class SecureVaultClient:
    def __init__(self, vault_addr: str, role: str):
        self.vault_addr = vault_addr
        self.role = role
        self.client = None
        
    def authenticate_kubernetes(self, jwt_path: str = '/var/run/secrets/kubernetes.io/serviceaccount/token'):
        """Authenticate using Kubernetes service account"""
        try:
            with open(jwt_path, 'r') as f:
                jwt = f.read()
            
            self.client = hvac.Client(url=self.vault_addr)
            self.client.auth.kubernetes.login(
                role=self.role,
                jwt=jwt
            )
            logger.info("Successfully authenticated to Vault")
            
        except Exception as e:
            logger.error(f"Vault authentication failed: {type(e).__name__}")
            raise
    
    def read_secret_secure(self, secret_path: str) -> dict:
        """
        Read secret from Vault following security best practices
        
        Security measures:
        - Never logs secret values
        - Returns in-memory only (no disk write)
        - Audit trail via Vault
        - Errors don't expose secret content
        """
        try:
            if not self.client or not self.client.is_authenticated():
                raise ValueError("Client not authenticated")
            
            # Read secret (Vault KV v2)
            response = self.client.secrets.kv.v2.read_secret_version(
                path=secret_path.replace('secret/data/', '')
            )
            
            # Extract data without logging
            secret_data = response['data']['data']
            
            logger.info(f"Successfully read secret from: {secret_path}")
            # DO NOT LOG: logger.debug(f"Secret content: {secret_data}")
            
            return secret_data
            
        except hvac.exceptions.Forbidden:
            logger.error(f"Access denied to secret: {secret_path}")
            raise
        except hvac.exceptions.InvalidPath:
            logger.error(f"Secret not found: {secret_path}")
            raise
        except Exception as e:
            # Generic error - don't expose secret details
            logger.error(f"Failed to read secret: {type(e).__name__}")
            raise

# Usage
vault_client = SecureVaultClient(
    vault_addr='https://vault.example.com:8200',
    role='payment-processor'
)

vault_client.authenticate_kubernetes()

# Read secret (in-memory only)
stripe_credentials = vault_client.read_secret_secure('secret/data/payments/stripe')

# Use secret (never log it)
stripe_api_key = stripe_credentials['api_key']

# Secret only exists in memory, never written to disk
```

---

### Use Case 3: Setup New KV Engine for Team
```
@workspace Apply vault/workflows/new-kv-engine-setup.md:

Team: data-science
Engine path: ds-secrets
Configuration:
  - KV version: 2
  - Max versions: 10
  - CAS required: true
Policies needed:
  - ds-admin (full access)
  - ds-read (read-only)
  - ds-app (specific paths only)
Authentication: JWT from CI/CD
```

---

### Use Case 4: Multi-Environment Secrets Strategy
```
@workspace Using vault/skills/generate-policy/:

Setup policies for 3 environments:
  - dev: relaxed (developers can read/write)
  - staging: moderate (CI/CD read/write, humans read-only)
  - prod: strict (CI/CD read, humans break-glass only)

Application: api-gateway
Secrets:
  - Database credentials
  - API keys (3rd party)
  - TLS certificates
```

---

## Security Principles

All Vault skills follow zero-trust security principles:

**Always**:
- Apply principle of least privilege
- Use explicit deny rules for sensitive paths
- Authenticate with short-lived tokens
- Rotate credentials regularly
- Audit all secret access
- Encrypt secrets in transit (TLS)
- Never log secret values
- Use namespaces for multi-tenancy (Vault Enterprise)
- Implement break-glass procedures
- Document access rationale

**Never**:
- Use root token in production
- Store secrets in environment variables (fetch at runtime)
- Log secret values to stdout/stderr/files
- Write secrets to disk (temp files, caches)
- Grant wildcard permissions (`*`) without explicit deny
- Allow `sudo` capability without justification
- Share policies across trust boundaries
- Hard-code Vault tokens in code
- Skip authentication verification

---

## Integration Examples

### GitHub Actions with Vault

```yaml
name: Deploy with Vault Secrets

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    permissions:
      id-token: write
      contents: read
    
    steps:
      - uses: actions/checkout@v4
      
      - name: Import Secrets from Vault
        uses: hashicorp/vault-action@v3
        with:
          url: https://vault.example.com:8200
          method: jwt
          role: github-actions-deploy
          secrets: |
            secret/data/app/database username | DB_USER ;
            secret/data/app/database password | DB_PASS ;
            secret/data/app/api-keys stripe | STRIPE_KEY
      
      - name: Deploy Application
        env:
          # Secrets injected as env vars (use sparingly)
          DATABASE_URL: "postgresql://${{ env.DB_USER }}:${{ env.DB_PASS }}@db.example.com/prod"
        run: |
          # Secrets only exist during job execution
          ./deploy.sh
      
      # Secrets automatically cleared after job
```

### Kubernetes with Vault

```yaml
# ServiceAccount for Vault authentication
apiVersion: v1
kind: ServiceAccount
metadata:
  name: web-app
  namespace: production
---
# Pod with Vault Agent Injector
apiVersion: v1
kind: Pod
metadata:
  name: web-app
  namespace: production
  annotations:
    vault.hashicorp.com/agent-inject: "true"
    vault.hashicorp.com/role: "web-app-prod"
    vault.hashicorp.com/agent-inject-secret-database: "secret/data/web-app/database"
    vault.hashicorp.com/agent-inject-template-database: |
      {{- with secret "secret/data/web-app/database" -}}
      export DB_USER="{{ .Data.data.username }}"
      export DB_PASS="{{ .Data.data.password }}"
      {{- end -}}
spec:
  serviceAccountName: web-app
  containers:
    - name: app
      image: web-app:latest
      command:
        - "/bin/sh"
        - "-c"
        - |
          # Source secrets from Vault Agent
          source /vault/secrets/database
          
          # Secrets in memory only
          ./start-app.sh
```

### Terraform with Vault Provider

```hcl
# Reference: vault/skills/generate-policy/

terraform {
  required_providers {
    vault = {
      source  = "hashicorp/vault"
      version = "~> 4.0"
    }
  }
}

provider "vault" {
  address = "https://vault.example.com:8200"
  # Authentication via VAULT_TOKEN environment variable
}

# Create application policy
resource "vault_policy" "web_app_prod" {
  name = "web-app-prod-policy"

  policy = <<EOT
# Least-privilege policy for web-app production
path "secret/data/web-app/*" {
  capabilities = ["read"]
}

# Explicit deny for other apps
path "secret/data/other-apps/*" {
  capabilities = ["deny"]
}

# Deny admin operations
path "sys/*" {
  capabilities = ["deny"]
}
EOT
}

# Setup AppRole authentication
resource "vault_auth_backend" "approle" {
  type = "approle"
}

resource "vault_approle_auth_backend_role" "web_app" {
  backend         = vault_auth_backend.approle.path
  role_name       = "web-app-prod"
  token_policies  = [vault_policy.web_app_prod.name]
  token_ttl       = 3600  # 1 hour
  token_max_ttl   = 7200  # 2 hours
  secret_id_ttl   = 86400 # 24 hours
}
```

---

## Additional Resources

### Within This Repository
- [Policy Examples](skills/generate-policy/resources/policy-examples.hcl)
- [Main README](../README.md) - Platform integration guides

### Official Documentation
- [Vault Documentation](https://www.vaultproject.io/docs)
- [HCP Vault](https://developer.hashicorp.com/vault/docs/platform/hcp)
- [Vault Policies](https://developer.hashicorp.com/vault/docs/concepts/policies)
- [Auth Methods](https://developer.hashicorp.com/vault/docs/auth)

### Security Resources
- [NIST Zero Trust Architecture](https://nvlpubs.nist.gov/nistpubs/SpecialPublications/NIST.SP.800-207.pdf)
- [CIS Vault Benchmark](https://www.cisecurity.org/benchmark/hashicorp_vault)
- [SOC2 Compliance Guide](https://www.vaultproject.io/docs/platform/soc2)

---

## Tips for AI Agents

When using these instructions:

1. **Always read the full SKILL.md** before generating policies
2. **Start with least privilege**: Grant minimum necessary access
3. **Add explicit deny rules**: For paths outside scope
4. **Never log secrets**: Not even in debug mode
5. **Use specific capabilities**: Avoid wildcard grants
6. **Include audit context**: Document why access is needed
7. **Test policies**: Verify with `vault policy read` before apply
8. **Rotate credentials**: After any potential exposure
