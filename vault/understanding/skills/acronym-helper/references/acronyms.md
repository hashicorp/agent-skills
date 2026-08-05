# Vault Acronyms and Terminology Reference

## Table of Contents
- [Acronyms](#acronyms)
- [Style & Usage Rules](#style--usage-rules)
- [Vault Terms and Concepts](#vault-terms-and-concepts)

---

## Acronyms

| Acronym | Expansion | Meaning |
|---------|-----------|---------|
| **ACME** | Automatic Certificate Management Environment | Protocol for automated certificate issuance |
| **ADP** | Advanced Data Protection | Vault Enterprise module for protecting secrets in external systems |
| **BYOK** | Bring Your Own Key | Customers generate/manage keys locally |
| **CLM** | Certificate Lifecycle Management | Certificate creation, revocation, expiration |
| **DEK** | Data Encryption Key | Vault's encryption key, protected by root key |
| **DR** | Disaster Recovery | Strategies for site/datacenter failover |
| **EGP** | Endpoint Governing Policy | Sentinel policy for specific Vault path (Enterprise) |
| **EMR** | Electronic Medical Record | Digital clinical data (e.g., Epic) |
| **FDE** | Full Disk Encryption | Encrypts all data on disk |
| **FIPS** | Federal Information Processing Standard | US/Canadian crypto standards |
| **FPE** | Format Preserving Encryption | Ciphertext preserves input format |
| **FSM** | Finite State Machine | Deterministic state machine for log ordering |
| **GDPR** | General Data Protection Regulation | EU data protection regulation |
| **GRC** | Governance, Risk and Compliance | Strategy combining governance, risk, compliance |
| **HIPAA** | Healthcare Insurance Portability and Accountability Act | US healthcare data protection |
| **HVD** | HCP Vault Dedicated | HashiCorp-managed Vault Enterprise on HCP |
| **HVE** | HashiCorp Vault Enterprise | Self-managed Vault Enterprise |
| **HVS** | HCP Vault Secrets | Cloud-native secrets management service |
| **KEK** | Key Encryption Key | Key that encrypts another key |
| **KMIP** | Key Management Interoperability Protocol | OASIS protocol for key lifecycle management |
| **KMSE** | Key Management Secret Engine | Vault secrets engine for key management |
| **NIST** | National Institute of Standards and Technology | US standards body |
| **OIDC** | OpenID Connect | Identity protocol for SSO (Okta, Ping, Google) |
| **PAM** | Privileged Access Management | Managing privileged credentials |
| **PCI** | Payment Card Information | PCI DSS security standard |
| **PHI** | Protected Health Information | HIPAA-governed healthcare data |
| **PII** | Personally Identifiable Information | Data identifying a person |
| **PKI** | Public Key Infrastructure | Certificate and public-key crypto management |
| **PQC** | Post-Quantum Cryptography | Algorithms secure against quantum attacks |
| **PR** | Performance Replication / Replica | Enterprise replication mode |
| **PRNG** | PseudoRandom Number Generator | Algorithm for key/nonce generation |
| **RGP** | Role Governing Policy | Sentinel RBAC policy (Enterprise) |
| **RUM** | Resources Under Management | Measure of Vault-managed resources |
| **SDP** | Software-Defined Perimeter | Dynamic infrastructure security model |
| **SSRF** | Server-Side Request Forgery | Web vulnerability for unintended requests |
| **TDE** | Transparent Database Encryption | DB encryption at rest |
| **VCS** | Vault Cloud Secrets | Former name for HCP Vault Secrets |
| **VSI** | Vault Secure Introduction | Process of obtaining initial client token |
| **VSO** | Vault Secrets Operator | Kubernetes secrets integration |

---

## Style & Usage Rules

### Term Corrections

| Incorrect | Correct | Notes |
|-----------|---------|-------|
| auth backend | **auth method** | Old term |
| secrets backend | **secrets engine** | Old term |
| master key | **root key** | Being renamed |
| Raft | **Integrated Storage** | Feature name is Integrated Storage |
| generic secrets | **KV secrets** | Prefer KV secrets engine |
| Secret (capitalized) | **secret** | Lowercase in body text |
| Token (capitalized) | **token** | Lowercase in body text |
| Vault Cluster | **Vault cluster** | Lowercase "cluster" in body |
| HCP Portal | **HCP portal** | Lowercase "portal" in body |
| Secrets Engine | **secrets engine** | Lowercase in body text |

### Proper Capitalization (Always Capitalize)

- **Vault Agent** - Proper name
- **Shamir Seal** - Named algorithm
- **Integrated Storage** - Product feature name

### Key Clarifications

**Unseal keys vs Shamir keys:**
- Default Shamir seal: unseal keys ARE Shamir keys
- Auto-unseal: recovery keys are Shamir keys; unseal key from provider (e.g., AWS)

**Storage Backend vs Integrated Storage:**
- Integrated Storage is ONE of the supported storage backends
- Integrated Storage is the only internal storage option
- Don't use "Raft" as the feature name

**GPG vs PGP:**
- GPG software → **GnuPG**
- The keys → **PGP keys** (regardless of creation tool)

**Client token vs Vault token:**
- Both terms are interchangeable
- CLI output often shows "client token"

---

## Vault Terms and Concepts

| Term | Definition |
|------|------------|
| **backend** | Historical term. auth backend → auth method; secrets backend → secrets engine; storage backend remains |
| **cipher** | Algorithm encrypting plaintext to ciphertext (e.g., AES-256-GCM, RSA) |
| **cryptographic barrier** | Encryption layer protecting all Vault data at rest using AES-256-GCM |
| **FedRAMP** | US program for cloud security assessment/authorization |
| **quorum** | Majority in peer set: floor(n/2) + 1 (e.g., 5 nodes → quorum = 3) |
| **Shamir's** | Shamir's Secret Sharing Algorithm for manual unseal |
| **tokenization** | Replacing sensitive data with tokens; vaultless tokenization preserves format |
| **Tweak** | Non-secret value in Transformation Secrets Engine for FPE context |
| **Watchtower** | Former code name for **Boundary** |
| **Workload IdP** | Workload Identity Provider in HCP context |
