---
name: identity-system
description: Reference documentation for Vault identity secrets engine, entities, groups, and OIDC provider.
---

# Identity System Reference

## Core Components

| Component | Description |
|-----------|-------------|
| Entity | Represents a user or machine across auth methods |
| Alias | Maps auth method login to an entity |
| Group (Internal) | Manual entity membership |
| Group (External) | Auth method controlled membership |
| Identity Token | OIDC-compliant JWT |
| OIDC Provider | Full OIDC IdP functionality |

## Entity API

| Method | Path | Description |
|--------|------|-------------|
| POST | `/identity/entity` | Create entity |
| GET | `/identity/entity/id/:id` | Read by ID |
| GET | `/identity/entity/name/:name` | Read by name |
| LIST | `/identity/entity/name` | List entities |
| DELETE | `/identity/entity/id/:id` | Delete entity |
| POST | `/identity/entity/merge` | Merge entities |

## Alias API

| Method | Path | Description |
|--------|------|-------------|
| POST | `/identity/entity-alias` | Create alias |
| GET | `/identity/entity-alias/id/:id` | Read alias |
| LIST | `/identity/entity-alias/id` | List aliases |
| DELETE | `/identity/entity-alias/id/:id` | Delete alias |

## Group API

| Method | Path | Description |
|--------|------|-------------|
| POST | `/identity/group` | Create group |
| GET | `/identity/group/id/:id` | Read by ID |
| GET | `/identity/group/name/:name` | Read by name |
| LIST | `/identity/group/name` | List groups |

## Group Types

### Internal Groups

- Membership controlled by Vault operators
- Entities added via `member_entity_ids`
- Use for cross-auth-method grouping

### External Groups

- Membership controlled by auth method
- Linked via group alias to external group
- Automatically synced on authentication

## Identity Token (OIDC) Flow

1. Create OIDC key with signing algorithm
2. Create role with template and key reference
3. Entity authenticates and reads token
4. Token contains claims from template

## OIDC Key Configuration

| Option | Description |
|--------|-------------|
| `algorithm` | RS256, RS384, RS512, ES256, ES384, ES512, EdDSA |
| `rotation_period` | How often to rotate signing key |
| `verification_ttl` | How long old keys remain valid |

## Template Variables

```json
{
  "sub": "{{identity.entity.id}}",
  "name": "{{identity.entity.name}}",
  "groups": {{identity.entity.groups.names}},
  "metadata": "{{identity.entity.metadata}}"
}
```

Available variables:
- `identity.entity.id`
- `identity.entity.name`
- `identity.entity.metadata.<key>`
- `identity.entity.aliases`
- `identity.entity.groups.ids`
- `identity.entity.groups.names`

## Lookup API

| Method | Path | Description |
|--------|------|-------------|
| POST | `/identity/lookup/entity` | Lookup entity by criteria |
| POST | `/identity/lookup/group` | Lookup group by criteria |

## Mount Accessor

Required for alias creation:

```bash
# Get accessor for auth method
vault auth list -detailed
# or
vault read sys/auth/ldap | grep accessor
```

## Policy Inheritance

Entities and groups can have policies attached:
1. Token inherits entity policies
2. Token inherits group policies (all groups entity belongs to)
3. Policies are additive to token's existing policies
4. Computed dynamically at request time
