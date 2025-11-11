# Vault Radar Skills & Workflows

This directory contains AI agent instructions for detecting, triaging, and remediating secrets exposure using HashiCorp Vault Radar with Model Context Protocol (MCP) integration.

## Directory Structure

```
vault-radar/
├── README.md (this file)
├── skills/
│   ├── scan-for-secrets/         # Detect secrets in code/repos/platforms
│   └── integrate-mcp-server/     # AI-powered analysis with MCP
├── workflows/
│   └── triage-and-remediate.md   # Complete remediation process
└── prompts/
    ├── system-prompt.md          # AI agent behavior for Vault Radar
    └── analyze-scan-results.md   # Interpret scan findings
```

---

## What's Inside

### Skills

**Skills** are discrete, reusable capabilities that teach AI agents specific Vault Radar tasks.

*** For Claude Desktop (Native SKILL.md Support) ***

  ```bash
  # No setup needed! Claude auto-discovers SKILL.md files
  # Just use natural language:

  "Using the scan-for-secrets skill, analyze my repository for exposed credentials"

  "Using the integrate-mcp-server skill, set up Vault Radar MCP integration"
  ```

**Why this works**: Claude Desktop natively supports Anthropic's SKILL.md format with progressive disclosure. It automatically finds and loads relevant skills.

#### [scan-for-secrets](skills/scan-for-secrets/)
**Purpose**: Detect hardcoded secrets, API keys, credentials in code repositories and platforms

**Use when**:
- Auditing codebase for secret leaks
- Pre-commit validation
- CI/CD security checks
- Compliance audits (SOC2, PCI DSS)
- Incident response

**Example**:
```
@workspace Using vault-radar/skills/scan-for-secrets/, run:

Target: ./src/
Scan type: Offline (git repository)
Depth: Full history + uncommitted changes
Severity: HIGH and CRITICAL only
Output: JSON for MCP analysis
```
---

#### [integrate-mcp-server](skills/integrate-mcp-server/)
**Purpose**: Connect Vault Radar with AI agents via Model Context Protocol for intelligent analysis

**Use when**:
- Need AI-powered triage of scan results
- Automating remediation workflows
- Generating fix recommendations
- Prioritizing findings by business impact
- Creating executive summaries

**Example**:
```
@workspace Using vault-radar/skills/integrate-mcp-server/:

Setup: Claude Desktop with Vault Radar MCP
Purpose: Analyze scan results from prod-api repo
Actions needed:
  - Triage severity levels
  - Generate remediation plan
  - Identify rotation requirements
  - Suggest Vault migration paths
```
---

### Workflows

**Workflows** are multi-step processes that combine multiple skills and tools.

#### [triage-and-remediate](workflows/triage-and-remediate.md)
**Purpose**: Complete 6-phase process from detection to prevention

**Phases**:
1. **Scan**: Run Vault Radar across all targets
2. **Triage**: Categorize by severity and impact
3. **Contain**: Immediately rotate CRITICAL/HIGH findings
4. **Remediate**: Remove secrets from code + git history
5. **Migrate**: Move to Vault secrets management
6. **Prevent**: Implement pre-commit hooks, CI/CD gates

**Use when**:
- Secrets detected in production code
- Security incident response
- Compliance audit preparation
- Migrating to Vault from hardcoded secrets
- Implementing secrets management strategy

---

### Prompts

**Prompts** are specialized instructions for specific AI agent scenarios.

#### [system-prompt-vault-radar](prompts/system-prompt-vault-radar.md)
**Purpose**: Define AI agent behavior for Vault Radar security work

**Use when**:
- Starting AI agent for secrets scanning
- Need security-first context
- Autonomous triage and remediation
- Compliance-driven analysis

**Sets expectations for**:
- Severity-based prioritization
- Progressive disclosure of secrets
- Complete remediation (not just rotation)
- Prevention-first mindset
- Audit trail requirements

---

#### [analyze-scan-results](prompts/analyze-scan-results.md)
**Purpose**: Interpret Vault Radar scan output and generate action plans

**Use when**:
- Processing scan JSON output
- Creating remediation roadmaps
- Generating executive summaries
- Prioritizing by business impact
- Assigning remediation tasks

**Output includes**:
- Severity breakdown (counts + examples)
- High-impact findings highlighted
- Remediation effort estimates
- Risk assessment
- Compliance implications

---

## Quick Start

### For GitHub Copilot Users

**Method 1: Direct reference** (no setup)
```
@workspace Using vault-radar/skills/scan-for-secrets/, scan ./backend/ for secrets
```

