# Specification: vault-operations

**Status**: Published  
**Version**: 0.2.0

---

## Overview

This plugin provides skills for deploying Vault in Kubernetes, operating production clusters, and troubleshooting issues. Covers HA architecture, disaster recovery, monitoring, upgrades, and common operational patterns.

---

## User Stories

### US-1: Platform Engineer Deploying Vault on Kubernetes (P1)

A platform engineer needs to deploy Vault on Kubernetes and integrate it with application workloads using Vault Secrets Operator.

**Acceptance Criteria**:
1. Given a user asks about Kubernetes deployment, when the skill is invoked, then it provides VSO, Agent Injector, or CSI options with trade-offs.
2. Given a VSO configuration question, when queried, then the skill provides VaultAuth, VaultStaticSecret, and VaultDynamicSecret CRD examples.
3. Given an Agent Injector question, when asked, then the skill explains annotation-based injection with complete annotation reference.
4. Given a selection question, when asked which to use, then the skill provides a decision matrix for VSO/CSI/Injector selection.

### US-2: Architect Designing HA/DR Deployment (P1)

A solutions architect needs to design a highly available Vault deployment with disaster recovery capabilities.

**Why this priority**: Enterprise Vault deployments require HA and DR for production readiness.

**Acceptance Criteria**:
1. Given an HA architecture question, when the skill is invoked, then it explains 5-node Raft clusters with 3-AZ distribution (2-2-1 pattern).
2. Given a DR question, when queried, then it explains replication types, DR failover procedures, and batch token portability.
3. Given an auto-unseal question, when asked about options, then the skill explains Cloud KMS, HSM, and Transit unseal with Seal HA (1.16+).
4. Given a cluster sizing question, when asked, then the skill provides instance sizing recommendations.

### US-3: Operations Engineer Monitoring Vault (P2)

An operations engineer needs to set up monitoring, alerting, and backup procedures for production Vault.

**Acceptance Criteria**:
1. Given a monitoring question, when the skill is invoked, then it provides critical metrics and alert thresholds.
2. Given a backup question, when queried, then the skill explains Raft snapshots and automated backup procedures.
3. Given an upgrade question, when asked, then the skill provides Autopilot rolling upgrade procedures.
4. Given an audit question, when asked about logging, then the skill explains multiple audit devices and privileged endpoint monitoring.

### US-4: SRE Troubleshooting Vault Issues (P1)

An SRE needs to diagnose why Vault is returning errors, failing to authenticate clients, or responding slowly.

**Why this priority**: Production troubleshooting is a common, high-stress scenario where accurate guidance is critical.

**Acceptance Criteria**:
1. Given a user reports Vault errors, when the skill is invoked, then it provides systematic troubleshooting steps (seal status, leader election, storage health, audit logs).
2. Given an authentication failure, when asked for help, then the skill identifies common causes and solutions.
3. Given performance issues, when queried, then the skill suggests metrics analysis, connection pooling, and caching strategies.
4. Given an anti-patterns question, when asked, then the skill lists common operational anti-patterns to avoid.

---

## Functional Requirements

| ID | Requirement |
|----|-------------|
| FR-001 | Skill MUST cover VSO with VaultAuth, VaultStaticSecret, VaultDynamicSecret CRDs |
| FR-002 | Skill MUST cover Agent Injector with complete annotation reference |
| FR-003 | Skill MUST cover CSI Provider with SecretProviderClass |
| FR-004 | Skill MUST include VSO/CSI/Injector decision matrix |
| FR-005 | Skill MUST cover 5-node Raft HA with 3-AZ distribution |
| FR-006 | Skill MUST explain auto-unseal options (KMS, HSM, Transit) |
| FR-007 | Skill MUST cover Seal HA (1.16+) configuration |
| FR-008 | Skill MUST include DR failover procedures |
| FR-009 | Skill MUST cover Autopilot for rolling upgrades |
| FR-010 | Skill MUST cover automated Raft snapshots |
| FR-011 | Skill MUST explain critical monitoring metrics |
| FR-012 | Skill MUST cover multiple audit devices requirement |
| FR-013 | Skill MUST list privileged endpoints to monitor |
| FR-014 | Skill MUST include troubleshooting decision trees |
| FR-015 | Skill MUST cover operational anti-patterns |

---

## Skills Included

| Skill | Description |
|-------|-------------|
| `kubernetes-integration` | VSO, Agent Injector, CSI Provider configuration |
| `production-operations` | HA, DR, monitoring, backup, upgrades |
| `troubleshooting` | Diagnose seal, auth, permission, and performance issues |

---

## Content Sources

- HashiCorp Vault Documentation
- Vault Tutorials
- CSA Enterprise Patterns (genericized)

---

## References

- [Vault on Kubernetes](https://developer.hashicorp.com/vault/docs/platform/k8s)
- [Vault Secrets Operator](https://developer.hashicorp.com/vault/docs/platform/k8s/vso)
- [Vault Agent Injector](https://developer.hashicorp.com/vault/docs/platform/k8s/injector)
- [Integrated Storage (Raft)](https://developer.hashicorp.com/vault/docs/configuration/storage/raft)
- [Vault Telemetry](https://developer.hashicorp.com/vault/docs/internals/telemetry)
