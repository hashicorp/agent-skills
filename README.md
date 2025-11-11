# Agent Instructions Library for HashiCorp Stack

> **AI agent instructions for Terraform, Vault, Vault Radar, and Consul - Works with GitHub Copilot, Claude, Cursor, Amazon Kiro, Amazon Q CLI, and any AI coding assistant**

[![Documentation](https://img.shields.io/badge/docs-latest-blue.svg)](https://github.com/hashicorp/agent-instructions-library)
[![License](https://img.shields.io/badge/license-MPL%202.0-green.svg)](LICENSE)

## What's the purpose of this repository?

This repository hosts pre-built instruction sets that teach AI agents HashiCorp best practices, security patterns, and workflows. Copy files → Reference in prompts → Get quality code. Edit them as needed.

```text
┌──────────────────────────────────────────────────────────────┐
│                HashiCorp Instructions Library                │
├──────────────────────────────────────────────────────────────┤
│                                                              │
│  Terraform        Vault          Vault Radar      Consul     │
│  └─ Skills        └─ Skills      └─ Skills        └─ Skills  │
│  └─ Workflows     └─ Workflows   └─ Workflows     └─ ...     │
│  └─ Prompts       └─ Prompts     └─ Prompts                  │
│                                                              │
└───┬─────────────┬─────────────┬─────────────┬────────────────┘
    │             │             │             │
    ▼             ▼             ▼             ▼
┌──────────┐ ┌─────────┐ ┌─────────┐ ┌────────────┐
│ Copilot  │ │ Claude  │ │ Cursor  │ │ Amazon     │
│ .github/ │ │~/.claude│ │AGENTS.md│ │ Kiro/Q CLI │
└──────────┘ └─────────┘ └─────────┘ └────────────┘
```

## Platform Instruction Matrix

| Platform | Primary Files | Auto-Loaded? | Invocation | Notes |
|----------|---------------|--------------|------------|-------|
| **GitHub Copilot** | `.github/copilot-instructions.md`<br>`.github/prompts/*.md` | YES | VS Code, JetBrains, Visual Studio - Auto-loaded repository context |(repository)<br>NO (on-demand) | `@workspace`<br>`#file:path/to/skill`<br>`#prompt-name` |
| **Claude** | `*/skills/*/SKILL.md` | YES (progressive disclosure) | `"Using X skill..."`<br>Auto-discovery | Native SKILL.md support - Progressive disclosure |
| **Cursor** | `AGENTS.md`<br>`.cursorrules` | YES (on startup) | Automatic<br>`@Apply` | MCP servers, auto-loaded on startup |
| **Amazon Kiro** | `.kiro/hooks/`<br>`.kiro/specs/`<br>`.kiro/steering/` | YES (per file) | Click hook/spec in Kiro tab | Hook-based context injection per file |
| **Amazon Q CLI** | `~/.aws/amazonq/agent/` | YES (global) | `/agent switch terraform-action-agent` | Agent-based global configuration |
| **Gemini** | `GEMINI.md`<br>`gemini-extension.json` | YES (on startup) | Automatic<br>Reference in prompt | Gemini CLI |
| **Codex/Jules/Generic** | `AGENTS.md` | YES (on startup) | Automatic<br>Reference in prompt | VS Code/JetBrains extension |

## Quick Start Examples

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

## How Each Platform Uses Instructions

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

Think of AGENTS.md as a README for agents: a dedicated, predictable place to provide the context and instructions to help AI coding agents work on your project.

Works with: Cursor, GitHub CoPilot, gemini-cli, Amp, Devin, Warp, Zed, Cursor, opencode, codex and other AI coding assistants

```text
┌────────────────────────────────────────────────────────────┐
│              Universal AGENTS.md Strategy                  │
├────────────────────────────────────────────────────────────┤
│                                                            │
│  Step 1: Create AGENTS.md in project root                  │
│          ├─ List all available skills                      │
│          ├─ List workflows                                 │
│          └─ Use custom instructions                        │
│                                                            │
│  Step 2: Coding Agent automatically picks up instructions  │
│                                                            │
└────────────────────────────────────────────────────────────┘

```

## Instruction File Types

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

## Learn More

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

---

**Questions?** [Open an issue](https://github.com/hashicorp/agent-instructions-library/issues) | [View Changelog](CHANGELOG.md) | **License:** MPL 2.0
