# Specification: vault-multi-tenancy

**Status**: Published  
**Version**: 0.2.0

---

## Overview

This plugin helps you **set up multi-tenant Vault** environments. Covers namespaces for tenant isolation, cross-datacenter replication (Performance and DR), policy-as-code with Sentinel, multi-factor authentication (MFA), and HSM integration. **Requires Vault Enterprise license.**

---

## User Stories

### US-1: Architect Designing Multi-Tenant Vault (P1)

An enterprise architect needs to design a multi-tenant Vault deployment where different business units have isolated secrets and independent administration.

**Acceptance Criteria**:
1. Given a user asks about tenant isolation, when the skill is invoked, then it provides namespace design patterns with recommended hierarchy.
2. Given a question about namespace limits, when queried, then the skill explains the ~4,600 namespace limit and strategies for large deployments.
3. Given an anti-pattern query, when asked about deep nesting, then the skill explains why to avoid >3 levels.

### US-2: Security Engineer Implementing Policy-as-Code (P1)

A security engineer needs to implement Sentinel policies for compliance requirements that go beyond standard ACL policies.

**Acceptance Criteria**:
1. Given a request for compliance controls, when the skill is invoked, then it provides Sentinel policy examples for common requirements.
2. Given a question about policy types, when queried, then the skill differentiates EGP (Endpoint Governing Policies) vs RGP (Role Governing Policies).
3. Given a debugging scenario, when a policy fails, then the skill provides simulation and testing approaches.

### US-3: Operations Engineer Configuring Replication (P2)

An operations engineer needs to configure Performance Replication for read scaling and Disaster Recovery replication for business continuity.

**Acceptance Criteria**:
1. Given a replication architecture question, when the skill is invoked, then it explains DR vs PR differences with use cases.
2. Given a failover question, when asked about DR promotion, then the skill provides step-by-step DR failover procedure.
3. Given a token question, when asked about cross-cluster tokens, then the skill explains batch token portability.

### US-4: Identity Admin Configuring MFA (P2)

An identity administrator needs to configure multi-factor authentication for sensitive operations in Vault.

**Acceptance Criteria**:
1. Given an MFA configuration request, when the skill is invoked, then it differentiates Login MFA vs Step-up MFA.
2. Given a TOTP question, when asked about authenticator apps, then the skill provides TOTP configuration with code examples.
3. Given a policy question, when asked about requiring MFA, then the skill shows policy syntax for MFA enforcement.

### US-5: Security Engineer Integrating HSM (P3)

A security engineer in a regulated environment needs to integrate Vault with an HSM for seal/unseal and cryptographic operations.

**Acceptance Criteria**:
1. Given an HSM question, when the skill is invoked, then it explains HSM integration options (PKCS#11).
2. Given an auto-unseal question, when queried about HSM vs cloud KMS, then the skill provides trade-offs.
3. Given a compliance question, when asked about FIPS 140-2, then the skill explains HSM requirements.

---

## Functional Requirements

| ID | Requirement |
|----|-------------|
| FR-001 | Skill MUST cover namespace design patterns and anti-patterns |
| FR-002 | Skill MUST include namespace hierarchy recommendations |
| FR-003 | Skill MUST explain namespace limits (~4,600 with default mount table) |
| FR-004 | Skill MUST cover Performance Replication configuration |
| FR-005 | Skill MUST cover Disaster Recovery Replication setup |
| FR-006 | Skill MUST include DR failover procedures |
| FR-007 | Skill MUST differentiate batch tokens for replication |
| FR-008 | Skill MUST cover Sentinel EGP and RGP policies |
| FR-009 | Skill MUST include Login MFA vs Step-up MFA |
| FR-010 | Skill MUST cover HSM/PKCS#11 integration |
| FR-011 | Skill MUST include Control Groups for approval workflows |

---

## Skills Included

| Skill | Description |
|-------|-------------|
| `enterprise-features` | Configure namespaces, replication, Sentinel, MFA, HSM, and Control Groups |

---

## Non-Functional Requirements

### NFR-1: Enterprise License Clarity

All features MUST be clearly marked as requiring Vault Enterprise license.

### NFR-2: Version Compatibility

Features MUST note minimum Vault version requirements (e.g., Seal HA requires 1.16+).

---

## References

- [Vault Enterprise Documentation](https://developer.hashicorp.com/vault/docs/enterprise)
- [Namespaces](https://developer.hashicorp.com/vault/docs/enterprise/namespaces)
- [Replication](https://developer.hashicorp.com/vault/docs/enterprise/replication)
- [Sentinel Policies](https://developer.hashicorp.com/vault/docs/enterprise/sentinel)
- [MFA](https://developer.hashicorp.com/vault/docs/enterprise/mfa)
