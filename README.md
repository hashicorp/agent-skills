# Agent Instructions Library for HashiCorp Stack

> **AI agent instructions for Terraform, Vault, Vault Radar, and Consul - Works with GitHub Copilot, Claude, Cursor, Amazon Kiro, Amazon Q CLI, and any AI coding assistant**

[![Documentation](https://img.shields.io/badge/docs-latest-blue.svg)](https://github.com/hashicorp/agent-instructions-library)
[![License](https://img.shields.io/badge/license-MPL%202.0-green.svg)](LICENSE)

## 🎯 What This Is

Pre-built instruction sets that teach AI agents HashiCorp best practices, security patterns, and workflows. Copy files → Reference in prompts → Get quality code.

```text
┌──────────────────────────────────────────────────────────────┐
│             🎯 HashiCorp Instructions Library                │
├──────────────────────────────────────────────────────────────┤
│                                                              │
│  Terraform        Vault          Vault Radar      Consul     │
│  └─ Skills        └─ Skills      └─ Skills        └─ Skills  │
│  └─ Workflows     └─ Workflows   └─ Workflows     └─ ...     │
│  └─ Prompts       └─ Prompts     └─ Prompts                  │
│                                                              │
└───┬─────────────┬─────────────┬─────────────┬───────────────┘
    │             │             │             │
    ▼             ▼             ▼             ▼
┌──────────┐ ┌─────────┐ ┌─────────┐ ┌────────────┐
│ Copilot  │ │ Claude  │ │ Cursor  │ │ Amazon     │
│ .github/ │ │~/.claude│ │AGENTS.md│ │ Kiro/Q CLI │
└──────────┘ └─────────┘ └─────────┘ └────────────┘
```


## 📁 Repository Structure

```
agent-instructions-library/
│
├── .github/copilot-instructions.md ◄─ GitHub Copilot (auto-loaded)
│
├── terraform/                       ◄─ Terraform Instructions
│   ├── skills/generate-hcl/         • Generate production HCL
│   ├── skills/refactor-module/      • Extract reusable modules
│   ├── workflows/plan-and-apply-*.md
│   └── prompts/system-prompt-tf.md
│
├── vault/                           ◄─ Vault Instructions
│   ├── skills/generate-policy/      • Create ACL policies
│   ├── skills/read-secret-securely/ • Secure secret handling
│   └── workflows/new-kv-engine-setup.md
│
├── vault-radar/                     ◄─ Vault Radar Instructions
│   ├── skills/scan-for-secrets/     • Detect exposed secrets
│   ├── skills/integrate-mcp-server/ • MCP integration
│   └── workflows/triage-and-remediate.md
│
└── consul/                          ◄─ Consul Instructions
    └── skills/configure-service-mesh/

📘 Detailed guides: terraform/README.md, vault/README.md, etc.
```



## 🚀 Platform Integration Guide

### How Each Platform Uses Instructions

```text
┌──────────────────────────────────────────────────────────────────────┐
│                    PLATFORM INSTRUCTION MATRIX                        │
├─────────────┬──────────────────┬────────────────┬─────────────────────┤
│  Platform   │  Primary Files   │  Auto-Loaded?  │  Invocation         │
├─────────────┼──────────────────┼────────────────┼─────────────────────┤
│ GitHub      │ .github/         │      YES       │ @workspace          │
│ Copilot     │   copilot-       │   Repository   │ #file:path/to/skill │
│             │   instructions   │     Always     │                     │
│             │ .github/         │       NO       │ #prompt-name        │
│             │   prompts/*.md   │  On-demand     │                     │
├─────────────┼──────────────────┼────────────────┼─────────────────────┤
│ Claude      │ */skills/*/      │      YES       │ "Using X skill..."  │
│             │   SKILL.md       │  Progressive   │ Auto-discovery      │
│             │                  │  disclosure    │                     │
├─────────────┼──────────────────┼────────────────┼─────────────────────┤
│ Cursor      │ AGENTS.md        │      YES       │ Automatic           │
│             │ .cursorrules     │   On startup   │ @Apply              │
├─────────────┼──────────────────┼────────────────┼─────────────────────┤
│ Amazon Kiro │ .kiro/           │      YES       │ Click hook/spec     │
│             │   hooks/         │   Per file     │ in Kiro tab         │
│             │   specs/         │                │                     │
│             │   steering/      │                │                     │
├─────────────┼──────────────────┼────────────────┼─────────────────────┤
│ Amazon Q    │ ~/.aws/amazonq/  │      YES       │ /agent switch       │
│ CLI         │   agent/         │   Global       │ terraform-action-   │
│             │                  │                │ agent               │
├─────────────┼──────────────────┼────────────────┼─────────────────────┤
│ Codex/      │ AGENTS.md        │      YES       │ Automatic           │
│ Jules/      │ CLAUDE.md        │   On startup   │ Reference in prompt │
│ Generic     │ GEMINI.md        │                │                     │
└─────────────┴──────────────────┴────────────────┴─────────────────────┘
```

### GitHub Copilot: File-Based Loading

```text
Your Project                          GitHub Copilot
┌────────────────────┐                ┌────────────────────┐
│ .github/           │                │                    │
│ ├─ copilot-        │───────────────►│ Always loaded      │
│ │  instructions.md │  Auto-loads    │ Repository context │
│ │                  │                │                    │
│ ├─ instructions/   │                ├────────────────────┤
│ │  └─ *.tf.md      │───────────────►│ When editing *.tf  │
│ │                  │  applyTo:      │ Path-specific      │
│ │                  │                │                    │
│ └─ prompts/        │                ├────────────────────┤
│    └─ *.prompt.md  │───────────────►│ When referenced    │
│                    │  #prompt-name  │ #file:path         │
└────────────────────┘                └────────────────────┘

Setup (one-time):
$ cp .github/copilot-instructions.md .github/
$ cp terraform/prompts/*.md .github/prompts/

Usage:
@workspace Using terraform/skills/generate-hcl, create a VPC
@workspace #terraform-review #file:main.tf
```

### Claude: Skills-Based Discovery

```text
Repository Structure                  Claude Agent
┌────────────────────┐                ┌────────────────────┐
│ terraform/skills/  │                │ Level 1: Metadata  │
│ ├─ generate-hcl/   │───────────────►│ ---                │
│ │  ├─ SKILL.md     │  Scans all     │ name: generate-hcl │
│ │  └─ resources/   │  SKILL.md      │ description: ...   │
│ │                  │                │ ---                │
│ vault/skills/      │                ├────────────────────┤
│ └─ generate-policy/│───────────────►│ Level 2: Full Skill│
│    ├─ SKILL.md     │  If relevant   │ (entire SKILL.md)  │
│    └─ resources/   │───────────────►│                    │
│                    │  If needed     │ Level 3: Resources │
│                    │                │ (resources/*.md)   │
└────────────────────┘                └────────────────────┘

Setup (automatic):
• Claude auto-discovers SKILL.md files in repository
• Progressive disclosure: loads only what's needed

Usage:
"Using the generate-hcl skill, create an RDS instance"
(Claude finds and loads terraform/skills/generate-hcl/SKILL.md)
```

### Cursor: Root-Level Configuration

```text
Your Project                          Cursor
┌────────────────────┐                ┌────────────────────┐
│ AGENTS.md          │───────────────►│ Loaded on startup  │
│ (or .cursorrules)  │  Root file     │ Always active      │
│                    │                │                    │
│ Contains:          │                ├────────────────────┤
│ - Skill paths      │                │ Auto-applied to:   │
│ - Workflow refs    │                │ • Code generation  │
│ - Best practices   │                │ • @Apply commands  │
│                    │                │ • Context requests │
└────────────────────┘                └────────────────────┘

Setup (create AGENTS.md):
$ cat > AGENTS.md <<EOF
# Skills Available
- terraform/skills/generate-hcl/ - Generate Terraform
- vault/skills/generate-policy/ - Create policies

# Reference
See .github/copilot-instructions.md for details
EOF

Usage:
"Create a VPC" → Cursor auto-uses terraform/skills/generate-hcl/
@Apply terraform/workflows/plan-and-apply-with-approval.md
```

### Amazon Kiro: Hook-Based Context

```text
Your Project                          Amazon Kiro
┌────────────────────┐                ┌────────────────────┐
│ .kiro/             │                │                    │
│ ├─ hooks/          │───────────────►│ Pre/post file ops  │
│ │  └─ *.md         │  Per-file      │ Context injection  │
│ │                  │                │                    │
│ ├─ specs/          │───────────────►│ File generation    │
│ │  └─ *.md         │  Templates     │ Specifications     │
│ │                  │                │                    │
│ └─ steering/       │───────────────►│ Agent behavior     │
│    └─ *.md         │  Guidelines    │ Instructions       │
└────────────────────┘                └────────────────────┘

Setup (copy to project):
$ cp -r terraform/.kiro/ .kiro/

Usage:
1. Open Kiro tab in your editor
2. Click on hook, spec, or steering file to activate
3. Files auto-apply when editing matching paths
```

### Amazon Q CLI: Agent-Based Workflow

```text
User Directory                        Amazon Q CLI
┌────────────────────┐                ┌────────────────────┐
│ ~/.aws/amazonq/    │                │                    │
│ └─ agent/          │───────────────►│ Custom agents      │
│    └─ terraform-   │  Global config │ terraform-action-  │
│       action-agent/│                │ agent available    │
│       └─ *.md      │                │                    │
└────────────────────┘                └────────────────────┘

Setup (copy to home directory):
$ cp -r terraform/.aws/amazonq ~/.aws/

Usage:
$ q
> /agent switch terraform-action-agent
Agent switched to: terraform-action-agent
> Create a secure VPC module
```

### Universal Setup (Any AI Agent)

```text
┌────────────────────────────────────────────────────────────┐
│              Universal AGENTS.md Strategy                  │
├────────────────────────────────────────────────────────────┤
│                                                            │
│  Step 1: Create AGENTS.md in project root                  │
│          ├─ List all available skills                      │
│          ├─ List workflows                                 │
│          └─ Reference this library                         │
│                                                            │
│  Step 2: Reference in prompts                              │
│          "Read terraform/skills/generate-hcl/SKILL.md..."  │
│                                                            │
│  Step 3: (Optional) Create platform-specific files         │
│          ├─ CLAUDE.md → symlink to AGENTS.md               │
│          └─ GEMINI.md → symlink to AGENTS.md               │
│                                                            │
└────────────────────────────────────────────────────────────┘

Works with: OpenAI Codex, Google Jules, Gemini CLI, Aider, etc.
```

### Platform Decision Tree

```text
                      Which AI assistant?
                             │
        ┌────────────────────┼────────────────────┐
        │                    │                    │
        ▼                    ▼                    ▼
    VS Code            Claude App          Amazon Tools
        │                    │                    │
        ▼                    ▼                    ▼
┌──────────────┐  ┌───────────────┐  ┌───────────────────┐
│ GitHub       │  │ Skills auto-  │  │ Kiro or Q CLI?    │
│ Copilot      │  │ discovered    │  │                   │
├──────────────┤  ├───────────────┤  ├───────────────────┤
│ Copy to:     │  │ No setup!     │  │ Kiro: .kiro/      │
│ .github/     │  │               │  │  to project root  │
│ copilot-     │  │ Just use:     │  │                   │
│ instructions │  │ "Using the    │  │ Q CLI: ~/.aws/    │
│              │  │  X skill..."  │  │  amazonq/         │
└──────────────┘  └───────────────┘  └───────────────────┘
        │                    │                    │
        └────────────────────┼────────────────────┘
                             │
                             ▼
                    ┌─────────────────┐
                    │ Other (Cursor,  │
                    │ Codex, Jules)   │
                    ├─────────────────┤
                    │ Create          │
                    │ AGENTS.md       │
                    │ List skills     │
                    │ & workflows     │
                    └─────────────────┘
```



## 📚 Instruction File Types

### Skills (`SKILL.md`) - Discrete Capabilities

```text
┌─────────────────────────────────────┐
│ # Skill: Generate HCL               │  ◄─ Clear title
│                                     │
│ ## Overview                         │  ◄─ High-level description
│ ## Capability Statement             │  ◄─ What agent will do
│ ## Prerequisites                    │  ◄─ Required setup
│ ## Execution Steps                  │  ◄─ Detailed steps
│ ## Examples                         │  ◄─ Usage examples
└─────────────────────────────────────┘
```

**Examples:** Generate HCL code, Create Vault policies, Scan for secrets  
**Location:** `product/skills/skill-name/SKILL.md`  
**Usage:** `"Using the generate-hcl skill, create..."`

### Workflows (`*.md`) - Multi-Step Processes

```text
Step 1: Init    →    Step 2: Plan    →    Step 3: Review
                                                 │
                                            Approved?
                                                 │
                                           Yes   │   No
                                            │    │    │
Step 6: Verify  ←  Step 5: Apply  ←  ─────┘    └→ Stop
```

**Examples:** Plan→Approve→Apply, Scan→Triage→Remediate  
**Location:** `product/workflows/workflow-name.md`  
**Usage:** `"Follow the plan-and-apply-with-approval workflow"`

### Prompts (`*.md`) - Reusable Templates

**Examples:** Summarize Terraform plan, Analyze scan results, Review for security  
**Location:** `product/prompts/prompt-name.md`  
**Usage:** `#prompt-name` (Copilot) or reference explicitly


## 🔌 Platform Compatibility

| Platform | Skills | Workflows | Prompts | System Prompts | Notes |
|----------|--------|-----------|---------|----------------|-------|
| **GitHub Copilot** | ✅ | ✅ | ✅ | ✅ | Via `.github/copilot-instructions.md` and prompt files |
| **Claude** | ✅ | ✅ | ✅ | ✅ | Native SKILL.md format support |
| **Cursor** | ✅ | ✅ | ✅ | ✅ | Via AGENTS.md and .cursorrules |
| **OpenAI Codex** | ✅ | ✅ | ✅ | ✅ | Via AGENTS.md |
| **Google Jules** | ✅ | ✅ | ✅ | ✅ | Via AGENTS.md or GEMINI.md |
| **VS Code Copilot** | ✅ | ✅ | ✅ | ✅ | Chat modes and prompt files |
| **JetBrains AI** | ✅ | ✅ | ✅ | ✅ | Custom instructions support |

### Cross-Platform Setup

**Symlink Strategy for Maximum Compatibility:**

```bash
# Create AGENTS.md pointing to main instructions
ln -s .github/copilot-instructions.md AGENTS.md

# Create CLAUDE.md for Claude-specific usage
ln -s .github/copilot-instructions.md CLAUDE.md

# Create GEMINI.md for Google Jules
ln -s .github/copilot-instructions.md GEMINI.md
```


## ⚡ Quick Start Examples

### Example 1: Generate Terraform Infrastructure (GitHub Copilot)

```
@workspace Using terraform/skills/generate-hcl/, create:
- VPC with public/private subnets
- RDS PostgreSQL in private subnet
- Application load balancer

Environment: production, Region: us-east-1
```

**What happens:** Copilot loads `.github/copilot-instructions.md` → References generate-hcl skill → Generates secure, well-structured HCL

### Example 2: Create Vault Policy (Claude)

```
Using the generate-policy skill, create a policy for:
- Service: web-application
- Access: read secret/data/app/web/prod/*
- Deny: all other paths
```

**What happens:** Claude discovers `vault/skills/generate-policy/SKILL.md` → Loads skill → Generates least-privilege policy

### Example 3: Remediate Secrets (Any Agent with AGENTS.md)

```
Follow vault-radar/workflows/triage-and-remediate.md:
1. Analyze last scan (47 findings)
2. Prioritize by severity
3. Generate remediation plan
```

**What happens:** Agent reads AGENTS.md → Finds workflow → Executes multi-step process



## � Learn More

### Product-Specific Guides
- **[Terraform Guide](terraform/README.md)** - Deep-dive into Terraform skills and workflows
- **[Vault Guide](vault/README.md)** - Vault policies and secret management
- **[Vault Radar Guide](vault-radar/README.md)** - Secrets detection and remediation
- **[Consul Guide](consul/README.md)** - Service mesh configuration

### Platform Documentation
- [GitHub Copilot Custom Instructions](https://docs.github.com/en/copilot/how-tos/configure-custom-instructions/add-repository-instructions)
- [Claude Skills](https://docs.claude.com/en/docs/agents-and-tools/agent-skills/overview)
- [AGENTS.md Specification](https://agents.md)
- [Anthropic Skills Engineering Blog](https://www.anthropic.com/engineering/equipping-agents-for-the-real-world-with-agent-skills)

### Advanced Guides
- **[USAGE_GUIDE.md](USAGE_GUIDE.md)** - Detailed platform-specific setup and real-world examples
- **[VISUAL_GUIDE.md](VISUAL_GUIDE.md)** - Comprehensive diagrams and flowcharts

---

💡 **Questions?** [Open an issue](https://github.com/hashicorp/agent-instructions-library/issues) | 📋 [View Changelog](CHANGELOG.md) | 📄 **License:** MPL 2.0
