---
name: terraform-module-story-builder
description: >
  Help write and refine Agile user stories for infrastructure-as-code
  and Terraform modules. Focus on clear personas, goals, and value,
  even for highly technical work such as platform, security, and
  reusable modules.
metadata:
  domain: requirements
  tags: ["user-story", "iac", "terraform", "platform", "technical-story"]
---

# Purpose

When this skill is active, you help the user write or improve user stories
for infrastructure-as-code and platform work (e.g. Terraform modules,
cloud networking, security hardening, observability).

You keep the classic "As a / I want / so that" structure but adapt:
- personas to infra / dev / security roles,
- goals to infra capabilities and developer experience,
- value to reliability, security, speed, or maintainability.

# When to use this skill

Use this skill when:
- The user wants to describe work on Terraform modules, cloud infra,
  CI/CD, security or platform capabilities as user stories.
- The user has a rough technical requirement and wants it framed
  as a user story that is understandable, prioritizable, and testable.

Do NOT use this skill for:
- Non-infra product features targeting end-users of an app (use a generic
  product user-story skill instead).
- Low-level task lists without any user or value context (e.g. "rename a variable").

# Core principles

Always enforce these principles when writing stories:

1. **Persona is a real beneficiary**
   - Use roles like: "application developer", "platform engineer",
     "security engineer", "SRE", "data engineer", "team X developer". 
   - Avoid vague "As a system" or "As Terraform". Systems are not users.

2. **Goal is a capability, not an implementation**
   - "I want to provision a secure VPC via a reusable module", not
     "I want to write a Terraform file".
   - "I want to rotate secrets automatically", not
     "I want to configure a cronjob".

3. **Value is explicit and business- or risk-oriented**
   - "so that I reduce the risk of misconfigured networks",
   - "so that teams can deploy faster with fewer manual steps",
   - "so that we meet compliance requirements". 

4. **Stories should be INVEST where possible**
   - Independent, Negotiable, Valuable, Estimable, Small, Testable.

# Instructions

When using this skill, follow this process:

1. **Clarify context**
   - Ask 1–2 short questions if needed:
     - Who benefits most from this change? (role/team)
     - What capability do they need in terms of infra or modules?
     - What risk or pain are we reducing, or what outcome are we improving?
   - If context is already clear, skip questions and proceed.

2. **Draft the core user story**

Use this template:

> As a <persona>,  
> I want <capability or outcome>,  
> so that <value, risk reduction, or measurable benefit>.

Rules:
- Persona = human role (e.g. "application developer in team X", 
  "platform engineer", "security officer").
- Capability = something they can now do using infra or a module
  (provision, observe, secure, recover, audit, etc.).
- Value = framed in terms of speed, safety, stability, compliance,
  developer experience, or cost.

3. **Adapt for Terraform / IaC modules**

When the user mentions Terraform or modules, make the story more specific:

- Mention the module or area at a high level:
  - "via a standardized Terraform module",
  - "using our shared VPC module",
  - "through an automated pipeline".
- Keep it at the level of "what I can do", not "how the module is implemented".

Examples:
- "As an application developer, I want to create application networks via a standard Terraform VPC module so that I don't have to understand low-level cloud networking details."
- "As a security engineer, I want all S3 buckets provisioned via our storage module to be encrypted and private by default so that we reduce the risk of data exposure."

4. **Output format**

Always respond in this structure:

```md
## User story

As a <persona>,  
I want <capability or outcome>,  
so that <value / risk reduction / benefit>.

## Context (optional)

- Domain: <e.g. Terraform module, networking, security, CI/CD>
- Primary beneficiary: <role/team>
- Notes: <any important constraints>

```

5. **Keep it small and focused**

If the described work is too large or mixes multiple capabilities:
- Propose a split into 2–3 smaller stories, each with its own persona,
  goal, and value.
- Make sure each story can be scoped to something completable within one iteration.

6. **Avoid common anti-patterns**

Watch out for:
- Stories without a real "so that" (no clear value).
- "As a developer, I want to refactor X…" without explaining why 
  (maintainability, performance, risk reduction, etc.).
- Stories that are really tasks (e.g. "As Terraform, I want a module…"
  or "As a system, I want to create a VPC").
