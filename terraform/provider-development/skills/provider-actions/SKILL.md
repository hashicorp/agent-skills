---
name: provider-actions
description: Implement Terraform Provider actions using the Plugin Framework. Use when developing imperative operations that execute at lifecycle events (before/after create, update, destroy).
metadata:
  copyright: Copyright IBM Corp. 2026
  version: "0.0.1"
---

# Terraform Provider Actions Implementation Guide

## Overview

Terraform Actions enable imperative operations during the Terraform lifecycle. Actions are experimental features that allow performing provider operations at specific lifecycle events (before/after create, update, destroy).

**References:**
- [Terraform Plugin Framework](https://developer.hashicorp.com/terraform/plugin/framework)
- [Terraform Actions RFC](https://github.com/hashicorp/terraform/blob/main/docs/plugin-protocol/actions.md)

## File Structure

Actions follow the standard service package structure:

```
internal/service/<service>/
├── <action_name>_action.go       # Action implementation
├── <action_name>_action_test.go  # Action tests
└── service_package_gen.go        # Auto-generated service registration
```

Documentation structure:
```
website/docs/actions/
└── <service>_<action_name>.html.markdown  # User-facing documentation
```

Changelog entry:
```
.changelog/
└── <pr_number_or_description>.txt  # Release note entry
```

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
   - Using `types.String` instead of `fwtypes.String` in model structs
   - Using `types.StringType` instead of `fwtypes.StringType` in schema
   - Mixing framework types with plugin-framework types

2. **List/Map Element Types**
   ```go
   // WRONG - missing ElementType
   "items": schema.ListAttribute{
       Optional: true,
   }

   // CORRECT
   "items": schema.ListAttribute{
       Optional:    true,
       ElementType: fwtypes.StringType,
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

5. **Region/Provider Attribute**
   - Use framework-provided region handling when available
   - Don't manually define provider-specific config in schema if framework handles it

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

    // Create provider client
    conn := a.Meta().Client(ctx)

    // Progress updates for long-running operations
    resp.Progress.Set(ctx, "Starting operation...")

    // Implement action logic with error handling
    // Use context for timeout management
    // Poll for completion if async operation

    resp.Progress.Set(ctx, "Operation completed")
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

- Use provider SDK clients from `a.Meta().<Service>Client(ctx)`
- Handle pagination for list operations
- Implement retry logic for transient failures
- Use appropriate error types

### 5. Parameter Validation

- Use framework validators for input validation
- Validate resource existence before operations
- Check for conflicting parameters
- Validate against provider naming requirements

### 6. Polling and Waiting

For operations that require waiting for completion:

```go
result, err := wait.WaitForStatus(ctx,
    func(ctx context.Context) (wait.FetchResult[*ResourceType], error) {
        // Fetch current status
        resource, err := findResource(ctx, conn, id)
        if err != nil {
            return wait.FetchResult[*ResourceType]{}, err
        }
        return wait.FetchResult[*ResourceType]{
            Status: wait.Status(resource.Status),
            Value:  resource,
        }, nil
    },
    wait.Options[*ResourceType]{
        Timeout:            timeout,
        Interval:           wait.FixedInterval(5 * time.Second),
        SuccessStates:      []wait.Status{"AVAILABLE", "COMPLETED"},
        TransitionalStates: []wait.Status{"CREATING", "PENDING"},
        ProgressInterval:   30 * time.Second,
        ProgressSink: func(fr wait.FetchResult[any], meta wait.ProgressMeta) {
            resp.SendProgress(action.InvokeProgressEvent{
                Message: fmt.Sprintf("Status: %s, Elapsed: %v", fr.Status, meta.Elapsed.Round(time.Second)),
            })
        },
    },
)
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

Actions are invoked via `action_trigger` lifecycle blocks in Terraform configurations:

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

**Terraform 1.14.0 Supported Events:**
- `before_create` - Before resource creation
- `after_create` - After resource creation
- `before_update` - Before resource update
- `after_update` - After resource update

**Not Supported in Terraform 1.14.0:**
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
func TestAccServiceAction_basic(t *testing.T) {
    ctx := acctest.Context(t)

    resource.ParallelTest(t, resource.TestCase{
        PreCheck:                 func() { acctest.PreCheck(ctx, t) },
        ProtoV5ProviderFactories: acctest.ProtoV5ProviderFactories,
        TerraformVersionChecks: []tfversion.TerraformVersionCheck{
            tfversion.SkipBelow(tfversion.Version1_14_0),
        },
        Steps: []resource.TestStep{
            {
                Config: testAccActionConfig_basic(),
                Check: resource.ComposeTestCheckFunc(
                    testAccCheckResourceExists(ctx, "provider_resource.test"),
                ),
            },
        },
    })
}
```

### Test Cleanup with Sweep Functions

Add sweep functions to clean up test resources:

```go
func sweepResources(region string) error {
    ctx := context.Background()
    client := /* get client for region */

    input := &service.ListInput{
        // Filter for test resources
    }

    var sweeperErrs *multierror.Error

    pages := service.NewListPaginator(client, input)
    for pages.HasMorePages() {
        page, err := pages.NextPage(ctx)
        if err != nil {
            sweeperErrs = multierror.Append(sweeperErrs, err)
            continue
        }

        for _, item := range page.Items {
            id := item.Id

            // Skip non-test resources
            if !strings.HasPrefix(id, "tf-acc-test") {
                continue
            }

            _, err := client.Delete(ctx, &service.DeleteInput{
                Id: id,
            })
            if err != nil {
                sweeperErrs = multierror.Append(sweeperErrs, err)
            }
        }
    }

    return sweeperErrs.ErrorOrNil()
}
```

### Testing Best Practices

**Service-Specific Prerequisites**
- Always check for service-specific prerequisites that must be met before actions can succeed
- Document prerequisites in action documentation and test configurations

**Error Pattern Matching**
- Terraform wraps action errors with additional context
- Use flexible regex patterns: `regexache.MustCompile(\`(?s)Error Title.*key phrase\`)`

**Test Patterns Not Applicable to Actions**
1. Actions trigger on lifecycle events, not config reapplication
2. Before/After Destroy Tests: Not supported in Terraform 1.14.0

### Running Tests

Compile test to check for errors:
```bash
go test -c -o /dev/null ./internal/service/<service>
```

Run specific action tests:
```bash
TF_ACC=1 go test ./internal/service/<service> -run TestAccServiceAction_ -v
```

Run sweep to clean up test resources:
```bash
TF_ACC=1 go test ./internal/service/<service> -sweep=<region> -v
```

## Documentation Standards

Each action documentation file must include:

1. **Front Matter**
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

5. **Documentation Linting**
   - Run `terrafmt fmt` before submission
   - Verify with `terrafmt diff`

## Changelog Entry Format

Create a changelog entry in `.changelog/` directory:

```
.changelog/<pr_number_or_description>.txt
```

Content format:
```release-note:new-action
action/provider_service_action: Brief description of the action
```

## Pre-Submission Checklist

Before submitting your action implementation:

- [ ] Code compiles: `go build -o /dev/null .`
- [ ] Tests compile: `go test -c -o /dev/null ./internal/service/<service>`
- [ ] Code formatted: `make fmt`
- [ ] Documentation formatted: `terrafmt fmt website/docs/actions/<action>.html.markdown`
- [ ] Changelog entry created
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
