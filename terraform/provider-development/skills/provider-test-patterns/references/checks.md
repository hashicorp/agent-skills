# State Checks and Plan Checks Reference

Detailed reference for `statecheck` and `plancheck` packages from
`terraform-plugin-testing`. Read this when writing assertions for test steps.

Source: [State Checks](https://developer.hashicorp.com/terraform/plugin/testing/acceptance-tests/state-checks/resource),
[Plan Checks](https://developer.hashicorp.com/terraform/plugin/testing/acceptance-tests/plan-checks)

---

## Table of Contents

1. [State Checks](#state-checks)
2. [Known Value Types](#known-value-types)
3. [tfjsonpath Navigation](#tfjsonpath-navigation)
4. [Value Comparers](#value-comparers)
5. [Plan Checks](#plan-checks)

---

## State Checks

Use via `ConfigStateChecks` field on `TestStep`. All assertion errors are
aggregated and reported together.

### ExpectKnownValue

Assert an attribute has a specific type and value:

```go
statecheck.ExpectKnownValue("example_widget.test",
    tfjsonpath.New("name"),
    knownvalue.StringExact("my-widget"))
```

### ExpectSensitiveValue

Assert an attribute is marked sensitive (requires Terraform 1.4.6+):

```go
TerraformVersionChecks: []tfversion.TerraformVersionCheck{
    tfversion.SkipBelow(tfversion.Version1_4_6),
},
// ...
statecheck.ExpectSensitiveValue("example_widget.test",
    tfjsonpath.New("api_key"))
```

### CompareValue

Compare the same attribute across sequential test steps:

```go
compareValuesSame := statecheck.CompareValue(compare.ValuesSame())

Steps: []resource.TestStep{
    {
        Config: testAccConfig_v1(rName),
        ConfigStateChecks: []statecheck.StateCheck{
            compareValuesSame.AddStateValue("example_widget.test",
                tfjsonpath.New("id")),
        },
    },
    {
        Config: testAccConfig_v2(rName),
        ConfigStateChecks: []statecheck.StateCheck{
            compareValuesSame.AddStateValue("example_widget.test",
                tfjsonpath.New("id")),
        },
    },
},
```

### CompareValuePairs

Compare attributes between two resources:

```go
statecheck.CompareValuePairs(
    "example_widget.test", tfjsonpath.New("vpc_id"),
    "example_vpc.test", tfjsonpath.New("id"),
    compare.ValuesSame())
```

### CompareValueCollection

Check if a value exists in a collection attribute:

```go
statecheck.CompareValueCollection(
    "example_widget.test", tfjsonpath.New("tags"),
    "example_widget.test", tfjsonpath.New("name"),
    compare.ValuesSame())
```

---

## Known Value Types

Use with `ExpectKnownValue` to assert attribute values:

| Type | Example |
|------|---------|
| `knownvalue.StringExact("value")` | Exact string match |
| `knownvalue.StringRegexp(regexp.MustCompile(`^arn:`))` | Regex match |
| `knownvalue.Bool(true)` | Boolean value |
| `knownvalue.Int64Exact(42)` | Exact int64 |
| `knownvalue.Float64Exact(3.14)` | Exact float64 |
| `knownvalue.NotNull()` | Value is set (not null) |
| `knownvalue.Null()` | Value is null |
| `knownvalue.ListExact([]knownvalue.Check{...})` | Exact list match |
| `knownvalue.ListPartial(map[int]knownvalue.Check{0: ...})` | Partial list match |
| `knownvalue.ListSizeExact(3)` | List has N elements |
| `knownvalue.SetExact([]knownvalue.Check{...})` | Exact set match |
| `knownvalue.SetPartial([]knownvalue.Check{...})` | Set contains items |
| `knownvalue.SetSizeExact(2)` | Set has N elements |
| `knownvalue.MapExact(map[string]knownvalue.Check{...})` | Exact map match |
| `knownvalue.MapPartial(map[string]knownvalue.Check{...})` | Map contains keys |
| `knownvalue.MapSizeExact(1)` | Map has N keys |
| `knownvalue.ObjectExact(map[string]knownvalue.Check{...})` | Exact object match |
| `knownvalue.ObjectPartial(map[string]knownvalue.Check{...})` | Object has attributes |

### Nested Value Example

```go
statecheck.ExpectKnownValue("example_widget.test",
    tfjsonpath.New("settings"),
    knownvalue.ObjectExact(map[string]knownvalue.Check{
        "mode":    knownvalue.StringExact("production"),
        "enabled": knownvalue.Bool(true),
    }))
```

---

## tfjsonpath Navigation

Navigate nested attributes in state:

```go
tfjsonpath.New("attribute")                   // top-level attribute
tfjsonpath.New("block").AtMapKey("key")       // nested map/object key
tfjsonpath.New("list_attr").AtSliceIndex(0)   // list element by index
tfjsonpath.New("block").AtMapKey("nested").AtMapKey("deep") // deep nesting
```

---

## Value Comparers

Use with `CompareValue`, `CompareValuePairs`, `CompareValueCollection`:

| Comparer | Purpose |
|----------|---------|
| `compare.ValuesSame()` | Values are identical |
| `compare.ValuesDiffer()` | Values are different |

---

## Plan Checks

Use via `ConfigPlanChecks` or `RefreshPlanChecks` on `TestStep`. Plan checks
inspect the plan file at specific phases.

### ConfigPlanChecks Phases

```go
ConfigPlanChecks: resource.ConfigPlanChecks{
    PreApply:  []plancheck.PlanCheck{...}, // after plan, before apply
    PostApplyPreRefresh: []plancheck.PlanCheck{...}, // after apply, before refresh
    PostApplyPostRefresh: []plancheck.PlanCheck{...}, // after refresh
},
```

### Built-in Plan Checks

```go
// Expect no changes in plan
plancheck.ExpectEmptyPlan()

// Expect changes in plan
plancheck.ExpectNonEmptyPlan()

// Expect specific resource action
plancheck.ExpectResourceAction("example_widget.test", plancheck.ResourceActionCreate)
plancheck.ExpectResourceAction("example_widget.test", plancheck.ResourceActionUpdate)
plancheck.ExpectResourceAction("example_widget.test", plancheck.ResourceActionDestroy)
plancheck.ExpectResourceAction("example_widget.test", plancheck.ResourceActionNoop)

// Expect known plan value
plancheck.ExpectKnownValue("example_widget.test",
    tfjsonpath.New("name"),
    knownvalue.StringExact("my-widget"))

// Expect unknown (computed) value in plan
plancheck.ExpectUnknownValue("example_widget.test",
    tfjsonpath.New("computed_field"))

// Expect sensitive value in plan
plancheck.ExpectSensitiveValue("example_widget.test",
    tfjsonpath.New("api_key"))
```

### No-Op After Update Example

Verify that updating a config back to original values produces no diff:

```go
Steps: []resource.TestStep{
    {
        Config: testAccConfig_basic(rName),
    },
    {
        Config: testAccConfig_updated(rName),
    },
    {
        Config: testAccConfig_basic(rName),
        ConfigPlanChecks: resource.ConfigPlanChecks{
            PreApply: []plancheck.PlanCheck{
                plancheck.ExpectEmptyPlan(),
            },
        },
    },
},
```
