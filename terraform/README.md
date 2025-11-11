# Terraform Skills & Workflows

This directory contains AI agent instructions for generating secure Terraform infrastructure code.

## Directory Structure

```
terraform/
├── README.md (this file)
├── skills/
│   ├── generate-hcl/          # Generate HCL code
│   └── refactor-module/       # Extract reusable Terraform modules
├── workflows/
│   ├── plan-and-apply-with-approval.md    # Deployment workflow with gates
│   └── security-scan-workflow.md          # Comprehensive security scanning
└── prompts/
    ├── system-prompt-tf.md    # AI system prompt for Terraform work
    └── summarize-plan.md      # Format plan output for humans
```

---

## What's Inside

### Skills

**Skills** are discrete, reusable capabilities that teach AI agents specific Terraform tasks.

### For Claude Desktop (Native SKILL.md Support)
```bash
# No setup needed! Claude auto-discovers SKILL.md files
# Just use natural language:

"Using the generate-hcl skill, create an AWS VPC with public and private subnets"

"Using the refactor-module skill, extract this RDS configuration into a reusable module"
```

**Why this works**: Claude Desktop natively supports Anthropic's SKILL.md format with progressive disclosure. It automatically finds and loads relevant skills.


#### [generate-hcl](skills/generate-hcl/)
**Purpose**: Create secure, compliant Terraform HCL code following best practices

**Use when**:
- Creating new infrastructure resources
- Need security-hardened configurations
- Generating infrastructure code
- Following compliance standards (CIS, PCI DSS, HIPAA)

**Example**:
```
@workspace Using terraform/skills/generate-hcl/, create:
Resource: AWS RDS PostgreSQL
Environment: Production
Requirements:
  - Encryption at rest with KMS
  - Private subnet placement
  - Automated backups (7-day retention)
  - Multi-AZ deployment
```

**Key Features**:
- Encryption by default (KMS, SSL/TLS)
- Security group hardening
- Proper variable validation
- Comprehensive outputs
- Best practices documentation in `resources/`

---

#### [refactor-module](skills/refactor-module/)
**Purpose**: Extract reusable Terraform modules from existing code

**Use when**:
- Consolidating duplicate code
- Creating shareable modules
- Need state migration (moved blocks)
- Building internal module library

**Example**:
```
@workspace Using terraform/skills/refactor-module/:
Extract: VPC networking configuration
Module name: vpc-standard
Include:
  - State migration with moved blocks
  - Variable validation
  - Comprehensive outputs
  - Usage examples
```

**Key Features**:
- Safe state migration with `moved` blocks
- Module versioning guidance
- Testing frameworks
- Documentation templates

---

### Workflows

**Workflows** are multi-step processes that combine multiple skills and tools.

#### [plan-and-apply-with-approval](workflows/plan-and-apply-with-approval.md)
**Purpose**: Structured deployment process with human approval gates

**Phases**:
1. **Plan**: Generate execution plan
2. **Review**: Human review of changes
3. **Approve**: Explicit approval required
4. **Apply**: Execute changes
5. **Verify**: Confirm deployment

**Use when**:
- Deploying to production
- Changes affect critical infrastructure
- Compliance requires approval trails
- Team review needed

**Integration**: Works with GitHub Actions, GitLab CI, HCP Terraform

---

#### [security-scan-workflow](workflows/security-scan-workflow.md)
**Purpose**: Comprehensive security validation before deployment

**Scans performed**:
- **tfsec**: Security best practices
- **checkov**: Compliance policies
- **terrascan**: Multi-framework security
- **Custom**: Organization-specific rules

**Use when**:
- Before every deployment
- CI/CD pipeline validation
- Security audit requirements
- Compliance checks (PCI DSS, HIPAA, SOC2)

**Fail conditions**: Critical or High severity findings

---

### Prompts

**Prompts** are specialized instructions for specific AI agent scenarios.

#### [system-prompt-tf](prompts/system-prompt-tf.md)
**Purpose**: Define AI agent behavior for Terraform work

**Use when**:
- Starting new AI agent session
- Need Terraform-specific context
- Autonomous agent deployment

**Sets expectations for**:
- Security-first approach
- HCL best practices
- Validation requirements
- Error handling

---

#### [summarize-plan](prompts/summarize-plan.md)
**Purpose**: Convert Terraform plan output to human-readable summary

**Use when**:
- Posting plan to PR comments
- Generating change reports
- Executive summaries needed
- Non-technical stakeholder communication

**Output includes**:
- Resources to add/change/destroy (counts)
- High-impact changes highlighted
- Estimated cost impact
- Risk assessment

---

## Quick Start

### For GitHub Copilot Users

**Method 1: Direct reference** (no setup)
```
@workspace Using terraform/skills/generate-hcl/, create an S3 bucket with encryption
```

**Method 2: Custom Agent** (specialized)
Create `.github/agents/terraform-specialist.md`:
```markdown
---
name: terraform-specialist
description: Expert in secure Terraform infrastructure
tools: ["read", "edit", "search", "terminal"]
---

Load instructions from terraform/skills/generate-hcl/SKILL.md
and follow security best practices...
```

**Method 3: Repository Instructions** (team-wide)
Add to `.github/copilot-instructions.md`:
```markdown
## Terraform Standards
Always reference terraform/skills/generate-hcl/ for HCL generation.
Run tfsec and checkov before committing.
```

---

### For Claude Users

