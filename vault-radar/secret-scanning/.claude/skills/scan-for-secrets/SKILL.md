# Skill: Scan for Secrets, PII, and Non-Inclusive Language

## Overview

This skill enables AI agents to guide developers in using HCP Vault Radar to detect and prevent exposure of sensitive information in code repositories. Vault Radar identifies three critical risk categories: secrets (credentials, API keys), personally identifiable information (PII), and non-inclusive language (NIL), providing real-time scanning and remediation guidance.

## Capability Statement

**As an AI agent, I can help developers:**
- Configure Vault Radar for scanning GitHub repositories and other data sources
- Run offline scans using the Vault Radar CLI
- Analyze scan results and categorize findings by severity
- Interpret risk categories (secrets, PII, NIL) and recommend actions
- Implement preventive controls (pre-commit hooks, CI/CD integration)
- Understand Vault Radar's security model (HMAC + Argon2id hashing)

## Prerequisites

### For HCP Vault Radar (Online Scanning)
- HCP account with Vault Radar project created
- GitHub/GitLab repository connected as data source
- Service principal credentials (for CLI authentication)
- Appropriate IAM permissions (Vault Radar Viewer/Admin)

### For Vault Radar CLI (Offline Scanning)
- Vault Radar CLI installed (`brew install hashicorp/tap/vault-radar` or download binary)
- Local repository or file system access
- Optional: HCP credentials for syncing results

### Knowledge Prerequisites
- Understanding of secrets management principles
- Familiarity with git version control
- Basic knowledge of security severity levels
- Awareness of compliance requirements (PII handling, inclusive language policies)

## Input Parameters

### For Repository Scanning

```yaml
scan_mode: string              # "online" (HCP) or "offline" (CLI)
data_source_type: string       # "github", "gitlab", "filesystem", "git"
repository_url: string         # Repository URL (for online) or local path (for offline)
branch: string                 # Branch to scan (default: "main")
scan_depth: string             # "full" (all history) or "shallow" (recent commits)
risk_categories: array         # ["secrets", "pii", "nil"] or subset
exclude_patterns: array        # File/directory patterns to exclude
custom_rules: boolean          # Use custom detection rules (HCP only)
```

### For CLI Offline Scanning

```yaml
scan_path: string              # Local directory path
output_format: string          # "json", "sarif", "text"
output_file: string            # Output file path (optional)
indexing_enabled: boolean      # Create index for faster subsequent scans
secret_hasher_key: string      # Custom key for secret hashing (optional)
```

## Execution Steps

### Step 1: Choose Scanning Approach

**Online Scanning (HCP Vault Radar)**:
- Continuous monitoring with real-time alerts
- Pull request scanning and blocking
- Centralized dashboard and reporting
- Active secret verification
- Team collaboration features

**Offline Scanning (CLI)**:
- No data leaves your environment
- One-time or scheduled scans
- Integration with local workflows
- Faster for large repositories
- No internet connectivity required

### Step 2: Online Scanning Setup (HCP)

```bash
# Install Vault Radar CLI
brew install hashicorp/tap/vault-radar

# Authenticate with HCP
vault-radar auth login \
  --client-id="${HCP_CLIENT_ID}" \
  --client-secret="${HCP_CLIENT_SECRET}"

# Connect GitHub repository
# (Also available via HCP UI: Vault Radar > Data Sources > Add GitHub)
vault-radar data-source add github \
  --organization="your-org" \
  --repository="your-repo"

# Initial scan is triggered automatically
# Monitor scan status
vault-radar scan status --data-source-id="ds-abc123"
```

### Step 3: Offline Scanning with CLI

```bash
# Navigate to repository
cd /path/to/your/repository

# Run a comprehensive scan
vault-radar scan repo \
  --path=. \
  --output-format=json \
  --output-file=scan-results.json

# Scan specific directory
vault-radar scan repo \
  --path=./src \
  --risk-categories=secrets,pii

# Scan with exclusions
vault-radar scan repo \
  --path=. \
  --exclude='*.test.js,node_modules/*,vendor/*'

# Create indexed scan for faster subsequent runs
vault-radar scan repo \
  --path=. \
  --index
```

### Step 4: Analyze Scan Results

**Understanding Severity Levels**:

