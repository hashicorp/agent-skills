---
name: vault-architecture
description: Design and organize code in HashiCorp Vault. Use when designing new features, refactoring code, working with CE/EE splits, making API design decisions, understanding Vault's plugin architecture, or deciding where code should live (api/ vs sdk/ vs vault/).
compatibility: Requires Go 1.22+, access to Vault repository
---

# Vault Architecture

## Repository Structure

### Public vs Internal

Only these packages are public (importable externally):
```
api/          # Vault API client
sdk/          # Plugin SDK
```

Everything in `vault/` is internal - never import directly.

### Core Organization

```
vault/        # Core server (INTERNAL)
├── logical/  # Backend interfaces
├── physical/ # Storage backends
└── audit/    # Audit backends

builtin/      # Built-in plugins
├── logical/  # Secret engines
└── credential/ # Auth methods

command/      # CLI commands
http/         # HTTP API handlers
```

## CE/EE Code Separation

Use build tags for compile-time separation:

### File Naming

```
feature.go              # Shared (CE + EE)
feature_oss.go          # Community Edition / Open Source only
feature_ent.go          # Enterprise only
feature_test.go         # Shared tests
feature_ent_test.go     # Enterprise tests only
```

### Build Tags

```go
//go:build !enterprise
// CE-only code

//go:build enterprise  
// EE-only code
```

### Pattern: Interface-Based Separation

```go
// feature.go - shared interface
type FeatureManager interface {
    Process(ctx context.Context) error
    GetCapabilities() []string
}

// feature_oss.go
//go:build !enterprise

func NewFeatureManager() FeatureManager {
    return &ossManager{}  // Basic implementation
}

// feature_ent.go
//go:build enterprise

func NewFeatureManager() FeatureManager {
    return &entManager{  // Advanced implementation
        replicator: NewReplicator(),
    }
}
```

**Key rules**:
- Define interface in shared file
- Same function signatures in both files
- Use build tags, not runtime checks
- Test both editions: `make subtest` (CE), `make test` (EE)

## API Design

### RESTful Endpoints

```
Create:  POST   /v1/resource
Read:    GET    /v1/resource/:id
Update:  POST   /v1/resource/:id
Delete:  DELETE /v1/resource/:id
List:    LIST   /v1/resource  # Note: LIST not GET
```

### Request/Response Pattern

```go
func (b *backend) pathEntityCreate(
    ctx context.Context,
    req *logical.Request,
    data *framework.FieldData,
) (*logical.Response, error) {
    // Parse
    name := data.Get("name").(string)
    
    // Validate
    if err := validateName(name); err != nil {
        return logical.ErrorResponse(err.Error()), nil
    }
    
    // Process
    entity, err := b.createEntity(ctx, name)
    if err != nil {
        return nil, err  // Internal error
    }
    
    // Return
    return &logical.Response{
        Data: map[string]interface{}{
            "id": entity.ID,
        },
    }, nil
}
```

**Error handling**:
- `logical.ErrorResponse()` for validation errors (user-facing)
- `return nil, err` for internal errors (logged, user sees generic message)

## Plugin Architecture

### Backend Interface

```go
func Factory(ctx context.Context, conf *logical.BackendConfig) (logical.Backend, error) {
    b := &backend{}
    
    b.Backend = &framework.Backend{
        BackendType: logical.TypeLogical,
        Paths: []*framework.Path{
            b.pathCreate(),
            b.pathRead(),
        },
    }
    
    if err := b.Setup(ctx, conf); err != nil {
        return nil, err
    }
    
    return b, nil
}
```

## Storage Patterns

```go
// Write
entry := &logical.StorageEntry{
    Key:   "entity/" + id,
    Value: marshaledData,
}
req.Storage.Put(ctx, entry)

// Read
entry, err := req.Storage.Get(ctx, "entity/"+id)

// Delete
req.Storage.Delete(ctx, "entity/"+id)

// List
keys, err := req.Storage.List(ctx, "entity/")
```

**Key naming**:
```
entity/<id>                  # Single entity
entity/<id>/alias/<alias_id> # Nested
config/                      # Configuration
```

## Decision Trees

### Where Does Code Go?

```
Is it a public API?
├─ YES → api/ or sdk/
│   ├─ External consumers need it → api/
│   └─ Plugin developers need it → sdk/
└─ NO → CE, EE, or both?
    ├─ Both → .go file
    ├─ CE only → _oss.go file
    └─ EE only → _ent.go file
```

**Default rule**: If external projects might need it, put in `api/` or `sdk/`. Otherwise, use `vault/`.

### When to Split CE/EE?

Use CE/EE split when:
- Feature exists in both with different implementations
- EE adds significant capabilities
- Single codebase needed

Don't split when:
- Feature identical in both
- Feature 100% EE-only (just use `_ent.go`)
- Difference is trivial

## Adding New Components

### New Secret Engine

1. Create package in `builtin/logical/<name>/`
2. Implement `logical.Backend` interface
3. Define paths using `framework.PathAppend`
4. Add CRUD operations
5. Implement secret revocation
6. Write tests + acceptance tests

### New Auth Method

1. Create package in `builtin/credential/<name>/`
2. Implement `logical.Backend` interface
3. Define authentication paths
4. Implement token generation
5. Add credential validation
6. Write tests

## Dependency Management

```bash
# Add dependency
go get github.com/example/package@latest

# Update go.mod
make go-mod-tidy

# Verify tests
make test TEST=./path/to/package
```

**Rules**:
- Pin exact versions
- Minimize dependencies (smaller attack surface)
- Run full tests after any dep change
