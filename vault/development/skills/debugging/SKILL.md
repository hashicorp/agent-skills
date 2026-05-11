---
name: vault-debugging
description: Debug build failures, test failures, race conditions, and runtime issues in HashiCorp Vault. Use when troubleshooting compilation errors, test timeouts, nil pointer errors, investigating crashes, or when tests hang with no output.
compatibility: Requires Go 1.22+, make, access to Vault repository
---

# Vault Debugging

## Systematic Workflow

### 1. Reproduce Consistently

```bash
# Run failing test multiple times
for i in {1..10}; do
    make test TEST=./vault/identity TESTARGS="-run TestFailingTest"
done

# Check for race conditions
make testrace TEST=./vault/identity TESTARGS="-run TestFailingTest"
```

### 2. Isolate the Problem

```bash
# Run with verbose output
make test TEST=./vault/identity TESTARGS="-v -run TestSpecificTest"

# Enable debug logging
VAULT_LOG_LEVEL=debug make test TEST=./vault/identity
```

### 3. Gather Information

```bash
# Check build tags
go list -f '{{.GoFiles}}' ./vault/identity
go list -tags enterprise -f '{{.GoFiles}}' ./vault/identity

# Check dependencies
go list -m all | grep hashicorp
```

## Common Error Patterns

### "undefined: ConstantName"

**Symptom**: `undefined: EnterpriseThing`

**Cause**: Build tags not applied, or CE code referencing EE code

**Fix**:
1. Use `make test` not `go test`
2. Add `//go:build enterprise` to file
3. Move EE code to `_ent.go` file

**Debug**:
```bash
# Verify which files are compiled
go list -f '{{.GoFiles}}' ./vault/identity
go list -tags enterprise -f '{{.GoFiles}}' ./vault/identity
```

### Nil Pointer Dereference

**Symptom**: `panic: runtime error: invalid memory address`

**Common causes**:
- Uninitialized maps: `var m map[string]string` (nil map)
- Error interface with nil value
- Missing initialization

**Fix**:
```go
// Initialize maps
m := make(map[string]string)

// Check before dereferencing
if obj != nil && obj.Field != nil {
    value = obj.Field.Value
}

// Return concrete errors, not interface variables
if err != nil {
    return nil, err  // Not: return nil, someInterfaceVar
}
```

### Race Conditions

**Symptom**: `WARNING: DATA RACE`

**Debug**:
```bash
# Always use race detector
make testrace TEST=./vault/identity

# Increase iterations
make testrace TEST=./vault/identity TESTARGS="-count=100"
```

**Fix**: Add synchronization
```go
type SafeMap struct {
    mu   sync.RWMutex
    data map[string]string
}

func (m *SafeMap) Get(key string) string {
    m.mu.RLock()
    defer m.mu.RUnlock()
    return m.data[key]
}

func (m *SafeMap) Set(key, value string) {
    m.mu.Lock()
    defer m.mu.Unlock()
    m.data[key] = value
}
```

### Context Deadline Exceeded

**Symptom**: `context deadline exceeded` in tests

**Common causes**:
- Test cluster not ready
- Missing `vault.TestWaitActive()`
- Actual timeout

**Fix**:
```go
cluster := vault.NewTestCluster(t, coreConfig, clusterOptions)
defer cluster.Cleanup()

core := cluster.Cores[0].Core
vault.TestWaitActive(t, core)  // CRITICAL: Add this

// Now safe to proceed
client := cluster.Cores[0].Client
```

## Build Failures

```bash
# Clean caches
go clean -cache -modcache -testcache

# Update dependencies
go mod tidy
go mod download

# Verify version
go version  # Should be 1.22+
```

## Debugging Tools

### Printf Debugging

```go
log.Printf("DEBUG: Entering function with args: %+v", args)
log.Printf("DEBUG: Variable state: %v", variable)
```

### Delve Debugger

```bash
# Install
go install github.com/go-delve/delve/cmd/dlv@latest

# Debug test
dlv test ./vault/identity -- -test.run TestSpecificTest

# Commands
(dlv) break vault/identity.CreateEntity
(dlv) continue
(dlv) print entity
(dlv) next
```

### Stack Traces

```go
import "runtime/debug"

debug.PrintStack()  // Print current stack

stack := debug.Stack()
log.Printf("Stack:\n%s", stack)
```

## Troubleshooting Checklist

When stuck:

- [ ] Can reproduce consistently?
- [ ] Ran with `-v` for verbose output?
- [ ] Ran with race detector?
- [ ] Checked build tags?
- [ ] Verified dependencies?
- [ ] Checked for nil pointers?
- [ ] Added debug logging?
- [ ] Isolated minimal reproduction?
- [ ] Checked git diff for recent changes?

## Long-Running Builds: Don't Assume Hangs

Building Vault and running tests can show **no output for 1-2 minutes**. This is normal.

**Observed timings** (macOS Apple Silicon):
- First `make test` prints nothing for ~50-70 seconds during "Cleaning..." and "go generate"
- Focused subset: `make test TESTARGS="-run TestCore_ -v"` completes in ~60 seconds after prep

**Progress signals**:
```
"Checking that build is using go version..."
"Using go version ..."
"Cleaning..."          ← Can be quiet for 30-90s
"Running go generate..." ← Can be quiet for 30-90s
[burst of test output]
```

**Tips**:
```bash
# Wrap with timestamps
date; make test TEST=./vault TESTARGS="-run TestJWT -v"; date

# Always use -v for steady output stream
make test TEST=./vault TESTARGS="-run TestSpecificTest -v -count=1"
```

**Timeouts**: `TEST_TIMEOUT=45m`, `INTEG_TEST_TIMEOUT=120m` — lack of output for several minutes is normal.