| Severity | Criteria | Action Required |
|----------|----------|-----------------|
| **Critical** | Active secret in latest version | Immediate rotation |
| **High** | Active secret in older version OR secret in secret manager | Rotate soon |
| **Medium** | Default for unclassified secrets | Investigate and remediate |
| **Low** | PII OR secrets in test files | Review and remove if needed |
| **Info** | NIL OR inactive secrets | Consider remediation |

**Risk Categories**:

1. **Secrets**:
   - AWS/GCP/Azure credentials
   - Database passwords
   - API keys and tokens
   - Private keys (SSH, TLS)
   - OAuth tokens
   - Generic secrets

2. **PII (Personally Identifiable Information)**:
   - Email addresses
   - Social security numbers
   - Phone numbers
   - Credit card numbers
   - Personal names in specific contexts

3. **NIL (Non-Inclusive Language)**:
   - Offensive terminology
   - Exclusionary language
   - Culturally insensitive terms

### Step 5: Review and Triage Findings

```bash
# View scan summary
vault-radar events list \
  --severity=critical,high \
  --limit=20

# Filter by risk category
vault-radar events list \
  --risk-category=secrets \
  --status=active

# Export for analysis
vault-radar events list \
  --output-format=json \
  --output-file=critical-secrets.json

# Check specific secret type
vault-radar events list \
  --secret-type=aws_access_key_id
```

**Interpreting Results**:

```json
{
  "event_id": "evt-abc123",
  "severity": "critical",
  "risk_category": "secret",
  "secret_type": "aws_access_key_id",
  "status": "active",
  "location": {
    "file_path": "config/aws.js",
    "line_number": 15,
    "commit_hash": "a1b2c3d4",
    "is_latest_version": true
  },
  "detected_at": "2025-11-09T10:30:00Z",
  "tags": []
}
```

### Step 6: Remediate Findings

**For Secrets**:

```bash
# 1. Rotate the exposed secret immediately
# Example for AWS access key:
aws iam delete-access-key --access-key-id AKIA...
aws iam create-access-key --user-name myapp-user

# 2. Update application configuration
# Move secret to Vault, AWS Secrets Manager, or environment variables

# 3. Remove from git history (if committed)
# See vault-radar/workflows/git-history-scrubbing.md

# 4. Mark as resolved in HCP (if using online)
vault-radar events resolve --event-id evt-abc123 \
  --resolution-note="Rotated AWS key and migrated to Vault"
```

**For PII**:

```bash
# 1. Remove PII from code
# Replace with placeholder or anonymized data

# 2. Scrub from git history
git filter-repo --path config/users.json --invert-paths

# 3. Update processes to prevent future exposure
# - Use synthetic test data
# - Implement data masking
# - Add pre-commit hooks
```

**For Non-Inclusive Language**:

```bash
# 1. Replace with inclusive alternatives
# Example: "whitelist" → "allowlist", "blacklist" → "denylist"

# 2. Update documentation and comments

# 3. Add to project style guide

# 4. Configure linting rules to prevent reintroduction
```

### Step 7: Implement Preventive Controls

**Pre-Commit Hook**:

```bash
#!/bin/bash
# .git/hooks/pre-commit

echo "Running Vault Radar scan on staged files..."

# Create temporary directory for staged files
TEMP_DIR=$(mktemp -d)
git diff --cached --name-only --diff-filter=ACM | while read file; do
  mkdir -p "$TEMP_DIR/$(dirname "$file")"
  git show ":$file" > "$TEMP_DIR/$file"
done

# Scan staged files
vault-radar scan repo \
  --path="$TEMP_DIR" \
  --risk-categories=secrets,pii \
  --output-format=json \
  --output-file=/tmp/vault-radar-precommit.json

# Check for critical/high findings
CRITICAL_COUNT=$(jq '[.events[] | select(.severity=="critical" or .severity=="high")] | length' /tmp/vault-radar-precommit.json)

if [ "$CRITICAL_COUNT" -gt 0 ]; then
  echo "❌ Vault Radar found $CRITICAL_COUNT critical/high severity issues!"
  echo "Review findings in /tmp/vault-radar-precommit.json"
  rm -rf "$TEMP_DIR"
  exit 1
fi

echo "✅ Vault Radar scan passed"
rm -rf "$TEMP_DIR"
exit 0
```

**GitHub Actions Integration**:

