# Test Sweepers Reference

Sweepers clean up infrastructure resources that leak during acceptance tests —
when test infrastructure fails to be destroyed due to API errors or test
failures.

Source: [Sweepers](https://developer.hashicorp.com/terraform/plugin/testing/acceptance-tests/sweepers)

---

## Setup

### TestMain (required)

Add to a dedicated file (e.g., `sweep_test.go`):

```go
func TestMain(m *testing.M) {
    resource.TestMain(m)
}
```

This parses the `-sweep` flag and invokes registered sweepers.

### Register a Sweeper

Register in the test file for the resource being swept, using `init()`:

```go
func init() {
    resource.AddTestSweepers("example_widget", &resource.Sweeper{
        Name: "example_widget",
        F:    sweepWidgets,
    })
}

func sweepWidgets(region string) error {
    client, err := sharedClientForRegion(region)
    if err != nil {
        return fmt.Errorf("getting client: %w", err)
    }

    conn := client.(*Client)
    widgets, err := conn.ListWidgets()
    if err != nil {
        return fmt.Errorf("listing widgets: %w", err)
    }

    for _, w := range widgets {
        if !strings.HasPrefix(w.Name, "test-acc") {
            continue
        }
        if err := conn.DeleteWidget(w.ID); err != nil {
            log.Printf("[WARN] Failed to delete widget %s: %s", w.ID, err)
        }
    }

    return nil
}
```

Use a consistent test name prefix (e.g., `"test-acc"`) to identify
test-created resources.

### Dependencies

When resources have ordering requirements (e.g., child resources must be
deleted before parents), the **parent** sweeper declares children as
dependencies so they run first:

```go
resource.AddTestSweepers("example_widget", &resource.Sweeper{
    Name:         "example_widget",
    Dependencies: []string{"example_widget_child"},
    F:            sweepWidgets,
})
```

Dependencies run **before** the sweeper that declares them. In this example,
`example_widget_child` is swept first, then `example_widget`.

### Shared Client

Create a helper to build an API client for the sweep region:

```go
func sharedClientForRegion(region string) (any, error) {
    // Build and return a configured API client
    return NewClient(region)
}
```

## Running Sweepers

```bash
# Run all sweepers for a region
TF_ACC=1 go test ./internal/service/example -sweep=us-east-1 -v

# Makefile target (common convention)
make sweep
```
