---
name: vault-acronym-helper
description: Provide context and definitions for HashiCorp Vault acronyms, terminology, and usage guidelines. Use when encountering unfamiliar Vault-specific acronyms (e.g., PKI, KMIP, DR, HVD, VSO), normalizing terminology in documentation, understanding and reviewing Vault code, docs/blogs/UI copy, or understanding Vault concepts like auth methods, secrets engines, or storage backends.
---

# Vault Acronym Helper

Lookup and normalize HashiCorp Vault acronyms, terminology, and usage conventions.

## Quick Lookup

For acronym definitions and terminology guidance, consult [references/acronyms.md](references/acronyms.md).

## Key Terminology Corrections

Apply these corrections when writing or reviewing Vault content:

| Deprecated Term | Correct Term |
|-----------------|--------------|
| auth backend | **auth method** |
| secrets backend | **secrets engine** |
| master key | **root key** |
| Raft (as feature) | **Integrated Storage** |
| generic secrets | **KV secrets** |

## Capitalization Rules

- **Lowercase in body text**: secret, token, cluster, secrets engine, auth method
- **Capitalize proper names**: Vault Agent, Shamir Seal, Integrated Storage
- **Init Caps in headings only**

## Common Acronyms (Quick Reference)

| Acronym | Meaning |
|---------|---------|
| DR | Disaster Recovery |
| PKI | Public Key Infrastructure |
| KMIP | Key Management Interoperability Protocol |
| HVD | HCP Vault Dedicated |
| HVE | HashiCorp Vault Enterprise |
| HVS | HCP Vault Secrets |
| VSO | Vault Secrets Operator |
| DEK | Data Encryption Key |
| KEK | Key Encryption Key |

For complete acronym list with detailed explanations, see [references/acronyms.md](references/acronyms.md).