**Method 2: Custom Agent** (specialized)
Create `.github/agents/security-scanner.md`:
```markdown
---
name: security-scanner
description: Secrets detection and remediation expert
tools: ["read", "edit", "search", "terminal"]
---

Load instructions from vault-radar/skills/scan-for-secrets/SKILL.md
Prioritize CRITICAL and HIGH severity findings...
```

**Method 3: Repository Instructions** (team-wide)
Add to `.github/copilot-instructions.md`:
```markdown
## Vault Radar Standards
Run vault-radar/skills/scan-for-secrets/ before every PR merge.
CRITICAL findings must be resolved within 1 hour.
Never commit API keys, tokens, or credentials.
```

---

### For Claude Users with MCP

**Install Vault Radar MCP Server**:
```bash
# Configure in Claude Desktop config.json
{
    "mcpServers": {
        "vault-radar": {
            "command": "docker",
            "args": [
                    "run",
                    "--rm",
                    "-i",
                    "-e", "HCP_PROJECT_ID=<HCP Project ID>",
                    "-e", "HCP_CLIENT_ID=<HCP Service Principal Client ID>",
                    "-e", "HCP_CLIENT_SECRET=<HCP Service Principal Client Secret>",
                    "hashicorp/vault-radar-mcp-server:<tag>",
            ]
        }
    }
}
```

**Usage**:
```
Scan my repository for secrets and triage by severity
```

Claude will use MCP to:
1. Run Vault Radar scan
2. Retrieve results progressively
3. Analyze severity and impact
4. Generate remediation plan

---

### For VS Code / JetBrains Users

**Create Prompt File**: `.github/prompts/scan-secrets.prompt.md`
```markdown
Scan repository for hardcoded secrets:

1. Load: #file:../../agent-instructions-library-man/vault-radar/skills/scan-for-secrets/SKILL.md
2. Run: vault-radar scan --format json
3. Triage: Prioritize CRITICAL and HIGH
4. Remediate: Follow triage-and-remediate workflow
```

**Usage**: Attach prompt in Copilot Chat

---

### For AGENTS.md Compatible Tools (Cursor, Jules, Gemini CLI)

**Add to AGENTS.md**:
```markdown
## Vault Radar Security

### Secret Scanning
Use: agent-instructions-library-man/vault-radar/skills/scan-for-secrets/

Scan targets:
- Pre-commit: Staged files only
- PR validation: Changed files + context
- Full audit: Entire repo + git history

### Severity Response Times
- CRITICAL: Rotate within 1 hour
- HIGH: Rotate within 24 hours
- MEDIUM: Remediate within 7 days
- LOW: Address in next sprint

### Remediation Steps
1. Rotate immediately (don't just delete)
2. Scrub git history (BFG Repo-Cleaner)
3. Migrate to Vault (appropriate engine)
4. Add prevention (pre-commit hook)
```

---

## Common Use Cases

### Use Case 1: Pre-Commit Secret Scan
```
@workspace Using vault-radar/skills/scan-for-secrets/:

Scan: Git staged files only
Mode: Offline (local)
Severity: All levels
Action: Block commit if CRITICAL or HIGH found
Output: Terminal (human-readable)
```

**Pre-commit Hook**:
```bash
#!/bin/bash
# .git/hooks/pre-commit

echo "Scanning for secrets..."

# Scan staged files
vault-radar scan \
  --target git-staged \
  --format json \
  --output scan-results.json

# Check for CRITICAL or HIGH severity
CRITICAL_COUNT=$(jq '[.results[] | select(.severity == "CRITICAL")] | length' scan-results.json)
HIGH_COUNT=$(jq '[.results[] | select(.severity == "HIGH")] | length' scan-results.json)

if [ "$CRITICAL_COUNT" -gt 0 ] || [ "$HIGH_COUNT" -gt 0 ]; then
  echo "BLOCKED: Secrets detected in commit"
  echo "  CRITICAL: $CRITICAL_COUNT"
  echo "  HIGH: $HIGH_COUNT"
  echo ""
  echo "Run: vault-radar scan --target git-staged"
  exit 1
fi

echo "No secrets detected"
exit 0
```

---

### Use Case 2: Full Repository Audit with MCP
```
@workspace Using vault-radar/skills/integrate-mcp-server/:

Action: Complete security audit
Target: Production API repository
MCP Server: Vault Radar
Analysis needed:
  1. Scan entire repo including git history
  2. Triage by severity (CRITICAL → LOW)
  3. Identify which secrets are still valid
  4. Generate rotation plan
  5. Suggest Vault migration strategy
  6. Create prevention roadmap
```

