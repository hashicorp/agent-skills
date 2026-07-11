# Specification: vault-credential-generation

**Status**: Published  
**Version**: 0.2.0

---

## Overview

This plugin helps you **generate dynamic credentials** for your applications. Covers database credentials (PostgreSQL, MySQL, MongoDB), cloud credentials (AWS, Azure, GCP), encryption keys (Transit), certificates (PKI), and secret delivery via Vault Agent.

---

## User Stories

### US-1: Developer Needs Dynamic Database Credentials (P1)

A developer building an application needs to connect to a PostgreSQL database without hardcoding credentials. They want Vault to generate short-lived database credentials automatically.

**Why this priority**: Dynamic secrets are Vault's core value proposition. This is the most common enterprise use case.

**Acceptance Criteria**:
1. Given a user asks about database credential management, when the skill is invoked, then it provides Database secrets engine setup with role configuration and lease/TTL guidance.
2. Given a developer wants to integrate Vault with their app, when they ask for code examples, then the skill provides CLI commands and SDK patterns.
3. Given a user mentions "dynamic secrets," when the skill is invoked, then it explains the concept and lists available dynamic secrets engines.

### US-2: Security Engineer Needs Encryption Without Key Management (P1)

A security engineer needs to encrypt sensitive data at rest but doesn't want the application to have access to encryption keys.

**Acceptance Criteria**:
1. Given a user asks about encryption, when the skill is invoked, then it provides Transit engine setup and encryption/decryption patterns.
2. Given a request for key rotation, when queried, then the skill explains key versioning and rotation procedures.
3. Given a BYOK question, when asked about importing keys, then the skill explains Transit BYOK process.

### US-3: Platform Engineer Needs PKI for Internal Services (P2)

A platform engineer needs to issue TLS certificates for internal services from an internal CA.

**Acceptance Criteria**:
1. Given a user asks about internal CA, when the skill is invoked, then it provides PKI secrets engine setup with root/intermediate CA configuration.
2. Given a certificate automation question, when queried, then the skill explains cert-manager integration and renewal patterns.
3. Given a cross-namespace PKI question, when asked about shared CAs, then the skill explains Enterprise patterns.

### US-4: Developer Needs Vault Agent for Secret Injection (P1)

A developer needs to inject secrets into application config files without modifying application code.

**Acceptance Criteria**:
1. Given a user asks about secret file templating, when the skill is invoked, then it provides Vault Agent configuration with template examples.
2. Given a sidecar question, when queried, then the skill explains Kubernetes sidecar patterns.
3. Given a process supervisor question, when asked about exec mode, then the skill explains process supervisor and env_template.
4. Given a PKI template question, when asked about certificates, then the skill explains the pkiCert template function.

### US-5: Security Team Enabling SSH Access (P3)

A security team needs to manage SSH access to infrastructure using Vault's SSH secrets engine.

**Acceptance Criteria**:
1. Given an SSH access question, when the skill is invoked, then it explains SSH secrets engine modes (OTP, CA, Dynamic Keys).
2. Given a CA mode request, when queried, then the skill provides SSH CA configuration with user and host certificate signing.
3. Given a post-implementation question, when asked, then the skill explains removing authorized_keys and configuring sshd trust.

---

## Functional Requirements

| ID | Requirement |
|----|-------------|
| FR-001 | Skill MUST cover KV v1 and v2 secrets engine with versioning |
| FR-002 | Skill MUST cover Database secrets engine for PostgreSQL, MySQL, MongoDB |
| FR-003 | Skill MUST explain dynamic roles vs static roles |
| FR-004 | Skill MUST cover Transit encryption with key rotation |
| FR-005 | Skill MUST cover PKI secrets engine with root/intermediate CA |
| FR-006 | Skill MUST cover SSH secrets engine (OTP, CA modes) |
| FR-007 | Skill MUST explain lease management and renewal |
| FR-008 | Skill MUST cover AWS, Azure, GCP credential generation |
| FR-009 | Skill MUST cover Vault Agent auto-auth, caching, templating |
| FR-010 | Skill MUST explain process supervisor mode and env_template |
| FR-011 | Skill MUST cover pkiCert template function |
| FR-012 | Skill MUST cover Secrets Sync (Enterprise) |

---

## Skills Included

| Skill | Description |
|-------|-------------|
| `secrets-engines` | Configure KV, Database, AWS, Transit, PKI, SSH secrets engines |
| `vault-agent` | Set up auto-auth, caching, templating, and process supervisor |

---

## Content Sources

- HashiCorp Vault Documentation
- Vault Tutorials
- CSA Enterprise Patterns (genericized)

---

## References

- [Vault Secrets Engines](https://developer.hashicorp.com/vault/docs/secrets)
- [Vault Agent](https://developer.hashicorp.com/vault/docs/agent-and-proxy/agent)
- [Database Secrets Engine](https://developer.hashicorp.com/vault/docs/secrets/databases)
- [Transit Secrets Engine](https://developer.hashicorp.com/vault/docs/secrets/transit)