**Install as Skills**:
```bash
# Link to Claude's skills directory
mkdir -p ~/.claude/skills
ln -s ~/path/to/terraform/skills/generate-hcl ~/.claude/skills/terraform-generate-hcl
ln -s ~/path/to/terraform/skills/refactor-module ~/.claude/skills/terraform-refactor
```

**Usage**:
```
Using the terraform-generate-hcl skill, create a production VPC
```

Claude will automatically load the skill and apply patterns.

---

### For VS Code / JetBrains Users

**Create Prompt File**: `.github/prompts/terraform-generate.prompt.md`
```markdown
Generate Terraform code following best practices:

1. Load: #file:../../agent-instructions-library-man/terraform/skills/generate-hcl/SKILL.md
2. Apply security standards
3. Run validation: terraform fmt, validate
4. Scan: tfsec, checkov
```

**Usage**: Attach prompt in Copilot Chat

---

### For AGENTS.md Compatible Tools (Cursor, Jules, Gemini CLI)

**Add to AGENTS.md**:
```markdown
## Terraform Standards

### Code Generation
Use: agent-instructions-library-man/terraform/skills/generate-hcl/

Always:
- Encrypt data at rest (KMS)
- Private networking by default
- Validate variables with validation blocks
- Run security scans before commit

### Validation Commands
```bash
terraform fmt -recursive
terraform validate
tfsec . --minimum-severity HIGH
checkov -d . --framework terraform
```
```

---

## 🔧 Common Use Cases

### Use Case 1: Create Secure Database
```
@workspace Using terraform/skills/generate-hcl/, create:

Resource: AWS RDS PostgreSQL
Environment: Production
Security:
  - Encryption at rest (KMS)
  - Private subnet only
  - No public access
  - SSL/TLS required
  - Automated backups (7 days)
Compliance: PCI DSS Level 1
```

### Use Case 2: Refactor Repeated Code
```
@workspace Using terraform/skills/refactor-module/:

Extract repeated VPC code into module vpc-standard
Include:
  - 3 public subnets
  - 3 private subnets
  - NAT gateway per AZ
  - VPC Flow Logs to S3
Generate moved blocks for state migration
```

### Use Case 3: Security Scan Before PR
```
@workspace Apply terraform/workflows/security-scan-workflow.md

Scan: ./terraform/environments/prod/
Tools: tfsec, checkov, terrascan
Standards: CIS AWS Foundations Benchmark
Fail on: HIGH or CRITICAL
Output: SARIF for GitHub Code Scanning
```

### Use Case 4: Plan Summary for Stakeholders
```
@workspace Using terraform/prompts/summarize-plan.md:

Input: tfplan output
Format: Executive summary
Include:
  - Resource changes (add/modify/destroy counts)
  - Cost impact estimate
  - Risk level (low/medium/high)
  - Compliance impact
```

## Integration Examples

### GitHub Actions

```yaml
name: Terraform Security Scan

on: [pull_request]

jobs:
  scan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          cli_config_credentials_token: ${{ secrets.TF_API_TOKEN }}
      
      - name: Terraform Format Check
        run: terraform fmt -check -recursive
      
      - name: Terraform Validate
        run: |
          terraform init -backend=false
          terraform validate
      
      - name: Security Scan
        run: |
          # Reference: terraform/workflows/security-scan-workflow.md
          tfsec . --format json > tfsec-results.json
          checkov -d . --output json > checkov-results.json
          
      - name: Upload SARIF
        uses: github/codeql-action/upload-sarif@v3
        with:
          sarif_file: tfsec-results.sarif
```

### Pre-commit Hook

```bash
#!/bin/bash
# .git/hooks/pre-commit

echo "Running Terraform validation..."

# Format check
terraform fmt -check -recursive
if [ $? -ne 0 ]; then
  echo "Terraform format check failed. Run: terraform fmt -recursive"
  exit 1
fi

# Validate
terraform validate
if [ $? -ne 0 ]; then
  echo "Terraform validation failed"
  exit 1
fi

# Security scan
tfsec . --minimum-severity HIGH
if [ $? -ne 0 ]; then
  echo "Security scan failed. See: terraform/workflows/security-scan-workflow.md"
  exit 1
fi

echo "All pre-commit checks passed"
```

---

## Additional Resources

### Within This Repository
- [HCL Best Practices](skills/generate-hcl/resources/hcl-best-practices.md)
- [Main README](../README.md) - Platform integration guides

### Official Documentation
- [Terraform Documentation](https://www.terraform.io/docs)
- [HCP Terraform](https://developer.hashicorp.com/terraform/cloud-docs)
- [Terraform Registry](https://registry.terraform.io/)
- [AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)

### Security Tools
- [tfsec](https://aquasecurity.github.io/tfsec/)
- [checkov](https://www.checkov.io/)
- [terrascan](https://runterrascan.io/)
- [terraform-compliance](https://terraform-compliance.com/)

---

## Tips for AI Agents

When using these instructions:

1. **Always read the full SKILL.md** before generating code
2. **Reference `resources/hcl-best-practices.md`** for patterns
3. **Run validation** after code generation:
   ```bash
   terraform fmt
   terraform validate
   tfsec .
   ```
4. **Include comments** explaining security decisions
5. **Use explicit types** for all variables (never `any`)
6. **Add lifecycle blocks** for stateful resources
7. **Generate comprehensive outputs** for all modules