**Claude (with MCP) Conversation**:
```
User: Scan production-api repo for secrets

Claude: I'll use Vault Radar MCP to scan. Running now...
[MCP: vault-radar scan-repo production-api]

Results summary:
  CRITICAL: 3 findings
    - AWS access key (still active, last used 2 days ago)
    - Database password (admin account, prod DB)
    - Stripe secret key (live mode, payment processing)
  
  HIGH: 7 findings
    - GitHub personal access tokens (2)
    - API keys for 3rd party services (5)
  
  MEDIUM: 12 findings
  LOW: 45 findings

Immediate actions required:

1. CRITICAL - Rotate within 1 hour:
   a) AWS: Create new IAM user, update app config, revoke old
   b) Database: ALTER USER password, update connection strings
   c) Stripe: Generate new secret key in dashboard, deploy update

2. Remediation plan:
   - Scrub git history (BFG Repo-Cleaner)
   - Migrate to Vault (dynamic secrets for DB, KV for API keys)
   - Implement pre-commit hooks
   - Add CI/CD scanning

Would you like me to generate rotation scripts?
```

---

## Integration Examples

### Pre-commit Hook (Advanced)

```bash
#!/bin/bash
# .git/hooks/pre-commit
# Reference: vault-radar/skills/scan-for-secrets/

set -e

echo "Vault Radar: Scanning staged files..."

# Create temp file for results
RESULTS_FILE=$(mktemp)

# Scan staged files
vault-radar scan \
  --target git-staged \
  --format json \
  --output "$RESULTS_FILE" \
  2>/dev/null || true

# Parse results by severity
CRITICAL=$(jq -r '[.results[] | select(.severity == "CRITICAL")] | length' "$RESULTS_FILE")
HIGH=$(jq -r '[.results[] | select(.severity == "HIGH")] | length' "$RESULTS_FILE")
MEDIUM=$(jq -r '[.results[] | select(.severity == "MEDIUM")] | length' "$RESULTS_FILE")

# Cleanup
rm -f "$RESULTS_FILE"

# Decision logic
if [ "$CRITICAL" -gt 0 ]; then
  echo "BLOCKED: $CRITICAL CRITICAL secrets detected"
  echo ""
  echo "CRITICAL findings must be resolved before commit."
  echo "Run: vault-radar scan --target git-staged"
  exit 1
fi

if [ "$HIGH" -gt 0 ]; then
  echo " WARNING: $HIGH HIGH severity secrets detected"
  echo ""
  echo "HIGH findings should be resolved before commit."
  echo "Run: vault-radar scan --target git-staged"
  echo ""
  read -p "Override and commit anyway? (yes/no): " OVERRIDE
  if [ "$OVERRIDE" != "yes" ]; then
    exit 1
  fi
fi

if [ "$MEDIUM" -gt 0 ]; then
  echo "INFO: $MEDIUM MEDIUM severity findings (not blocking)"
fi

echo "Vault Radar: Scan complete"
exit 0
```
---

### MCP Server Configuration (VS Code)
```json
{
    "mcp": {
        "servers": {
            "vault-radar": {
                "command": "docker",
                "args": [
                    "run",
                    "--rm",
                    "-i",
                    "-e", "HCP_PROJECT_ID=<HCP Project ID>",
                    "-e", "HCP_CLIENT_ID=<HCP Service Principal Client ID>",
                    "-e", "HCP_CLIENT_SECRET=<HCP Service Principal Client Secret>",
                    "hashicorp/vault-radar-mcp-server:<tag>",
                ]
            }
        }
    }
}

```

**Available MCP Tools**:
- `query_vault_radar_data_sources`: Queries all data sources available in the Vault Radar project.
- `query_vault_radar_resources`: Queries all resources in your HCP Vault Radar project.
- `query_vault_radar_events`: Queries all the events in your HCP Vault Radar project.
- `list_vault_radar_secret_types`: Lists the detected secret types in your HCP Vault Radar project.

---

## Documentation
- [Vault Radar Documentation](https://developer.hashicorp.com/vault/docs/radar)
- [Vault Radar MCP Server](https://developer.hashicorp.com/hcp/docs/vault-radar/mcp-server/overview)
- [Model Context Protocol Spec](https://spec.modelcontextprotocol.io/)
- [HCP Vault Radar](https://developer.hashicorp.com/hcp/docs/vault-radar)