```yaml
# .github/workflows/vault-radar-scan.yml
name: Vault Radar Scan

on:
  pull_request:
    branches: [main, develop]
  push:
    branches: [main]

jobs:
  scan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0  # Full history for comprehensive scan
      
      - name: Install Vault Radar CLI
        run: |
          curl -fsSL https://releases.hashicorp.com/vault-radar/latest/vault-radar_linux_amd64.zip -o vault-radar.zip
          unzip vault-radar.zip
          chmod +x vault-radar
          sudo mv vault-radar /usr/local/bin/
      
      - name: Run Vault Radar Scan
        env:
          HCP_CLIENT_ID: ${{ secrets.HCP_CLIENT_ID }}
          HCP_CLIENT_SECRET: ${{ secrets.HCP_CLIENT_SECRET }}
        run: |
          vault-radar scan repo \
            --path=. \
            --output-format=sarif \
            --output-file=vault-radar-results.sarif
      
      - name: Upload SARIF results
        uses: github/codeql-action/upload-sarif@v3
        with:
          sarif_file: vault-radar-results.sarif
          category: vault-radar
      
      - name: Check for critical findings
        run: |
          CRITICAL=$(jq '.runs[0].results | map(select(.level=="error")) | length' vault-radar-results.sarif)
          if [ "$CRITICAL" -gt 0 ]; then
            echo "❌ Found $CRITICAL critical security issues"
            exit 1
          fi
          echo "✅ No critical issues found"
```

**GitLab CI Integration**:

```yaml
# .gitlab-ci.yml
vault-radar-scan:
  stage: security
  image: alpine:latest
  before_script:
    - apk add --no-cache curl jq
    - curl -fsSL https://releases.hashicorp.com/vault-radar/latest/vault-radar_linux_amd64.zip -o vault-radar.zip
    - unzip vault-radar.zip && chmod +x vault-radar
  script:
    - ./vault-radar scan repo --path=. --output-format=json --output-file=scan-results.json
    - |
      CRITICAL=$(jq '[.events[] | select(.severity=="critical")] | length' scan-results.json)
      if [ "$CRITICAL" -gt 0 ]; then
        echo "Critical secrets detected!"
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

## Output Format

### CLI Scan Output (JSON)

```json
{
  "scan_id": "scan-xyz789",
  "scan_timestamp": "2025-11-10T12:00:00Z",
  "scan_path": "/path/to/repo",
  "summary": {
    "total_events": 47,
    "by_severity": {
      "critical": 2,
      "high": 5,
      "medium": 18,
      "low": 15,
      "info": 7
    },
    "by_category": {
      "secrets": 25,
      "pii": 12,
      "nil": 10
    },
    "active_secrets": 7,
    "inactive_secrets": 18
  },
  "events": [
    {
      "event_id": "evt-local-001",
      "severity": "critical",
      "risk_category": "secret",
      "secret_type": "aws_access_key_id",
      "status": "active",
      "location": {
        "file_path": "src/config/aws.js",
        "line_number": 15,
        "line_content": "const AWS_KEY = 'AKIAIOSFODNN7EXAMPLE';",
        "commit_hash": "a1b2c3d4",
        "author": "developer@example.com",
        "committed_at": "2025-11-01T14:30:00Z"
      },
      "hashed_secret": "hmac:sha256:a9f5...",
      "tags": []
    },
    {
      "event_id": "evt-local-002",
      "severity": "low",
      "risk_category": "pii",
      "secret_type": "email_address",
      "location": {
        "file_path": "tests/fixtures/users.json",
        "line_number": 8,
        "line_content": "\"email\": \"john.doe@example.com\""
      },
      "tags": ["secret_in_test_file"]
    },
    {
      "event_id": "evt-local-003",
      "severity": "info",
      "risk_category": "nil",
      "nil_type": "non_inclusive_term",
      "location": {
        "file_path": "docs/network-config.md",
        "line_number": 42,
        "line_content": "Add IPs to the whitelist"
      },
      "suggested_replacement": "allowlist"
    }
  ],
  "exclusions": {
    "ignored_files": 342,
    "patterns": ["node_modules/*", "*.test.js", "vendor/*"]
  }
}
```

### Remediation Report

```markdown
# Vault Radar Scan Report

**Repository**: my-application
**Scan Date**: 2025-11-10 12:00 UTC
**Scan Type**: Full history scan

## Executive Summary

- **Total Findings**: 47
- **Critical**: 2 (require immediate action)
- **High**: 5 (remediate within 24 hours)
- **Medium**: 18 (remediate within 1 week)
- **Low**: 15 (review and address)
- **Info**: 7 (awareness only)

## Critical Findings

