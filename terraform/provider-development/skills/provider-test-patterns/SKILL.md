---
name: provider-test-patterns
description: >-
  Terraform provider acceptance test patterns using terraform-plugin-testing
  with the Plugin Framework. Covers test structure, TestCase/TestStep fields,
  ConfigStateChecks with custom statecheck.StateCheck implementations,
  plan checks, CompareValue for cross-step assertions, config helpers,
  import testing with ImportStateKind, sweepers, and scenario patterns
  (basic, update, disappears, validation, regression), and ephemeral resource
  testing with the echoprovider package. Use when writing, reviewing, or
  debugging provider acceptance tests, including questions about statecheck,
  plancheck, TestCheckFunc, CheckDestroy, ExpectError, import state
  verification, ephemeral resources, or how to structure test files.
metadata:
  copyright: Copyright IBM Corp. 2026
  version: "0.0.1"
---

# Provider Acceptance Test Patterns

Patterns for writing acceptance tests using
[terraform-plugin-testing](https://github.com/hashicorp/terraform-plugin-testing)
with the [Plugin Framework](https://github.com/hashicorp/terraform-plugin-framework).

Source: [HashiCorp Testing Patterns](https://developer.hashicorp.com/terraform/plugin/testing/testing-patterns)

**References** (load when needed):
- `references/checks.md` — statecheck, plancheck, knownvalue types, tfjsonpath, comparers
- `references/sweepers.md` — sweeper setup, TestMain, dependencies
- `references/ephemeral.md` — ephemeral resource testing, echoprovider, multi-step patterns

---

## Test Lifecycle

The framework runs each TestStep through: **plan → apply → refresh → final
plan**. If the final plan shows a diff, the test fails (unless
`ExpectNonEmptyPlan` is set). After all steps, destroy runs followed by
`CheckDestroy`. This means every test automatically verifies that
configurations apply cleanly and produce no drift — no assertions needed for
that.

---

## Test Function Structure

```go
func TestAccExample_basic(t *testing.T) {
    var widget example.Widget
    rName := acctest.RandStringFromCharSet(10, acctest.CharSetAlphaNum)
    resourceName := "example_widget.test"

    resource.ParallelTest(t, resource.TestCase{
        PreCheck:                 func() { testAccPreCheck(t) },
        ProtoV6ProviderFactories: testAccProtoV6ProviderFactories,
        CheckDestroy:             testAccCheckExampleDestroy,
        Steps: []resource.TestStep{
            {
                Config: testAccExampleConfig_basic(rName),
                ConfigStateChecks: []statecheck.StateCheck{
                    stateCheckExampleExists(resourceName, &widget),
                    statecheck.ExpectKnownValue(resourceName,
                        tfjsonpath.New("name"), knownvalue.StringExact(rName)),
                    statecheck.ExpectKnownValue(resourceName,
                        tfjsonpath.New("id"), knownvalue.NotNull()),
                },
            },
        },
    })
}
```

Use `resource.ParallelTest` by default. Use `resource.Test` only when tests
share state or cannot run concurrently.

---

## Provider Factory

```go
// provider_test.go — Plugin Framework with Protocol 6 (use Protocol5 variant if needed)
var testAccProtoV6ProviderFactories = map[string]func() (tfprotov6.ProviderServer, error){
    "example": providerserver.NewProtocol6WithError(New("test")()),
}
```

---

## TestCase Fields

| Field | Purpose |
|-------|---------|
| `PreCheck` | `func()` — verify prerequisites (env vars, API access) |
| `ProtoV6ProviderFactories` | Plugin Framework provider factories |
| `CheckDestroy` | `TestCheckFunc` — verify resources destroyed after all steps |
| `Steps` | `[]TestStep` — sequential test operations |
| `TerraformVersionChecks` | `[]tfversion.TerraformVersionCheck` — gate by CLI version |

---

## TestStep Fields

### Config Mode

| Field | Purpose |
|-------|---------|
| `Config` | Inline HCL string to apply |
| `ConfigStateChecks` | `[]statecheck.StateCheck` — modern assertions (preferred) |
| `ConfigPlanChecks` | `resource.ConfigPlanChecks{PreApply: []plancheck.PlanCheck{...}}` |
| `ExpectError` | `*regexp.Regexp` — expect failure matching pattern |
| `ExpectNonEmptyPlan` | `bool` — expect non-empty plan after apply |
| `PlanOnly` | `bool` — plan without applying |
| `Destroy` | `bool` — run destroy step |
| `PreConfig` | `func()` — setup before step |

### Import Mode

| Field | Purpose |
|-------|---------|
| `ImportState` | `true` to enable import mode |
| `ImportStateVerify` | Verify imported state matches prior state |
| `ImportStateVerifyIgnore` | `[]string` — attributes to skip during verify |
| `ImportStateKind` | `resource.ImportBlockWithID` — import block generation |
| `ResourceName` | Resource address to import |
| `ImportStateId` | Override the ID used for import |

---

## Check Functions

### Modern: ConfigStateChecks (preferred)

Type-safe with aggregated error reporting. Compose built-in checks with custom
`statecheck.StateCheck` implementations. See `references/checks.md` for full
knownvalue types, tfjsonpath navigation, and comparers.

```go
ConfigStateChecks: []statecheck.StateCheck{
    stateCheckExampleExists(resourceName, &widget),
    statecheck.ExpectKnownValue(resourceName,
        tfjsonpath.New("name"), knownvalue.StringExact("my-widget")),
    statecheck.ExpectKnownValue(resourceName,
        tfjsonpath.New("enabled"), knownvalue.Bool(true)),
    statecheck.ExpectKnownValue(resourceName,
        tfjsonpath.New("id"), knownvalue.NotNull()),
    statecheck.ExpectSensitiveValue(resourceName,
        tfjsonpath.New("api_key")),
},
```

Do not mix `Check` (legacy) and `ConfigStateChecks` in the same step.

### Legacy: Check (for CheckDestroy and migration)

`CheckDestroy` on `TestCase` requires `TestCheckFunc`. The `Check` field on
`TestStep` also accepts `TestCheckFunc` but prefer `ConfigStateChecks` for new
tests.

```go
Check: resource.ComposeAggregateTestCheckFunc(
    resource.TestCheckResourceAttr(name, "key", "expected"),
    resource.TestCheckResourceAttrSet(name, "id"),
    resource.TestCheckNoResourceAttr(name, "removed"),
    resource.TestMatchResourceAttr(name, "url", regexp.MustCompile(`^https://`)),
    resource.TestCheckResourceAttrPair(res1, "ref_id", res2, "id"),
),
```

`ComposeAggregateTestCheckFunc` reports all errors; `ComposeTestCheckFunc`
fails fast on the first.

---

## Config Helpers

Use numbered format verbs — `%[1]q` for quoted strings, `%[1]s` for raw:

```go
func testAccExampleConfig_basic(rName string) string {
    return fmt.Sprintf(`
resource "example_widget" "test" {
  name = %[1]q
}
`, rName)
}

func testAccExampleConfig_full(rName, description string) string {
    return fmt.Sprintf(`
resource "example_widget" "test" {
  name        = %[1]q
  description = %[2]q
  enabled     = true
}
`, rName, description)
}
```

---

## Scenario Patterns

### Basic + Update (combine in one test — updates are supersets of basic)

```go
Steps: []resource.TestStep{
    {
        Config: testAccExampleConfig_basic(rName),
        ConfigStateChecks: []statecheck.StateCheck{
            stateCheckExampleExists(resourceName, &widget),
            statecheck.ExpectKnownValue(resourceName,
                tfjsonpath.New("name"), knownvalue.StringExact(rName)),
        },
    },
    {
        Config: testAccExampleConfig_full(rName, "updated"),
        ConfigStateChecks: []statecheck.StateCheck{
            stateCheckExampleExists(resourceName, &widget),
            statecheck.ExpectKnownValue(resourceName,
                tfjsonpath.New("description"), knownvalue.StringExact("updated")),
        },
    },
},
```

### Import

After a config step, verify import produces identical state. Use
`ImportStateKind` for import block generation:

```go
{
    ResourceName:      resourceName,
    ImportState:       true,
    ImportStateVerify: true,
    ImportStateKind:   resource.ImportBlockWithID,
},
```

### Disappears (resource deleted externally)

```go
{
    Config: testAccExampleConfig_basic(rName),
    ConfigStateChecks: []statecheck.StateCheck{
        stateCheckExampleExists(resourceName, &widget),
        stateCheckExampleDisappears(resourceName),
    },
    ExpectNonEmptyPlan: true,
},
```

### Validation (expect error)

```go
{
    Config:      testAccExampleConfig_invalidName(""),
    ExpectError: regexp.MustCompile(`name must not be empty`),
},
```

### Regression (two-commit workflow)

A proper bug fix uses at least two commits: first commit the regression test
(which fails, confirming the bug), then commit the fix (test passes). This
lets reviewers independently verify the test reproduces the issue by checking
out the first commit, then advancing to the fix.

Name and document regression tests to identify the issue they fix. Include a
link to the original bug report when possible.

```go
// TestAccExample_regressionGH1234 verifies fix for https://github.com/org/repo/issues/1234
func TestAccExample_regressionGH1234(t *testing.T) {
    rName := acctest.RandStringFromCharSet(10, acctest.CharSetAlphaNum)
    resourceName := "example_widget.test"

    resource.ParallelTest(t, resource.TestCase{
        PreCheck:                 func() { testAccPreCheck(t) },
        ProtoV6ProviderFactories: testAccProtoV6ProviderFactories,
        CheckDestroy:             testAccCheckExampleDestroy,
        Steps: []resource.TestStep{
            {
                // Reproduce the issue: this config triggered the bug
                Config: testAccExampleConfig_regressionGH1234(rName),
                ConfigStateChecks: []statecheck.StateCheck{
                    stateCheckExampleExists(resourceName, nil),
                    statecheck.ExpectKnownValue(resourceName,
                        tfjsonpath.New("computed_field"), knownvalue.NotNull()),
                },
            },
        },
    })
}
```

---

## Helper Functions

### Custom StateCheck: Exists

Implement `statecheck.StateCheck` for API existence verification. Separate the
exists check into its own function for reuse across steps — the source
recommends this as a design principle:

```go
type exampleExistsCheck struct {
    resourceAddress string
    widget          *example.Widget
}

func (e exampleExistsCheck) CheckState(ctx context.Context, req statecheck.CheckStateRequest, resp *statecheck.CheckStateResponse) {
    r, err := stateResourceAtAddress(req.State, e.resourceAddress)
    if err != nil {
        resp.Error = err
        return
    }

    id, ok := r.AttributeValues["id"].(string)
    if !ok {
        resp.Error = fmt.Errorf("no id found for %s", e.resourceAddress)
        return
    }

    conn := testAccAPIClient()
    widget, err := conn.GetWidget(id)
    if err != nil {
        resp.Error = fmt.Errorf("%s not found via API: %w", e.resourceAddress, err)
        return
    }

    if e.widget != nil {
        *e.widget = *widget
    }
}

func stateCheckExampleExists(name string, widget *example.Widget) statecheck.StateCheck {
    return exampleExistsCheck{resourceAddress: name, widget: widget}
}
```

### Custom StateCheck: Disappears

Delete a resource via API to simulate external deletion:

```go
type exampleDisappearsCheck struct {
    resourceAddress string
}

func (e exampleDisappearsCheck) CheckState(ctx context.Context, req statecheck.CheckStateRequest, resp *statecheck.CheckStateResponse) {
    r, err := stateResourceAtAddress(req.State, e.resourceAddress)
    if err != nil {
        resp.Error = err
        return
    }

    id := r.AttributeValues["id"].(string)
    conn := testAccAPIClient()
    resp.Error = conn.DeleteWidget(id)
}

func stateCheckExampleDisappears(name string) statecheck.StateCheck {
    return exampleDisappearsCheck{resourceAddress: name}
}
```

### State Resource Lookup (shared utility)

```go
func stateResourceAtAddress(state *tfjson.State, address string) (*tfjson.StateResource, error) {
    if state == nil || state.Values == nil || state.Values.RootModule == nil {
        return nil, fmt.Errorf("no state available")
    }
    for _, r := range state.Values.RootModule.Resources {
        if r.Address == address {
            return r, nil
        }
    }
    return nil, fmt.Errorf("not found in state: %s", address)
}
```

### Destroy Check (TestCheckFunc — required by CheckDestroy)

```go
func testAccCheckExampleDestroy(s *terraform.State) error {
    conn := testAccAPIClient()
    for _, rs := range s.RootModule().Resources {
        if rs.Type != "example_widget" {
            continue
        }
        _, err := conn.GetWidget(rs.Primary.ID)
        if err == nil {
            return fmt.Errorf("widget %s still exists", rs.Primary.ID)
        }
        if !isNotFoundError(err) {
            return err
        }
    }
    return nil
}
```

### PreCheck

```go
func testAccPreCheck(t *testing.T) {
    t.Helper()
    if os.Getenv("EXAMPLE_API_KEY") == "" {
        t.Fatal("EXAMPLE_API_KEY must be set for acceptance tests")
    }
}
```
