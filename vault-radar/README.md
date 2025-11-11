# Vault Radar Skills & Workflows

This directory contains AI agent instructions for detecting, triaging, and remediating secrets exposure using HashiCorp Vault Radar with Model Context Protocol (MCP) integration.

## 📁 Directory Structure

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

## 🎯 What's Inside

### Skills

### For Claude Desktop (Native SKILL.md Support)
```bash
# No setup needed! Claude auto-discovers SKILL.md files
# Just use natural language:

"Using the scan-for-secrets skill, analyze my repository for exposed credentials"

"Using the integrate-mcp-server skill, set up Vault Radar MCP integration"
```

**Why this works**: Claude Desktop natively supports Anthropic's SKILL.md format with progressive disclosure. It automatically finds and loads relevant skills.

**Skills** are discrete, reusable capabilities that teach AI agents specific Vault Radar tasks.

#### 🔍 [scan-for-secrets](skills/scan-for-secrets/)
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

**Key Features**:
- **Online scanning**: GitHub, GitLab, Confluence, Jira, Slack
- **Offline scanning**: Local git repos, file systems, CI/CD artifacts
- **Severity levels**: CRITICAL (< 1hr), HIGH (< 24hr), MEDIUM (< 7d), LOW (backlog)
- **Pattern detection**: AWS keys, API tokens, private keys, database URLs, certificates
- **Git history**: Full commit history scanning
- **False positive filtering**: Context-aware analysis

---

#### 🤖 [integrate-mcp-server](skills/integrate-mcp-server/)
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

**Key Features**:
- **Progressive disclosure**: Reveal secret details only when explicitly requested
- **Severity-based prioritization**: CRITICAL → HIGH → MEDIUM → LOW
- **Remediation automation**: Generate rotation scripts, migration plans
- **Integration with Vault**: Suggest appropriate secret engines
- **Compliance mapping**: Link findings to SOC2, HIPAA, PCI DSS requirements

---

### Workflows

**Workflows** are multi-step processes that combine multiple skills and tools.

#### 🚨 [triage-and-remediate](workflows/triage-and-remediate.md)
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

**Time to Resolution**:
- CRITICAL: < 1 hour
- HIGH: < 24 hours
- MEDIUM: < 7 days
- LOW: Next sprint

---

### Prompts

**Prompts** are specialized instructions for specific AI agent scenarios.

#### 🤖 [system-prompt-vault-radar](prompts/system-prompt-vault-radar.md)
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

#### 📊 [analyze-scan-results](prompts/analyze-scan-results.md)
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

## 🚀 Quick Start

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
# Install via npm
npm install -g @hashicorp/vault-radar-mcp

