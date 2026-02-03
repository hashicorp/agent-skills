---
name: identity-system
description: Use when working with Vault identity, entities, aliases, groups, identity tokens, or OIDC provider configuration. Covers unified identity management and SSO patterns.
---

# Identity System

Manage Vault's identity secrets engine for unified identity, groups, and OIDC provider capabilities.

## Reference

- [Identity Secrets Engine](https://developer.hashicorp.com/vault/docs/secrets/identity)
- [Identity Concepts](https://developer.hashicorp.com/vault/docs/concepts/identity)
- [OIDC Provider](https://developer.hashicorp.com/vault/docs/secrets/identity/oidc-provider)
- For complete API examples and advanced patterns, see [references/identity-system.md](references/identity-system.md)

## Overview

The Identity secrets engine provides:
- **Entities**: Represent users/machines across multiple auth methods
- **Aliases**: Map auth method logins to entities
- **Groups**: Organize entities for policy assignment
- **Identity Tokens**: Issue OIDC-compliant tokens
- **OIDC Provider**: Act as an identity provider for SSO

## Entities

An entity represents a single person or machine:

```bash
# Create entity
vault write identity/entity \
  name="alice" \
  policies="developer" \
  metadata=team="platform"

# Read entity
vault read identity/entity/name/alice

# List entities
vault list identity/entity/name
```

### Entity Aliases

Map authentication sources to entities:

```bash
# Create alias linking LDAP login to entity
vault write identity/entity-alias \
  name="alice@corp.com" \
  canonical_id="entity-uuid-here" \
  mount_accessor="auth_ldap_abc123"

# When alice logs in via LDAP, her token inherits entity policies
```

## Groups

### Internal Groups (Manual Membership)

```bash
# Create internal group
vault write identity/group \
  name="platform-team" \
  policies="platform-policy" \
  member_entity_ids="entity-uuid-1,entity-uuid-2"

# Add entity to group
vault write identity/group/name/platform-team \
  member_entity_ids="entity-uuid-1,entity-uuid-2,entity-uuid-3"
```

### External Groups (Auth Method Controlled)

```bash
# Create external group
vault write identity/group \
  name="ldap-admins" \
  type="external" \
  policies="admin-policy"

# Create group alias mapping LDAP group
vault write identity/group-alias \
  name="cn=admins,ou=groups,dc=corp,dc=com" \
  mount_accessor="auth_ldap_abc123" \
  canonical_id="group-uuid-here"

# When LDAP user in "admins" group authenticates, they inherit policies
```

## Identity Hierarchy

```
┌─────────────────────────────────────────────────────────┐
│                      Entity: alice                       │
│                   policies: [developer]                  │
├─────────────────────┬───────────────────────────────────┤
│ Alias: alice@ldap   │ Alias: alice-github               │
│ mount: auth/ldap    │ mount: auth/github                │
└─────────────────────┴───────────────────────────────────┘
                      │
                      ▼
         ┌────────────────────────┐
         │   Group: platform-team  │
         │   policies: [platform]  │
         └────────────────────────┘
```

## Identity Tokens (OIDC)

Issue OIDC-compliant identity tokens:

```bash
# Create OIDC key
vault write identity/oidc/key/my-key \
  algorithm="RS256" \
  rotation_period="24h"

# Create role
vault write identity/oidc/role/my-role \
  key="my-key" \
  template='{"groups":{{identity.entity.groups.names}}}'

# Generate token
vault read identity/oidc/token/my-role
```

### Token Template

Customize claims in identity tokens:

```json
{
  "sub": "{{identity.entity.id}}",
  "name": "{{identity.entity.name}}",
  "groups": {{identity.entity.groups.names}},
  "email": "{{identity.entity.metadata.email}}"
}
```

## OIDC Provider

Configure Vault as an OIDC identity provider:

```bash
# Create provider
vault write identity/oidc/provider/my-provider \
  issuer="https://vault.example.com" \
  allowed_client_ids="client-id-1,client-id-2"

# Create client
vault write identity/oidc/client/my-app \
  redirect_uris="https://app.example.com/callback" \
  assignments="allow_all"

# Create scope
vault write identity/oidc/scope/profile \
  template='{"name":"{{identity.entity.name}}"}'
```

### Discovery Endpoint

```bash
# OIDC discovery
curl $VAULT_ADDR/v1/identity/oidc/provider/my-provider/.well-known/openid-configuration
```

## Lookup Operations

```bash
# Lookup entity by ID
vault read identity/entity/id/entity-uuid

# Lookup entity by name
vault read identity/entity/name/alice

# Lookup entity by alias
vault write identity/lookup/entity \
  alias_name="alice@corp.com" \
  alias_mount_accessor="auth_ldap_abc123"

# Lookup group by name
vault read identity/group/name/platform-team
```

## Merge Entities

Combine duplicate entities:

```bash
vault write identity/entity/merge \
  from_entity_ids="entity-uuid-1,entity-uuid-2" \
  to_entity_id="entity-uuid-primary"
```

## API Examples

### Create Entity

```bash
curl -X POST \
  -H "X-Vault-Token: $VAULT_TOKEN" \
  -d '{"name":"alice","policies":["developer"]}' \
  $VAULT_ADDR/v1/identity/entity
```

### List Groups

```bash
curl -X LIST \
  -H "X-Vault-Token: $VAULT_TOKEN" \
  $VAULT_ADDR/v1/identity/group/name
```

## Common Patterns

### SSO Integration

1. Configure Vault OIDC provider
2. Register applications as OIDC clients
3. Applications redirect to Vault for authentication
4. Vault issues identity tokens with entity claims

### Cross-Auth Method Identity

1. Create entity for each user
2. Create aliases for each auth method (LDAP, GitHub, OIDC, etc.)
3. Assign policies to entities or groups
4. Users get consistent access regardless of login method

## Troubleshooting

| Issue | Cause | Resolution |
|-------|-------|------------|
| Entity policies not applied | Alias not linked | Verify entity-alias exists |
| Group policies missing | Entity not in group | Check member_entity_ids |
| OIDC token empty claims | Template syntax error | Validate template JSON |
| External group not working | Mount accessor wrong | Get accessor from auth/method/tune |