### 1. AWS Access Key (Active) - evt-local-001

**Severity**: Critical
**Location**: `src/config/aws.js:15`
**Detected**: 2025-11-09 14:22 UTC
**Status**: ✅ Active (verified with AWS)

```javascript
// Line 15:
const AWS_KEY = 'AKIAIOSFODNN7EXAMPLE';
```

**Immediate Actions**:
1. Rotate AWS access key using IAM console
2. Update application to use AWS Secrets Manager or Vault
3. Audit CloudTrail for unauthorized access
4. Revoke old key once rotation is verified

**Estimated Time**: 20 minutes

### 2. Database Password (Active) - evt-local-002

**Severity**: Critical
**Location**: `config/database.yml:8`
**Status**: ⚠️ Active (database connection successful)

```yaml
production:
  password: "MyS3cur3P@ssw0rd!"
```

**Immediate Actions**:
1. Change database password
2. Migrate to Vault dynamic database credentials
3. Update application configuration
4. Review database audit logs

**Estimated Time**: 30 minutes

## High Severity Findings

### AWS Secret Access Keys (3 instances)
- `deploy/scripts/backup.sh:27`
- `infrastructure/aws-config.tf:14`
- `.env.example:6` (should be placeholder)

### API Keys (2 instances)
- Stripe API key: `lib/payment/stripe.rb:9`
- SendGrid API key: `services/email/config.json:3`

## Medium Severity Findings

18 findings across:
- Private SSH keys in commit history (5)
- Generic secrets without active verification (8)
- OAuth tokens (3)
- Legacy API keys (2)

## PII Findings

12 instances of personally identifiable information:
- Email addresses in test fixtures (8 - tagged as test files)
- SSN patterns in documentation examples (2)
- Phone numbers in sample data (2)

## Non-Inclusive Language

10 instances found:
- "whitelist" → "allowlist" (5 occurrences)
- "blacklist" → "denylist" (3 occurrences)
- "master" → "main" (2 occurrences in docs)

## Recommended Actions

### Immediate (Critical)
- [ ] Rotate AWS access key (evt-local-001)
- [ ] Change database password (evt-local-002)

### Short-term (High - within 24h)
- [ ] Rotate all AWS secret access keys
- [ ] Migrate API keys to secrets management
- [ ] Implement Vault dynamic credentials for database

### Medium-term (Medium - within 1 week)
- [ ] Scrub SSH keys from git history
- [ ] Implement pre-commit hooks
- [ ] Configure Vault Radar GitHub app for PR scanning
- [ ] Establish secrets rotation policy

### Long-term (Low/Info)
- [ ] Replace test fixture PII with synthetic data
- [ ] Update language in documentation
- [ ] Create style guide for inclusive language
- [ ] Implement automated linting for terminology

## Prevention Strategy

1. **Pre-Commit Scanning**: Install git hooks to scan before commits
2. **CI/CD Integration**: Add Vault Radar to pipeline (see examples above)
3. **Developer Training**: Educate team on secrets management best practices
4. **Policy Enforcement**: Require passing scans for PR merges
5. **Regular Audits**: Schedule monthly full repository scans

## References

