# Complete Usage Guide: AI Agent Instructions Library

> **Learn how to use instruction files with different AI coding assistants**

## 📚 Table of Contents

- [What This Guide Covers](#what-this-guide-covers)
- [Understanding Instruction File Types](#understanding-instruction-file-types)
- [Platform-Specific Setup](#platform-specific-setup)
- [Usage Patterns by Platform](#usage-patterns-by-platform)
- [Real-World Examples](#real-world-examples)
- [Best Practices](#best-practices)
- [Troubleshooting](#troubleshooting)

## 🎯 What This Guide Covers

This guide explains how to effectively use the Agent Instructions Library with different AI coding assistants. You'll learn:

- **What** instruction files are and how they work
- **How** to set them up for your specific AI platform
- **When** to use different instruction types
- **Examples** of real-world usage patterns

## 📖 Understanding Instruction File Types

### Visual Overview

```text
┌───────────────────────────────────────────────────────────────┐
│         Instruction File Type Hierarchy                       │
├───────────────────────────────────────────────────────────────┤
│                                                               │
│  1. System Prompts (Foundation)                               │
│     ├─ Defines agent identity & expertise                     │
│     ├─ Sets behavior patterns                                 │
│     └─ Establishes guardrails                                 │
│          │                                                    │
│          ▼                                                    │
│  2. Skills (Discrete Capabilities)                            │
│     ├─ Generate HCL code                                      │
│     ├─ Create Vault policies                                  │
│     └─ Scan for secrets                                       │
│          │                                                    │
│          ▼                                                    │
│  3. Workflows (Multi-Step Processes)                          │
│     ├─ Plan → Review → Apply                                  │
│     ├─ Scan → Triage → Remediate                              │
│     └─ Configure → Test → Deploy                              │
│          │                                                    │
│          ▼                                                    │
│  4. Prompts (Reusable Templates)                              │
│     ├─ Summarize Terraform plan                               │
│     ├─ Analyze scan results                                   │
│     └─ Generate reports                                       │
│                                                               │
└───────────────────────────────────────────────────────────────┘
```

### 1. Skills (`SKILL.md`)

**Format:**
```markdown
# Skill: Descriptive Name

## Overview
[High-level description]

## Capability Statement
When invoked, I will:
1. [Action 1]
2. [Action 2]

## Prerequisites
[Required setup]

## Input Parameters
[What the agent needs]

## Execution Steps
[Detailed instructions]

## Output Format
[Expected results]

## Examples
[Concrete usage examples]
```text

**Note:** Skills use standard Markdown format. The skill name serves as the identifier for Claude's progressive disclosure and explicit references in other platforms.

**Example:**
```
skills/generate-hcl/
├── SKILL.md                      # Level 2
└── resources/
    ├── hcl-best-practices.md    # Level 3
    └── examples/                 # Level 3
```text

### 2. Workflows (`*.md`)

**Format:**
```markdown
# Workflow: Descriptive Name

## Overview
[What this workflow accomplishes]

## Workflow Diagram
[ASCII or Mermaid diagram]

## Prerequisites
[Required setup and tools]

## Steps

### Step 1: [Action]
[Detailed instructions]

### Step 2: [Action]
[Detailed instructions]

## Best Practices
[Recommended approaches]

## Troubleshooting
[Common issues and solutions]
```

**When to Use:**
- Process has multiple steps with decision points
- Human approval or review required
- Different tools need coordination
- Error handling is critical

### 3. Prompts (`*.prompt.md` or `*.md`)

**Format:**
```markdown
# Prompt: Descriptive Name

## Purpose
[What this prompt accomplishes]

## Input
[Required context or files]

## Output Format
[Expected response structure]

## Usage
[How to invoke]

## Example
[Concrete example]
```text

**Usage Patterns:**

**Direct Reference:**
```
@workspace Read terraform/prompts/summarize-plan.md
Then summarize this plan: #file:tfplan.txt
```text

**As Prompt File (GitHub Copilot):**
```
@workspace #summarize-plan #file:tfplan.txt
```text

**As Attachment (Claude):**
```
Using the summarize-plan prompt, analyze: [paste plan]
```text

### 4. System Prompts (`system-prompt-*.md`)

**Format:**
```markdown
# System Prompt: [Product] AI Agent

## Identity and Role
[Who the agent is]

## Core Capabilities
[What it can do]

## Interaction Principles
[How it communicates]

## Tool Usage
[When and how to use tools]

## Security Guardrails
[What never to do]
```

**Loading:**
```text
@workspace Load terraform/prompts/system-prompt-tf.md as system context
```

## 🔌 Platform-Specific Setup

### GitHub Copilot

#### Repository-Wide Instructions

**File:** `.github/copilot-instructions.md`

**Auto-loaded by:**
- GitHub Copilot in VS Code
- GitHub Copilot in JetBrains
- GitHub Copilot CLI
- GitHub Copilot on GitHub.com

**Setup:**
```bash
# Option 1: Copy from this repository
cp agent-instructions-library/.github/copilot-instructions.md .github/

# Option 2: Reference via symlink
ln -s agent-instructions-library/.github/copilot-instructions.md .github/

# Option 3: Add submodule
git submodule add https://github.com/hashicorp/agent-instructions-library .ai-instructions
ln -s .ai-instructions/.github/copilot-instructions.md .github/
```text

#### Path-Specific Instructions

**File:** `.github/instructions/NAME.instructions.md`

**Example:**
```markdown
---
applyTo: "**/*.tf"
description: Terraform code standards
---

# Terraform Instructions

When working with Terraform files:
1. Read terraform/skills/generate-hcl/SKILL.md
2. Apply security defaults
3. Run tfsec before committing
```

**Advanced Pattern:**
```markdown
---
applyTo: "terraform/environments/prod/**/*.tf"
---

# Production Terraform Standards

CRITICAL: Production changes require:
1. Full plan review
2. Security scan (tfsec, checkov)
3. Manual approval
4. Follow terraform/workflows/plan-and-apply-with-approval.md
```text

#### Prompt Files

**Enable in VS Code:**
```json
{
  "chat.promptFiles": true
}
```

**Create:** `.github/prompts/terraform-review.prompt.md`
```markdown
Review this Terraform code for:
- Security vulnerabilities
- Best practice violations  
- Cost optimization opportunities

Reference: #file:terraform/skills/generate-hcl/resources/hcl-best-practices.md
```text

**Usage:**
```
@workspace #terraform-review #file:main.tf
```text

### Claude

#### Skills (Native Format)

**Claude Desktop/Web:**
1. Enable Skills in Settings → Features
2. Skills auto-discovered from repository
3. Reference by name: "Use the generate-hcl skill..."

**Claude Code:**
```bash
# Install skills
cp -r terraform/skills ~/.claude/skills/terraform/
cp -r vault/skills ~/.claude/skills/vault/
cp -r vault-radar/skills ~/.claude/skills/vault-radar/

# Skills loaded automatically when relevant
```

**API Integration:**
```python
from anthropic import Anthropic

client = Anthropic(api_key=os.environ["ANTHROPIC_API_KEY"])

response = client.messages.create(
    model="claude-3-5-sonnet-20241022",
    max_tokens=4096,
    skills=["terraform/skills/generate-hcl"],
    messages=[{
        "role": "user",
        "content": "Create an AWS VPC with public and private subnets"
    }]
)
```text

**Progressive Disclosure Example:**
```
User: "Create a secure RDS instance"
      │
      ▼
Claude scans skills metadata
      │
      ▼
Finds: generate-hcl (matches "create")
      │
      ▼
Loads: skills/generate-hcl/SKILL.md
      │
      ▼
References: resources/hcl-best-practices.md (as needed)
      │
      ▼
Generates secure HCL code
```text

### Cursor

#### .cursorrules

**File:** `.cursorrules`

```
# HashiCorp Instructions

## Terraform
When generating Terraform code:
1. Read terraform/skills/generate-hcl/SKILL.md
2. Query Terraform Registry for latest versions
3. Apply security defaults
4. Run: terraform fmt && terraform validate && tfsec .

## Vault
When creating Vault policies:
1. Read vault/skills/generate-policy/SKILL.md
2. Use principle of least privilege
3. Include explicit deny rules
4. Test with vault policy fmt

## References
- Skills: agent-instructions-library/{product}/skills/
- Workflows: agent-instructions-library/{product}/workflows/
```text

#### AGENTS.md

**File:** `AGENTS.md`

```markdown
# Agent Instructions

## Terraform Development

### Build Commands
- Format: `terraform fmt -recursive`
- Validate: `terraform validate`
- Plan: `terraform plan -out=tfplan`
- Apply: `terraform apply tfplan`

### Testing
- Security: `tfsec . && checkov -d .`
- Cost: `infracost breakdown --path .`

### Skills
- Generate HCL: terraform/skills/generate-hcl/
- Refactor: terraform/skills/refactor-module/

### Workflows
- Production: terraform/workflows/plan-and-apply-with-approval.md
- Security: terraform/workflows/security-scan-workflow.md

## Vault Development

### Skills
- Generate Policy: vault/skills/generate-policy/
- Read Secrets: vault/skills/read-secret-securely/

### Workflows
- Setup: vault/workflows/new-kv-engine-setup.md
```

### Amazon Kiro

#### Hook-Based Context Injection

**Files:** `.kiro/hooks/`, `.kiro/specs/`, `.kiro/steering/`

Kiro uses three types of context files:
- **Hooks**: Pre/post file operation context
- **Specs**: File generation specifications
- **Steering**: Agent behavior guidelines

**Setup:**
```bash
# Copy Kiro files to your project root
cp -r terraform/.kiro/ .kiro/

# Directory structure
.kiro/
├── hooks/          # Context for file operations
│   └── *.md
├── specs/          # Generation templates
│   └── *.md
└── steering/       # Agent instructions
    └── *.md
```

**Usage:**
1. Open Kiro tab in your editor
2. Click on a hook, spec, or steering file to activate it
3. Files automatically apply when editing matching paths

**Example - Terraform Hook:**
```markdown
# Hook: Terraform Security Defaults

Apply these patterns when generating Terraform:
- Always enable encryption at rest (KMS)
- Use private subnets by default
- Enable VPC Flow Logs
- Add required tags: Environment, Owner, Project
```

**Benefits:**
- Per-file context injection
- Path-based automatic activation
- Visual file selector in IDE

### Amazon Q CLI

#### Agent-Based Workflow

**Files:** `~/.aws/amazonq/agent/`

Amazon Q CLI supports custom agents that are globally available across all projects.

**Setup:**
```bash
# Copy agent files to your home directory
cp -r terraform/.aws/amazonq ~/.aws/

# Directory structure
~/.aws/amazonq/
└── agent/
    └── terraform-action-agent/
        ├── agent-config.md
        ├── skills.md
        └── workflows.md
```

**Usage:**
```bash
# Start Q CLI
$ q

# Switch to Terraform agent
> /agent switch terraform-action-agent
Agent switched to: terraform-action-agent

# Now all prompts use Terraform context
> Create a secure VPC module with 3 AZs
[Agent generates HCL with security defaults...]

# List available agents
> /agent list

# Switch back to default
> /agent switch default
```

**Example - Agent Configuration:**
```markdown
# Terraform Action Agent

## Identity
Expert in generating secure, well-architected Terraform code

## Capabilities
- Generate HCL following best practices
- Apply security defaults automatically
- Query Terraform Registry for latest versions
- Validate and format code

## Default Behaviors
- Always enable encryption
- Use private networking
- Add comprehensive tags
- Include variable validation
```

**Benefits:**
- Global agent availability
- Persistent context across sessions
- Easy agent switching
- CLI-first workflow

### OpenAI Codex / Jules / Gemini CLI

#### AGENTS.md (Universal)

All modern coding agents support the `AGENTS.md` convention:

```markdown
# AGENTS.md

## Project: HashiCorp Infrastructure

### Available Skills
- terraform/skills/generate-hcl/ - Generate Terraform code
- terraform/skills/refactor-module/ - Extract modules
- vault/skills/generate-policy/ - Create Vault policies
- vault-radar/skills/scan-for-secrets/ - Scan for exposed secrets

### Workflows
- terraform/workflows/plan-and-apply-with-approval.md
- vault-radar/workflows/triage-and-remediate.md

### Testing
```bash
# Terraform
terraform fmt && terraform validate && tfsec .

# Vault
vault policy fmt policy.hcl && vault policy write test policy.hcl

# Vault Radar
vault-radar scan -d . -o json
```text

### Compliance
All generated code must:
- Encrypt data at rest and in transit
- Use private networking by default
- Include comprehensive logging
- Follow least-privilege access
```

#### Gemini CLI Specific

**File:** `.gemini/settings.json`
```json
{
  "contextFileName": "AGENTS.md"
}
```text

#### Aider Specific

**File:** `.aider.conf.yml`
```yaml
read: AGENTS.md
```

## 📋 Usage Patterns by Platform

### GitHub Copilot Patterns

#### Pattern 1: Direct Skill Reference
```text
@workspace Using terraform/skills/generate-hcl, create:
- AWS VPC with 3 AZs
- Public and private subnets
- NAT gateways per AZ
- VPC Flow Logs to S3

Environment: production
Compliance: CIS AWS Foundations
```

#### Pattern 2: Workflow Execution
```text
@workspace Follow terraform/workflows/plan-and-apply-with-approval.md

Changes: Adding RDS instance
Environment: production
Approvers: @senior-engineer
Slack: #infrastructure-changes
```

#### Pattern 3: Custom Agent
Create `.github/agents/terraform-expert.md`:
```markdown
---
name: terraform-expert
description: Terraform infrastructure specialist
tools: ["read", "edit", "search"]
---

You are a Terraform expert. Always:
1. Load terraform/prompts/system-prompt-tf.md
2. Use terraform/skills/generate-hcl/ for code generation
3. Run security scans before committing
4. Follow plan-and-apply-with-approval for production
```text

**Usage:**
```
# Select "terraform-expert" from agent dropdown
Create an RDS instance
```text

### Claude Patterns

#### Pattern 1: Skill Discovery
```
Create a secure S3 bucket for production use
```text
Claude automatically:
1. Scans available skills
2. Loads `generate-hcl` skill
3. Applies security defaults
4. Generates HCL code

#### Pattern 2: Explicit Skill Reference
```
Using the generate-hcl skill, create an AWS EKS cluster with:
- Private endpoint access
- Managed node groups
- Pod security policies
- Cluster autoscaling
```text

#### Pattern 3: Multi-Skill Workflow
```
1. Use scan-for-secrets skill to check this repository
2. Use triage-and-remediate workflow for any findings
3. Generate migration plan to Vault
4. Create Vault policies using generate-policy skill
```text

### Cursor Patterns

#### Pattern 1: Context-Aware Generation
```
# Cursor reads .cursorrules
# Automatically applies terraform/skills/generate-hcl/

Create VPC  # Cursor applies skill automatically
```text

#### Pattern 2: Explicit Workflow
```
@Apply terraform/workflows/security-scan-workflow.md
Scan: ./terraform/prod/
```text

#### Pattern 3: AGENTS.md Reference
```
# Cursor reads AGENTS.md on startup
# Instructions available in context

Generate database module per AGENTS.md standards
```text

## 🌟 Real-World Examples

### Example 1: Secure Multi-Tier Application (GitHub Copilot)

**Scenario:** Deploy production web application to AWS

**Prompt:**
```
@workspace Using terraform/skills/generate-hcl

Create production infrastructure:

Architecture:
- VPC across 3 AZs (us-east-1)
- Public subnets: ALB
- Private subnets: ECS Fargate
- Database subnets: Aurora PostgreSQL

Security (CIS Benchmark):
- All encryption at rest (KMS)
- All encryption in transit (TLS 1.2+)
- Private networking only
- VPC Flow Logs
- CloudTrail enabled
- WAF on ALB

High Availability:
- Multi-AZ RDS
- Auto-scaling ECS
- Multiple NAT Gateways

Cost Optimization:
- Tag all resources
- Use Savings Plans
- Lifecycle policies

Generate:
- Complete Terraform module
- README with architecture diagram
- Security scan configuration
- Cost estimation
```text

**Agent Actions:**
1. Loads `terraform/skills/generate-hcl/SKILL.md`
2. Queries AWS provider for latest version
3. Reads `hcl-best-practices.md`
4. Generates complete module structure
5. Applies CIS security defaults
6. Creates documentation

### Example 2: Vault Policy for Microservices (Claude)

**Scenario:** Create policies for 5 microservices

**Prompt:**
```
Using vault/skills/generate-policy, create policies for:

Services:
1. api-gateway
   - Read: secret/data/api/*
   - Create: auth/token/create (limited TTL)
   - Deny: everything else

2. user-service
   - Read: secret/data/users/*
   - Read: database/creds/user-db
   - Write: secret/data/users/cache/*
   - Deny: other services' secrets

3. payment-service (PCI compliant)
   - Read: secret/data/payment/*
   - Read: database/creds/payment-db
   - No list capability
   - Explicit deny: all other paths

4. notification-service
   - Read: secret/data/notification/*
   - Read: aws/creds/ses
   - No database access

5. admin-portal
   - Read: secret/metadata/*
   - List: secret/metadata/*
   - No secret data access
   - View only mode

Environment: production
Compliance: PCI DSS Level 1
Auth method: Kubernetes IRSA
```text

**Agent Actions:**
1. Loads `vault/skills/generate-policy/SKILL.md`
2. Applies least-privilege principle
3. Generates 5 separate policies
4. Includes explicit deny rules
5. Adds identity templating
6. Creates testing script

### Example 3: Secrets Remediation Pipeline (Cursor)

**Scenario:** Found 47 secrets in git history

**Prompt:**
```
Follow vault-radar/workflows/triage-and-remediate.md

Scan Results:
- 47 total findings
- 15 HIGH (API keys, DB passwords)
- 22 MEDIUM (tokens, certs)
- 10 LOW (example secrets)

Repositories:
- web-app (12 findings)
- backend-api (20 findings)
- infrastructure (8 findings)
- scripts (7 findings)

Required Actions:
1. Triage by severity and exposure
2. Rotate all HIGH findings immediately
3. Scrub git history
4. Migrate to Vault
5. Setup pre-commit hooks
6. Generate compliance report

Timeline: Complete within 24 hours
```text

**Agent Actions:**
1. Loads `vault-radar/workflows/triage-and-remediate.md`
2. Creates prioritized action plan
3. Generates rotation scripts
4. Creates Vault migration plan
5. Generates BFG Repo-Cleaner commands
6. Creates pre-commit hook configuration
7. Produces executive summary

## ✅ Best Practices

### 1. Start with System Prompts

**Always** load product-specific system prompts first:

```
@workspace Load terraform/prompts/system-prompt-tf.md

Now help me create infrastructure...
```text

**Why:** Sets correct expertise, behavior, and safety guardrails

### 2. Reference Skills Explicitly for Complex Tasks

```
# ❌ Vague
Create a database

# ✅ Specific
Using terraform/skills/generate-hcl, create:
- RDS PostgreSQL
- Multi-AZ enabled
- Encryption with KMS
- Automated backups (7 days)
- Private subnet placement
```text

### 3. Combine Skills and Workflows

```
@workspace 

Step 1: Use terraform/skills/generate-hcl to create EKS cluster
Step 2: Apply terraform/workflows/security-scan-workflow.md
Step 3: Follow terraform/workflows/plan-and-apply-with-approval.md
```text

### 4. Validate Agent Output

**Always run validation after generation:**

```bash
# Terraform
terraform fmt -check
terraform validate
tfsec .
checkov -d .

# Vault
vault policy fmt policy.hcl
vault policy write test policy.hcl

# Vault Radar
vault-radar scan -d .
```

### 5. Iterate and Refine

```text
# First attempt
@workspace Using generate-hcl, create S3 bucket

# Agent generates basic bucket

# Refine
Add versioning, lifecycle policy for 90 days, and KMS encryption

# Continue refining
Also add bucket policy preventing unencrypted uploads
```

## 🔧 Troubleshooting

### Issue: Agent Ignores Instructions

**Symptoms:**
- Generated code doesn't follow patterns
- Security defaults not applied
- Missing validation

**Solutions:**

1. **Be more explicit:**
```text
# ❌ Implicit
Create infrastructure

# ✅ Explicit
Using terraform/skills/generate-hcl/SKILL.md, create...
```

2. **Load instructions first:**
```text
@workspace Read terraform/skills/generate-hcl/SKILL.md completely
Then create...
```

3. **Reference multiple times:**
```text
Following terraform/skills/generate-hcl best practices,
create... ensure you apply security defaults from the skill.
```

### Issue: Skills Not Found (Claude)

**Symptoms:**
- "I don't have access to that skill"
- Skill not loaded automatically

**Solutions:**

1. **Install skills:**
```bash
cp -r terraform/skills ~/.claude/skills/terraform/
```text

2. **Reference full path:**
```
Using the skill at terraform/skills/generate-hcl/SKILL.md
```text

3. **Load manually:**
```
First, read terraform/skills/generate-hcl/SKILL.md
Then apply those patterns to create...
```text

### Issue: Prompt Files Not Working (GitHub Copilot)

**Symptoms:**
- #prompt-name not recognized
- Prompt files not showing in autocomplete

**Solutions:**

1. **Enable in settings:**
```json
{
  "chat.promptFiles": true
}
```

2. **Check file location:**
```bash
ls .github/prompts/
# Files must end with .prompt.md
```text

3. **Use direct reference:**
```
@workspace #file:.github/prompts/summarize-plan.prompt.md
```text

### Issue: AGENTS.md Not Loading (Cursor, etc.)

**Symptoms:**
- Instructions not applied automatically
- Agent unaware of project structure

**Solutions:**

1. **Verify file location:**
```bash
ls -la AGENTS.md
# Must be in project root
```

2. **Check format:**
```markdown
# AGENTS.md

## Section Headers Required
Content...
```text

3. **Restart IDE:**
Some platforms only load AGENTS.md on startup

## 📚 Additional Resources

### Documentation by Platform

- [GitHub Copilot Custom Instructions](https://docs.github.com/en/copilot/how-tos/configure-custom-instructions/add-repository-instructions)
- [Claude Skills](https://docs.claude.com/en/docs/agents-and-tools/agent-skills/overview)
- [Anthropic Skills Engineering](https://www.anthropic.com/engineering/equipping-agents-for-the-real-world-with-agent-skills)
- [AGENTS.md Specification](https://agents.md)
- [Cursor Documentation](https://cursor.com/docs)

### HashiCorp Product Documentation

- [Terraform](https://developer.hashicorp.com/terraform)
- [Vault](https://developer.hashicorp.com/vault)
- [Vault Radar](https://developer.hashicorp.com/vault/radar)
- [Consul](https://developer.hashicorp.com/consul)

### Community Resources

- [Awesome Copilot Customizations](https://github.com/github/awesome-copilot)
- [HashiCorp Learn](https://learn.hashicorp.com/)
- [Claude Cookbook](https://github.com/anthropics/claude-cookbooks/tree/main/skills)

---

## 🎓 Next Steps

1. **Choose your platform** (GitHub Copilot, Claude, Cursor, etc.)
2. **Follow the setup guide** for your platform
3. **Try a simple example** from this guide
4. **Gradually increase complexity** as you become comfortable
5. **Customize** instructions for your organization
6. **Share** learnings with your team

**Remember:** Instruction files are living documents. Update them as you learn what works best for your use cases!

---

For questions, please open an issue on GitHub or consult the [main README](README.md).

📋 **[View Changelog](CHANGELOG.md)** for version history and updates.
