---
name: vault-performance
description: Optimize performance and write benchmarks for HashiCorp Vault. Use when investigating slow operations, reducing allocations, writing benchmarks, profiling CPU/memory usage, or working on scalability improvements.
compatibility: Requires Go 1.22+, go tool pprof
---

# Vault Performance

## Philosophy

**Measure first**: Don't optimize without data. Profile before optimizing.

**Optimize what matters**: Focus on hot paths and bottlenecks, not micro-optimizations.

**Maintain readability**: Clear code > slightly faster code.

## Benchmarking

### Writing Benchmarks

```go
func BenchmarkCreateEntity(b *testing.B) {
    // Setup (not timed)
    store := setupStore(b)
    
    b.ResetTimer()  // Exclude setup time
    
    for i := 0; i < b.N; i++ {
        entity := &Entity{Name: fmt.Sprintf("entity-%d", i)}
        _ = store.CreateEntity(context.Background(), entity)
    }
}
```

### Running Benchmarks

```bash
# Run all benchmarks
go test -bench=. ./vault/identity

# Specific benchmark
go test -bench=BenchmarkCreateEntity ./vault/identity

# With memory stats
go test -bench=. -benchmem ./vault/identity

# Compare before/after
go test -bench=. ./vault/identity > old.txt
# Make changes
go test -bench=. ./vault/identity > new.txt
benchcmp old.txt new.txt
```

### Interpreting Output

```
BenchmarkCreateEntity-8    50000    35420 ns/op    4832 B/op    102 allocs/op
                      |       |           |           |              |
                   cores  iterations   ns/op      bytes/op      allocs/op
```

## Profiling

### CPU Profile

```bash
# Generate profile
go test -cpuprofile=cpu.prof -bench=. ./vault/identity

# Analyze
go tool pprof cpu.prof

# Commands
(pprof) top10          # Top 10 functions
(pprof) list FuncName  # Source with annotations
(pprof) web            # Visual graph
```

### Memory Profile

```bash
# Generate profile
go test -memprofile=mem.prof -bench=. ./vault/identity

# Analyze
go tool pprof mem.prof
(pprof) top10
(pprof) alloc_space    # Total allocations
```

## Common Optimizations

### 1. Reduce Allocations

```go
// ❌ BEFORE - many allocations
func ProcessEntities(entities []Entity) []string {
    var names []string
    for _, e := range entities {
        names = append(names, e.Name)
    }
    return names
}

// ✅ AFTER - preallocate
func ProcessEntities(entities []Entity) []string {
    names := make([]string, 0, len(entities))  // Preallocate capacity
    for _, e := range entities {
        names = append(names, e.Name)
    }
    return names
}
```

### 2. String Concatenation

```go
// ❌ SLOW
var result string
for _, s := range strings {
    result += s  // New string each iteration
}

// ✅ FAST
var builder strings.Builder
builder.Grow(estimatedSize)  // Preallocate if known
for _, s := range strings {
    builder.WriteString(s)
}
result := builder.String()
```

### 3. Map Preallocation

```go
// ❌ BEFORE
m := make(map[string]*Entity)

// ✅ AFTER
m := make(map[string]*Entity, len(entities))  // Preallocate
```

### 4. Avoid Unnecessary Copies

```go
// ❌ BEFORE - copies struct
func ProcessEntity(e Entity) {}

// ✅ AFTER - pass pointer
func ProcessEntity(e *Entity) {}
```

### 5. Sync.Pool for Temporary Objects

```go
var bufferPool = sync.Pool{
    New: func() interface{} {
        return new(bytes.Buffer)
    },
}

func ProcessData(data []byte) ([]byte, error) {
    buf := bufferPool.Get().(*bytes.Buffer)
    buf.Reset()
    defer bufferPool.Put(buf)
    
    buf.Write(data)
    // Process
    
    return buf.Bytes(), nil
}
```

## Optimization Strategies

### Batching

```go
// ❌ BEFORE - many small operations
for _, entity := range entities {
    store.Save(entity)
}

// ✅ AFTER - batch operation
store.SaveBatch(entities)
```

### Parallel Processing

```go
func ProcessParallel(entities []*Entity) error {
    var wg sync.WaitGroup
    errCh := make(chan error, len(entities))
    
    for _, entity := range entities {
        wg.Add(1)
        go func(e *Entity) {
            defer wg.Done()
            if err := process(e); err != nil {
                errCh <- err
            }
        }(entity)
    }
    
    wg.Wait()
    close(errCh)
    
    for err := range errCh {
        if err != nil {
            return err
        }
    }
    return nil
}
```

## Performance Checklist

Before deploying optimizations:

- [ ] Benchmarked before and after
- [ ] Profiled CPU and memory
- [ ] Checked for memory leaks
- [ ] Verified concurrent access is safe
- [ ] Load tested with realistic workload
- [ ] Confirmed correctness with tests

## Test Timeout Considerations

**Symptom**: Tests hang or timeout

**Solutions**:
1. Check for goroutine leaks - use `go tool trace`
2. Reduce complexity in test setup
3. Use Docker-based tests for isolation: `make integ`
4. Set explicit timeouts in integration tests
5. Note: `TEST_TIMEOUT=45m`, `INTEG_TEST_TIMEOUT=120m` are defaults