- Remediation workflow: `vault-radar/workflows/triage-and-remediate.md`
- Git history scrubbing: `vault-radar/workflows/git-history-scrubbing.md`
- Vault integration: `vault/workflows/migrate-to-vault.md`
```

## Best Practices

### Scanning Strategy

1. **Initial Baseline**:
   - Run full history scan to discover all secrets
   - Triage findings by severity
   - Create remediation plan with timelines
   - Track progress in issue tracker

2. **Continuous Monitoring**:
   - Enable HCP Vault Radar for connected repositories
   - Configure PR scanning to block commits with secrets
   - Set up alerts for critical findings
   - Review dashboard weekly

3. **Exclusions Management**:
   ```bash
   # Create .vault-radar-ignore file
   cat > .vault-radar-ignore <<EOF
   # Test fixtures
   tests/fixtures/
   **/*.test.js
   
   # Dependencies
   node_modules/
   vendor/
   .venv/
   
   # Build artifacts
   dist/
   build/
   *.min.js
   
   # Documentation examples (review carefully)
   docs/examples/
   EOF
   ```

4. **Tag-Based Filtering**:
   - Vault Radar automatically tags `secret_in_test_file`
   - Tags reduce severity for test/example files
   - Review tags to ensure correct categorization

### Security Considerations

1. **Secret Hashing**:
   - Vault Radar uses HMAC + Argon2id for secret hashing
   - Argon2id provides memory-hardness and brute-force resistance
   - Offline CLI creates local hasher key in `~/.vault-radar.json`
   - Keep hasher key consistent for accurate deduplication

2. **Data Privacy**:
   - Online scanning: Hashed secrets sent to HCP (original secrets never transmitted)
   - Offline scanning: All data stays local
   - Choose mode based on compliance requirements

3. **Network Requirements**:
   - HCP authentication requires access to `api.cloud.hashicorp.com` and `auth.idp.hashicorp.com`
   - For scanning internal repos, allowlist HCP IPs (see integration skill)

### Performance Optimization

1. **Large Repositories**:
   ```bash
   # Use indexing for faster subsequent scans
   vault-radar scan repo --path=. --index
   
   # Scan only recent commits
   vault-radar scan repo --path=. --commits=100
   
   # Scan specific paths
   vault-radar scan repo --path=./src --path=./config
   ```

2. **CI/CD Optimization**:
   - Scan only changed files in PRs
   - Cache Vault Radar CLI binary
   - Use SARIF output for GitHub Code Scanning integration
   - Set appropriate timeouts

## Common Pitfalls

### ❌ Ignoring Test File Secrets

**Problem**: Assuming test files don't matter

**Impact**: Test secrets often become production secrets through copy-paste

**Solution**:
- Review all secrets, even in test files
- Use obviously fake patterns (e.g., `AKIAIOSFODNN7EXAMPLE`)
- Generate fresh test credentials that are immediately revoked

### ❌ Incomplete Git History Scrubbing

**Problem**: Removing secrets from latest commit only

**Impact**: Secrets remain in git history and can be accessed

**Solution**:
```bash
# Use git-filter-repo or BFG to scrub entire history
git filter-repo --path config/secrets.yml --invert-paths

# Force push (coordinate with team)
git push origin --force --all

# Inform team to re-clone repository
```

### ❌ Not Rotating After Detection

**Problem**: Marking secrets as "resolved" without rotation

**Impact**: Secrets remain compromised

**Solution**:
- Always rotate secrets immediately
- Verify rotation completed before marking as resolved
- Audit access logs for unauthorized usage

### ❌ Over-Reliance on Exclusions

**Problem**: Excluding too many paths or patterns

**Impact**: Missing actual secrets in excluded areas

**Solution**:
- Use exclusions sparingly
- Periodically review exclusion rules
- Document reason for each exclusion

## Related Skills

- `vault-radar/skills/integrate-mcp-server/` - Using MCP for AI-assisted analysis
- `vault/skills/generate-policy/` - Creating Vault policies for migrated secrets
- `terraform/workflows/security-scan-workflow.md` - Infrastructure scanning

## Related Workflows

- `vault-radar/workflows/triage-and-remediate.md` - Handling findings systematically
- `vault-radar/workflows/git-history-scrubbing.md` - Removing secrets from history
- `vault/workflows/migrate-secrets-to-vault.md` - Moving secrets to Vault

## Resources

### Official Documentation
- [Vault Radar Documentation](https://developer.hashicorp.com/hcp/docs/vault-radar)
- [Vault Radar FAQ](https://developer.hashicorp.com/hcp/docs/vault-radar/faq)
- [Vault Radar CLI Reference](https://developer.hashicorp.com/hcp/docs/vault-radar/cli)

### Secret Types Detected
Common patterns Vault Radar identifies:
- AWS (access keys, secret keys, session tokens)
- GCP (service account keys, API keys)
- Azure (storage keys, connection strings)
- GitHub (personal access tokens, OAuth)
- Database credentials (PostgreSQL, MySQL, MongoDB)
- Private keys (SSH, RSA, TLS)
- API keys (Stripe, Twilio, SendGrid, etc.)
- Generic secrets (high-entropy strings)

### Severity Calculation Details

| Severity | Secret Criteria | PII/NIL Criteria |
|----------|----------------|------------------|
| Critical | Active + Latest version | N/A |
| High | Active + Older version OR In secret manager (active unknown) | N/A |
| Medium | Default (active status unknown) | N/A |
| Low | N/A | All PII OR Secrets in test files |
| Info | Inactive OR Certain tags (example files, specific types) | All NIL |

## Revision History

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | 2025-11-10 | Initial skill creation covering online and offline scanning |