# Configure in Claude Desktop config.json
{
  "mcpServers": {
    "vault-radar": {
      "command": "vault-radar-mcp",
      "args": ["--token", "${VAULT_RADAR_TOKEN}"],
      "env": {
        "VAULT_RADAR_TOKEN": "your-token-here"
      }
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

## 🎓 Learning Path

### Beginners
1. Start with **scan-for-secrets** skill (offline mode)
2. Understand severity levels and response times
3. Learn common secret patterns (AWS keys, tokens)
4. Practice with test repositories

### Intermediate
1. Use **integrate-mcp-server** for AI-powered analysis
2. Practice **triage-and-remediate** workflow
3. Implement pre-commit hooks
4. Set up CI/CD scanning

### Advanced
1. Build custom detection patterns
2. Integrate with SIEM/SOAR platforms
3. Automate complete remediation pipeline
4. Implement organization-wide scanning strategy

---

## 🔧 Common Use Cases

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

echo "🔍 Scanning for secrets..."

# Scan staged files
vault-radar scan \
  --target git-staged \
  --format json \
  --output scan-results.json

# Check for CRITICAL or HIGH severity
CRITICAL_COUNT=$(jq '[.results[] | select(.severity == "CRITICAL")] | length' scan-results.json)
HIGH_COUNT=$(jq '[.results[] | select(.severity == "HIGH")] | length' scan-results.json)

if [ "$CRITICAL_COUNT" -gt 0 ] || [ "$HIGH_COUNT" -gt 0 ]; then
  echo "❌ BLOCKED: Secrets detected in commit"
  echo "  CRITICAL: $CRITICAL_COUNT"
  echo "  HIGH: $HIGH_COUNT"
  echo ""
  echo "Run: vault-radar scan --target git-staged"
  exit 1
fi

echo "✅ No secrets detected"
exit 0
```

---

### Use Case 2: CI/CD Pipeline Scan
```
@workspace Using vault-radar/skills/scan-for-secrets/:

Scan: Changed files in PR + 10 lines context
Mode: Offline (CI runner)
Severity: CRITICAL and HIGH fail build
Output: SARIF for GitHub Code Scanning
Integration: Post results to PR comment
```

**GitHub Actions Workflow**:
```yaml
name: Vault Radar Secrets Scan

on:
  pull_request:
    branches: [main, develop]

jobs:
  scan:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      pull-requests: write
      security-events: write
    
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0  # Full history for context
      
      - name: Install Vault Radar
        run: |
          curl -fsSL https://releases.hashicorp.com/vault-radar/0.5.0/vault-radar_0.5.0_linux_amd64.zip -o vr.zip
          unzip vr.zip
          chmod +x vault-radar
          sudo mv vault-radar /usr/local/bin/
      
      - name: Scan for Secrets
        env:
          VAULT_RADAR_TOKEN: ${{ secrets.VAULT_RADAR_TOKEN }}
        run: |
          vault-radar scan \
            --target . \
            --format sarif \
            --output results.sarif
      
      - name: Upload SARIF to GitHub
        uses: github/codeql-action/upload-sarif@v3
        with:
          sarif_file: results.sarif
      
      - name: Check for CRITICAL/HIGH
        run: |
          CRITICAL=$(jq '.runs[0].results | map(select(.level == "error")) | length' results.sarif)
          HIGH=$(jq '.runs[0].results | map(select(.level == "warning")) | length' results.sarif)
          
          if [ "$CRITICAL" -gt 0 ]; then
            echo "❌ $CRITICAL CRITICAL secrets detected"
            exit 1
          fi
          
          if [ "$HIGH" -gt 0 ]; then
            echo "⚠️  $HIGH HIGH severity secrets detected"
            exit 1
          fi
          
          echo "✅ No CRITICAL or HIGH secrets detected"
```

---

### Use Case 3: Full Repository Audit with MCP
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

### Use Case 4: Incident Response - Secret Exposed in Public Repo
```
@workspace Apply vault-radar/workflows/triage-and-remediate.md:

Incident: AWS keys committed to public GitHub repo
Discovered: 30 minutes ago
Exposure: Public for 2 hours
Repository: company/web-app (public)
Severity: CRITICAL

Execute 6-phase workflow:
1. Scan - Confirm exposure
2. Triage - CRITICAL (public repo)
3. Contain - Rotate AWS keys IMMEDIATELY
4. Remediate - Remove from code + scrub git history
5. Migrate - Move to Vault dynamic AWS secrets
6. Prevent - Pre-commit hooks + CI/CD gates
```

**Incident Response Timeline**:
```
T+0 min:  Secret detected in public repo
T+5 min:  CRITICAL triage confirmed
T+10 min: AWS keys rotated (emergency procedure)
T+15 min: Verify old keys are revoked
T+30 min: Git history scrubbed (BFG Repo-Cleaner)
T+45 min: New keys in Vault (dynamic AWS engine)
T+60 min: Pre-commit hook deployed
T+90 min: Incident report completed
```

---

## 🛡️ Security Principles

All Vault Radar skills follow these security-first principles:

✅ **Always**:
- Scan before commit (pre-commit hooks)
- Scan in CI/CD (block on CRITICAL/HIGH)
- Rotate immediately on detection (don't just delete)
- Scrub git history (secrets persist in commits)
- Migrate to Vault (centralized secrets management)
- Implement prevention (layered security)
- Audit all secret access (compliance trail)
- Use progressive disclosure (AI agents)
- Prioritize by severity (CRITICAL < 1hr)
- Document all findings and remediation

❌ **Never**:
- Delete secrets without rotation (still valid!)
- Skip git history scrubbing (commits are permanent)
- Ignore LOW severity (technical debt compounds)
- Rely on rotation alone (prevention > detection)
- Log secret values during scanning
- Share scan results publicly (contain exposure)
- Skip verification after remediation
- Treat all findings equally (severity matters)

---

## 🔗 Integration Examples

### Pre-commit Hook (Advanced)

```bash
#!/bin/bash
# .git/hooks/pre-commit
# Reference: vault-radar/skills/scan-for-secrets/

set -e

echo "🔍 Vault Radar: Scanning staged files..."

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
  echo "❌ BLOCKED: $CRITICAL CRITICAL secrets detected"
  echo ""
  echo "CRITICAL findings must be resolved before commit."
  echo "Run: vault-radar scan --target git-staged"
  exit 1
fi

if [ "$HIGH" -gt 0 ]; then
  echo "⚠️  WARNING: $HIGH HIGH severity secrets detected"
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
  echo "ℹ️  INFO: $MEDIUM MEDIUM severity findings (not blocking)"
fi

echo "✅ Vault Radar: Scan complete"
exit 0
```

---

### GitLab CI/CD Integration

```yaml
# .gitlab-ci.yml

stages:
  - security
  - build
  - deploy

vault-radar-scan:
  stage: security
  image: hashicorp/vault-radar:latest
  script:
    - vault-radar scan --target . --format json --output scan-results.json
    
    # Parse results
    - CRITICAL=$(jq '[.results[] | select(.severity == "CRITICAL")] | length' scan-results.json)
    - HIGH=$(jq '[.results[] | select(.severity == "HIGH")] | length' scan-results.json)
    
    # Fail on CRITICAL or HIGH
    - |
      if [ "$CRITICAL" -gt 0 ] || [ "$HIGH" -gt 0 ]; then
        echo "❌ Secrets detected - blocking pipeline"
        echo "  CRITICAL: $CRITICAL"
        echo "  HIGH: $HIGH"
        exit 1
      fi
  
  artifacts:
    reports:
      sast: scan-results.json
    paths:
      - scan-results.json
    expire_in: 30 days
  
  only:
    - merge_requests
    - main
```

---

### MCP Server Configuration (Claude Desktop)

```json
{
  "mcpServers": {
    "vault-radar": {
      "command": "npx",
      "args": [
        "-y",
        "@hashicorp/vault-radar-mcp"
      ],
      "env": {
        "VAULT_RADAR_TOKEN": "${VAULT_RADAR_TOKEN}",
        "VAULT_RADAR_ORG": "your-org-name"
      }
    }
  }
}
```

**Available MCP Tools**:
- `scan-repo`: Scan GitHub/GitLab repository
- `scan-offline`: Scan local directory
- `get-finding`: Retrieve finding details (progressive disclosure)
- `triage-severity`: Categorize by impact
- `generate-remediation`: Create fix scripts

---

## 📚 Additional Resources

### Within This Repository
- [Main README](../README.md) - Platform integration guides

### Official Documentation
- [Vault Radar Documentation](https://developer.hashicorp.com/vault/docs/radar)
- [Vault Radar MCP Server](https://github.com/hashicorp/vault-radar-mcp)
- [Model Context Protocol Spec](https://spec.modelcontextprotocol.io/)
- [HCP Vault Radar](https://portal.cloud.hashicorp.com/services/vault-radar)

### Security Resources
- [OWASP Secrets Management](https://cheatsheetseries.owasp.org/cheatsheets/Secrets_Management_Cheat_Sheet.html)
- [CIS Critical Security Controls](https://www.cisecurity.org/controls)
- [NIST Cybersecurity Framework](https://www.nist.gov/cyberframework)

---

## 🤝 Contributing

When adding new Vault Radar skills or workflows:

1. **Follow progressive disclosure**: Don't expose secrets unnecessarily
2. **Include severity guidance**: CRITICAL, HIGH, MEDIUM, LOW
3. **Provide remediation steps**: Not just detection
4. **Add prevention measures**: Pre-commit, CI/CD integration
5. **Document MCP integration**: For AI agent automation
6. **Update this README**: Add your skill/workflow to relevant sections

---

## 💡 Tips for AI Agents

When using these instructions:

1. **Always use progressive disclosure**: Don't reveal secret values unless explicitly requested
2. **Prioritize by severity**: CRITICAL → HIGH → MEDIUM → LOW
3. **Rotate, don't just delete**: Secrets remain valid after removal
4. **Scrub git history**: Commits are permanent without BFG/git-filter-repo
5. **Implement layered prevention**: Pre-commit + CI/CD + runtime monitoring
6. **Migrate to Vault**: Dynamic secrets preferred over static
7. **Verify remediation**: Rescan after fixes applied
8. **Document everything**: Audit trail for compliance

---

**Remember**: Exposed secrets are compromised secrets. Complete remediation means rotation + removal + migration + prevention.

**🔒 Detect Fast | 🚨 Rotate Immediately | 🛡️ Prevent Always**
