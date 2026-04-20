---
name: vault-testing
description: Write and run tests for HashiCorp Vault. Use when writing unit tests, integration tests, running specific tests, understanding build tags. Covers CE/EE testing, race detection, and common test patterns.
compatibility: Requires Go 1.22+, Docker for integration tests
---

# Vault Testing

## Fast Test Execution

Run tests directly with `go test` using proper tags and environment variables for faster execution (skips prep/generation steps):

```bash
# Basic enterprise tests
CGO_ENABLED=0 \
VAULT_ADDR= \
VAULT_TOKEN= \
VAULT_DEV_ROOT_TOKEN_ID= \
VAULT_ACC= \
go test -tags='enterprise,testonly' ./... -timeout=45m -parallel=20

# With race detector (requires CGO)
CGO_ENABLED=1 \
VAULT_ADDR= \
VAULT_TOKEN= \
VAULT_DEV_ROOT_TOKEN_ID= \
VAULT_ACC= \
go test -tags='enterprise,testonly' -race ./... -timeout=60m -parallel=20
```

## Running Specific Tests

### Basic Patterns

```bash
# Run all tests in package
CGO_ENABLED=0 VAULT_ADDR= VAULT_TOKEN= VAULT_DEV_ROOT_TOKEN_ID= VAULT_ACC= \
go test -tags='enterprise,testonly' ./vault/identity -timeout=45m -parallel=20

# Run specific test function
CGO_ENABLED=0 VAULT_ADDR= VAULT_TOKEN= VAULT_DEV_ROOT_TOKEN_ID= VAULT_ACC= \
go test -tags='enterprise,testonly' ./vault -run TestSpecificTest -timeout=45m -parallel=20

# Verbose output
CGO_ENABLED=0 VAULT_ADDR= VAULT_TOKEN= VAULT_DEV_ROOT_TOKEN_ID= VAULT_ACC= \
go test -tags='enterprise,testonly' ./vault -run TestJWT -v -timeout=45m -parallel=20

# Run multiple times (stability)
for i in {1..10}; do \
  CGO_ENABLED=0 VAULT_ADDR= VAULT_TOKEN= VAULT_DEV_ROOT_TOKEN_ID= VAULT_ACC= \
  go test -tags='enterprise,testonly' ./vault -run TestJWT -timeout=45m -parallel=20; \
done
```

### Test Filtering

The `-run` flag uses **Go regex patterns**:

```bash
# Match any test starting with TestJWT
-run TestJWT

# Exact match only
-run TestJWT$

# Match tests with JWT anywhere
-run '.*JWT.*'

# Multiple patterns (OR)
-run 'Test(JWT|OIDC)'

# Subtests
-run TestJWT/with_role
```

## Test Both CE and EE

When changing shared code, always test both editions:

```bash
# Community Edition
CGO_ENABLED=0 go test -tags='testonly' ./vault/identity -timeout=45m -parallel=20

# Enterprise Edition
CGO_ENABLED=0 VAULT_ADDR= VAULT_TOKEN= VAULT_DEV_ROOT_TOKEN_ID= VAULT_ACC= \
go test -tags='enterprise,testonly' ./vault/identity -timeout=45m -parallel=20
```

## Build Tags in Code

### File Naming

```
feature.go              # Shared (CE + EE)
feature_oss.go          # CE / Open Source only
feature_ent.go          # EE only
feature_test.go         # Shared tests
feature_ent_test.go     # EE tests only
```

### Tag Syntax

```go
//go:build enterprise
// Enterprise-only code

//go:build !enterprise
// CE-only code

//go:build ent
// +build ent
// Enterprise test
```

## Writing Tests

### Table-Driven Pattern

```go
func TestCreateEntity(t *testing.T) {
    t.Parallel()
    
    tests := []struct {
        name        string
        input       string
        expectError bool
    }{
        {"valid input", "test-entity", false},
        {"empty input", "", true},
    }
    
    for _, tt := range tests {
        tt := tt  // Capture range variable
        t.Run(tt.name, func(t *testing.T) {
            t.Parallel()
            // Test implementation
        })
    }
}
```

### Test Cluster Setup

```go
func TestWithCluster(t *testing.T) {
    t.Parallel()
    
    cluster := vault.NewTestCluster(t, &vault.CoreConfig{},
        &vault.TestClusterOptions{HandlerFunc: vaulthttp.Handler})
    t.Cleanup(cluster.Cleanup)
    
    core := cluster.Cores[0].Core
    vault.TestWaitActive(t, core)  // CRITICAL: Always wait
    
    client := cluster.Cores[0].Client
    // Test with client
}
```

## Integration and Acceptance Tests

### Integration Tests

```bash
# Basic integration tests
CGO_ENABLED=0 \
VAULT_SKIP_LOGGING_LEASE_EXPIRATIONS=1 \
VAULT_ADDR= \
VAULT_TOKEN= \
VAULT_ACC= \
go test -tags='enterprise,testonly' ./integ -v -timeout=120m -parallel=4

# With race detector
CGO_ENABLED=1 \
VAULT_SKIP_LOGGING_LEASE_EXPIRATIONS=1 \
VAULT_ADDR= \
VAULT_TOKEN= \
VAULT_ACC= \
go test -tags='enterprise,testonly' -race ./integ -v -timeout=120m -parallel=4
```

### Acceptance Tests

**WARNING**: These may incur costs or modify real resources.

```bash
VAULT_ACC=1 \
CGO_ENABLED=0 \
go test -tags='enterprise,testonly' ./... -v -timeout=60m
```

## Common Failures & Fixes

| Error | Cause | Fix |
|-------|-------|-----|
| `undefined: ConstantName` | Missing build tags | Use `-tags='enterprise,testonly'` |
| `nil pointer dereference` | Uninitialized map/struct | `m := make(map[string]string)` |
| `context deadline exceeded` | Cluster not ready | Add `vault.TestWaitActive(t, core)` |
| `data race detected` | Concurrent access | Add mutex, run with `-race` and `CGO_ENABLED=1` |
| `redeclared type` | Build tag issue | Check `//go:build` tags |

## Pre-PR Checklist

- [ ] Enterprise tests pass: `CGO_ENABLED=0 VAULT_ADDR= VAULT_TOKEN= VAULT_DEV_ROOT_TOKEN_ID= VAULT_ACC= go test -tags='enterprise,testonly' ./path -timeout=45m -parallel=20`
- [ ] CE tests pass: `CGO_ENABLED=0 go test -tags='testonly' ./path -timeout=45m -parallel=20`
- [ ] Race detector passes: `CGO_ENABLED=1 VAULT_ADDR= VAULT_TOKEN= VAULT_DEV_ROOT_TOKEN_ID= VAULT_ACC= go test -tags='enterprise,testonly' -race ./path -timeout=60m -parallel=20`
- [ ] Tests pass multiple runs
- [ ] **`make fmt` applied** (always the final step)

## Final Step: Format Code

**Always run `make fmt` as the last step** in any development or test authoring cycle:

```bash
make fmt
```

This ensures all Go files are properly formatted before committing or submitting a PR.
