---
name: provider-actions
description: Implement Terraform Provider actions using the Plugin Framework. Use when developing imperative operations that execute at lifecycle events (before/after create, update, destroy).
metadata:
  lifecycle-status: active
  copyright: Copyright IBM Corp. 2026
  version: "0.0.1"
---

# Terraform Provider Actions Implementation Guide

## Overview

Terraform Actions enable imperative operations during the Terraform lifecycle. Actions are experimental features that allow performing provider operations at specific lifecycle events (before/after create, update, destroy).

**References:**
- [Terraform Plugin Framework](https://developer.hashicorp.com/terraform/plugin/framework)
- [Terraform Plugin Framework Actions](https://developer.hashicorp.com/terraform/plugin/framework/actions)

## First Action Setup

When adding the first action to a provider that has never had one, several one-time scaffolding steps are required:

1. **Implement `ProviderWithActions`** — add an `Actions()` method to the provider that returns `[]func() action.Action`.
2. **Set `ActionData` in `Configure`** — the provider's `Configure` method must set `resp.ActionData = v` alongside the existing `ResourceData`, `DataSourceData`, and `EphemeralResourceData` assignments.
3. **Create `ActionWithConfigure` base type** — if the provider uses embedded base types (e.g. `ResourceWithConfigure`), create an equivalent `ActionWithConfigure` type implementing `action.ConfigureRequest` / `action.ConfigureResponse`.
4. **Action-schema helper variants** — if the provider injects common schema attributes (e.g. `namespace`) via helper functions, action-schema variants are needed since `action/schema` types differ from `resource/schema` types.

## File Structure

Most providers keep actions alongside resources in the provider package:

```
internal/provider/
├── <action_name>_action.go       # Action implementation
└── <action_name>_action_test.go  # Action tests
```

(Large multi-service providers use `internal/service/<service>/` packages
instead — follow the target repository's layout.)

Documentation lives with the other generated docs:
```
docs/actions/
└── <action_name>.md              # User-facing documentation
```

(Some older, large providers hand-write
`website/docs/actions/<name>.html.markdown` instead — match the repo.)

## Action Schema Definition

Actions use the Terraform Plugin Framework with a standard schema pattern:

```go
func (a *actionType) Schema(ctx context.Context, req action.SchemaRequest, resp *action.SchemaResponse) {
    resp.Schema = schema.Schema{
        Attributes: map[string]schema.Attribute{
            // Required configuration parameters
            "resource_id": schema.StringAttribute{
                Required:    true,
                Description: "ID of the resource to operate on",
            },
            // Optional parameters with defaults
            "timeout": schema.Int64Attribute{
                Optional:    true,
                Description: "Operation timeout in seconds",
                Default:     int64default.StaticInt64(1800),
                Computed:    true,
            },
        },
    }
}
```

### Common Schema Issues

**Pay special attention to the schema definition** - common issues after a first draft:

1. **Type Mismatches**
   - Model structs use `types.String`/`types.Int64` and schemas use
     `types.StringType` from
     `github.com/hashicorp/terraform-plugin-framework/types` — don't mix in
     types from other packages
   - Some large providers layer their own custom type package on top (e.g.
     terraform-provider-aws's internal `fwtypes`); inside such a repo,
     follow its convention consistently instead of the plain types

2. **List/Map Element Types**
   ```go
   // WRONG - missing ElementType
   "items": schema.ListAttribute{
       Optional: true,
   }

   // CORRECT
   "items": schema.ListAttribute{
       Optional:    true,
       ElementType: types.StringType,
   }
   ```

3. **Computed vs Optional**
   - Attributes with defaults must be both `Optional: true` and `Computed: true`
   - Don't mark action inputs as `Computed` unless they have defaults

4. **Validator Imports**
   ```go
   // Ensure proper imports
   "github.com/hashicorp/terraform-plugin-framework-validators/int64validator"
   "github.com/hashicorp/terraform-plugin-framework-validators/stringvalidator"
   ```

5. **Region/Provider Attribute** (multi-region providers, e.g. AWS)
   - Use the provider's shared region handling when it has one
   - Don't manually re-define provider-level configuration in an action schema

6. **Nested Attributes**
   - Use appropriate nested object types for complex structures
   - Ensure nested types are properly defined

### Schema Validation Checklist

Before submitting, verify:
- [ ] All attributes have descriptions
- [ ] List/Map attributes have ElementType defined
- [ ] Validators are imported and applied correctly
- [ ] Model struct uses correct framework types
- [ ] Optional attributes with defaults are marked Computed
- [ ] Code compiles without type errors
- [ ] Run `go build` to catch type mismatches

## Action Invoke Method

The Invoke method contains the action logic:

```go
func (a *actionType) Invoke(ctx context.Context, req action.InvokeRequest, resp *action.InvokeResponse) {
    var data actionModel
    resp.Diagnostics.Append(req.Config.Get(ctx, &data)...)
    if resp.Diagnostics.HasError() {
        return
    }

    // a.client was stored by Configure (from req.ProviderData), the same
    // pattern resources use.
    resp.SendProgress(action.InvokeProgressEvent{Message: "Starting operation..."})

    // Implement action logic with error handling
    // Use context for timeout management
    // Poll for completion if async operation

    resp.SendProgress(action.InvokeProgressEvent{Message: "Operation completed"})
}
```

## Key Implementation Requirements

### 1. Progress Reporting

- Use `resp.SendProgress(action.InvokeProgressEvent{...})` for real-time updates
- Provide meaningful progress messages during long operations
- Update progress at key milestones
- Include elapsed time for long operations

### 2. Timeout Management

- Always include configurable timeout parameter (default: 1800s)
- Use `context.WithTimeout()` for API calls
- Handle timeout errors gracefully
- Validate timeout ranges (typically 60-7200 seconds)

### 3. Error Handling

- Add diagnostics with `resp.Diagnostics.AddError()`
- Provide clear error messages with context
- Include API error details when relevant
- Map provider error types to user-friendly messages
- Document all possible error cases

Example error handling:
```go
// Handle specific errors
var notFound *types.ResourceNotFoundException
if errors.As(err, &notFound) {
    resp.Diagnostics.AddError(
        "Resource Not Found",
        fmt.Sprintf("Resource %s was not found", resourceID),
    )
    return
}

// Generic error handling
resp.Diagnostics.AddError(
    "Operation Failed",
    fmt.Sprintf("Could not complete operation for %s: %s", resourceID, err),
)
```

### 4. Provider SDK Integration

- Use the API client stored at Configure time (`a.client`), shared with
  resources and data sources
- Handle pagination for list operations
- Implement retry logic for transient failures
- Use appropriate error types

### 5. Parameter Validation

- Use framework validators for input validation
- Validate resource existence before operations
- Check for conflicting parameters
- Validate against provider naming requirements

### 6. Polling and Waiting

For operations that require waiting for completion, poll on a ticker under
a context deadline, reporting progress as you go. (Alternatively use
`retry.StateChangeConf` from
`github.com/hashicorp/terraform-plugin-sdk/v2/helper/retry`, the same waiter
primitive resources use.)

```go
ctx, cancel := context.WithTimeout(ctx, timeout)
defer cancel()

ticker := time.NewTicker(5 * time.Second)
defer ticker.Stop()

// Poll fast, report slow: progress events cross the plugin protocol, so
// throttle them instead of emitting one per poll.
start := time.Now()
var lastProgress time.Time
for {
    res, err := findResource(ctx, a.client, id)
    if err != nil {
        resp.Diagnostics.AddError("Error polling operation", fmt.Sprintf("checking status of %s: %s", id, err))
        return
    }
    switch res.Status {
    case "AVAILABLE", "COMPLETED":
        resp.SendProgress(action.InvokeProgressEvent{Message: "Operation completed"})
        return
    case "CREATING", "PENDING":
        if time.Since(lastProgress) >= 30*time.Second {
            lastProgress = time.Now()
            resp.SendProgress(action.InvokeProgressEvent{
                Message: fmt.Sprintf("Status: %s, Elapsed: %v", res.Status, time.Since(start).Round(time.Second)),
            })
        }
    default:
        resp.Diagnostics.AddError("Operation Failed", fmt.Sprintf("%s entered unexpected status %q", id, res.Status))
        return
    }

    select {
    case <-ctx.Done():
        resp.Diagnostics.AddError("Operation Timed Out", fmt.Sprintf("%s did not complete within %v", id, timeout))
        return
    case <-ticker.C:
    }
}
```

## Common Action Patterns

### Batch Operations
- Process items in configurable batches
- Report progress per batch
- Handle partial failures gracefully
- Support prefix/filter parameters

### Command Execution
- Submit command and get operation ID
- Poll for completion status
- Retrieve and report output
- Handle timeout during polling
- Validate resources exist before execution

### Service Invocation
- Invoke service with parameters
- Wait for completion (if synchronous)
- Return output/results
- Handle service-specific errors

### Resource State Changes
- Validate current state
- Apply state change
- Poll for target state
- Handle transitional states

### Async Job Submission
- Submit job with configuration
- Get job ID
- Optionally wait for completion
- Report job status

## Action Triggers

Actions are invoked via `action_trigger` lifecycle blocks in Terraform configurations. A standalone `action` block without a corresponding trigger is declared but never executed.

### HCL Syntax

Action parameters must be wrapped in a `config {}` block. Trigger references use the `action.` prefix, and `actions` is a list. Events are bare identifiers, not quoted strings.

```hcl
action "provider_service_action" "name" {
  config {
    parameter = value
  }
}

resource "terraform_data" "trigger" {
  lifecycle {
    action_trigger {
      events  = [after_create]
      actions = [action.provider_service_action.name]
    }
  }
}
```

### Available Trigger Events

**Supported events (as of Terraform 1.14):**
- `before_create` - Before resource creation
- `after_create` - After resource creation
- `before_update` - Before resource update
- `after_update` - After resource update

**Not supported (as of Terraform 1.14; check current release notes):**
- `before_destroy` - Not available (will cause validation error)
- `after_destroy` - Not available (will cause validation error)

## Testing Actions

### Acceptance Tests

- Test action invocation with valid parameters
- Test timeout scenarios
- Test error conditions
- Verify provider state changes
- Test progress reporting
- Test with custom parameters
- Test trigger-based invocation

### Test Pattern

```go
func TestAccExampleAction_basic(t *testing.T) {
    resource.ParallelTest(t, resource.TestCase{
        PreCheck:                 func() { testAccPreCheck(t) },
        ProtoV6ProviderFactories: testAccProtoV6ProviderFactories,
        TerraformVersionChecks: []tfversion.TerraformVersionCheck{
            tfversion.SkipBelow(tfversion.Version1_14_0),
        },
        Steps: []resource.TestStep{
            {
                Config: testAccActionConfig_basic(),
                ConfigStateChecks: []statecheck.StateCheck{
                    // assert the observable effect of the action on the
                    // triggering resource
                },
            },
        },
    })
}
```

### Test Cleanup with Sweep Functions

Actions invoked in tests can leave real resources behind; register sweepers
(list → filter test-prefixed names → delete) so leaked resources are
cleanable. Sweepers are not action-specific — use the
`provider-test-patterns` skill (if available) for the sweep function
pattern, registration, `TestMain`, and dependency ordering.

### Using `terraform_data` as a No-Op Trigger

`terraform_data` can serve as a no-op trigger resource for action tests that don't need real infrastructure. This is valuable for error-case and validation tests:

```hcl
resource "terraform_data" "trigger" {
  lifecycle {
    action_trigger {
      events  = [after_create]
      actions = [action.provider_service_action.test]
    }
  }
}

action "provider_service_action" "test" {
  config {
    param = "invalid-value"
  }
}
```

### Using `PostApplyFunc` to Verify Side Effects

Actions don't produce state that can be checked with `resource.TestCheckResourceAttr`. Use `PostApplyFunc` on `resource.TestStep` to query the API after apply and confirm the action produced the expected side effect:

```go
Steps: []resource.TestStep{
    {
        Config: testConfig,
        PostApplyFunc: func() {
            // query the API to verify the action's side effect occurred
        },
    },
},
```

### Testing Best Practices

**Service-Specific Prerequisites**
- Always check for service-specific prerequisites that must be met before actions can succeed
- Document prerequisites in action documentation and test configurations

**Error Pattern Matching**
- Terraform wraps action errors with additional context
- Use flexible regex patterns: `regexp.MustCompile(\`(?s)Error Title.*key phrase\`)`

**Test Patterns Not Applicable to Actions**
1. Actions trigger on lifecycle events, not config reapplication
2. Before/After Destroy Tests: Not supported as of Terraform 1.14

### Running Tests

Compile-check first, then run the focused acceptance test:
```bash
go test -c -o /dev/null ./internal/provider
TF_ACC=1 go test ./internal/provider -run TestAccExampleAction_ -timeout 60m
```

Use the `run-acceptance-tests` skill (if available) for environment variable
setup, debugging failing tests, and sweeper runs.

## Documentation Standards

Generate action documentation with `tfplugindocs` where the provider uses
it (use the `provider-docs` skill, if available, for that workflow). Each
action documentation page must include:

1. **Front Matter** (hand-written legacy layouts only)
   ```yaml
   ---
   subcategory: "Service Name"
   layout: "provider"
   page_title: "Provider: provider_service_action"
   description: |-
     Brief description of what the action does.
   ---
   ```

2. **Header with Warnings**
   - Beta/Alpha notice about experimental status
   - Warning about potential unintended consequences
   - Link to provider documentation

3. **Example Usage**
   - Basic usage example
   - Advanced usage with all options
   - Trigger-based example with `terraform_data`
   - Real-world use case examples

4. **Argument Reference**
   - List all required and optional arguments
   - Include descriptions and defaults
   - Note any validation rules

5. **Documentation Linting** (optional tooling)
   - If the repo uses `terrafmt`, run `terrafmt fmt` before submission and
     verify with `terrafmt diff`

## Changelog Entry Format (provider-specific convention)

Some providers (e.g. terraform-provider-aws) track release notes with
[go-changelog](https://github.com/hashicorp/go-changelog): one file per PR
in a `.changelog/` directory. Check the target repo's CONTRIBUTING guide;
skip this if the repo doesn't use it.

```
.changelog/<pr_number>.txt
```

Content format:
```release-note:new-action
action/provider_service_action: Brief description of the action
```

## Pre-Submission Checklist

Before submitting your action implementation:

- [ ] Code compiles: `go build -o /dev/null .`
- [ ] Tests compile: `go test -c -o /dev/null ./internal/provider`
- [ ] Code formatted: `gofmt` (or the repo's `make fmt`)
- [ ] Documentation generated or formatted per the repo's convention
- [ ] Changelog entry created (if the repo uses one)
- [ ] Schema uses correct types
- [ ] All List/Map attributes have ElementType
- [ ] Progress updates implemented for long operations
- [ ] Error messages include context and resource identifiers
- [ ] Documentation includes multiple examples
- [ ] Documentation includes prerequisites and warnings

## References

- [Terraform Plugin Framework Documentation](https://developer.hashicorp.com/terraform/plugin/framework)
- [Terraform Provider Development](https://developer.hashicorp.com/terraform/plugin)
- [terraform-plugin-framework GitHub](https://github.com/hashicorp/terraform-plugin-framework)
- [terraform-plugin-testing](https://github.com/hashicorp/terraform-plugin-testing)
- [Writing a Terraform Action (blog)](https://danielmschmidt.de/posts/2025-09-26-writing-a-terraform-action/)
- Reference implementations: `terraform-provider-tfe` (`action_query_run.go`, `action_query_run_test.go`), `terraform-provider-vault` (`action_rotate_root.go`)
