---
name: provider-resources
description: Implement Terraform Provider resources and data sources using the Plugin Framework. Use when developing CRUD operations, schema design, state management, and acceptance testing for provider resources.
metadata:
  copyright: Copyright IBM Corp. 2026
  version: "0.0.1"
---

# Terraform Provider Resources Implementation Guide

## Overview

This guide covers developing Terraform Provider resources and data sources using the Terraform Plugin Framework. Resources represent infrastructure objects that Terraform manages through Create, Read, Update, and Delete (CRUD) operations.

**References:**
- [Terraform Plugin Framework](https://developer.hashicorp.com/terraform/plugin/framework)
- [Resource Development](https://developer.hashicorp.com/terraform/plugin/framework/resources)
- [Data Source Development](https://developer.hashicorp.com/terraform/plugin/framework/data-sources)

## File Structure

Resources follow the standard service package structure:

```
internal/service/<service>/
├── <resource_name>.go           # Resource implementation
├── <resource_name>_test.go      # Acceptance tests
├── <resource_name>_data_source.go    # Data source (if applicable)
├── find.go                      # Finder functions
├── exports_test.go              # Test exports
└── service_package_gen.go       # Auto-generated registration
```

Documentation structure:
```
website/docs/r/
└── <service>_<resource_name>.html.markdown  # Resource documentation

website/docs/d/
└── <service>_<resource_name>.html.markdown  # Data source documentation
```

## Resource Structure

### SDKv2 Resource Pattern

```go
func ResourceExample() *schema.Resource {
    return &schema.Resource{
        CreateWithoutTimeout: resourceExampleCreate,
        ReadWithoutTimeout:   resourceExampleRead,
        UpdateWithoutTimeout: resourceExampleUpdate,
        DeleteWithoutTimeout: resourceExampleDelete,

        Importer: &schema.ResourceImporter{
            StateContext: schema.ImportStatePassthroughContext,
        },

        Schema: map[string]*schema.Schema{
            "name": {
                Type:         schema.TypeString,
                Required:     true,
                ForceNew:     true,
                ValidateFunc: validation.StringLenBetween(1, 255),
            },
            "arn": {
                Type:     schema.TypeString,
                Computed: true,
            },
            "tags":     tftags.TagsSchema(),
            "tags_all": tftags.TagsSchemaComputed(),
        },

        CustomizeDiff: verify.SetTagsDiff,
    }
}
```

### Plugin Framework Resource Pattern

```go
type resourceExample struct {
    framework.ResourceWithConfigure
}

func (r *resourceExample) Metadata(_ context.Context, req resource.MetadataRequest, resp *resource.MetadataResponse) {
    resp.TypeName = req.ProviderTypeName + "_example"
}

func (r *resourceExample) Schema(ctx context.Context, req resource.SchemaRequest, resp *resource.SchemaResponse) {
    resp.Schema = schema.Schema{
        Attributes: map[string]schema.Attribute{
            "id": framework.IDAttribute(),
            "name": schema.StringAttribute{
                Required: true,
                PlanModifiers: []planmodifier.String{
                    stringplanmodifier.RequiresReplace(),
                },
                Validators: []validator.String{
                    stringvalidator.LengthBetween(1, 255),
                },
            },
            "arn": schema.StringAttribute{
                Computed: true,
                PlanModifiers: []planmodifier.String{
                    stringplanmodifier.UseStateForUnknown(),
                },
            },
        },
    }
}
```

## CRUD Operations

### Create Operation

```go
func (r *resourceExample) Create(ctx context.Context, req resource.CreateRequest, resp *resource.CreateResponse) {
    var data resourceExampleModel
    resp.Diagnostics.Append(req.Plan.Get(ctx, &data)...)
    if resp.Diagnostics.HasError() {
        return
    }

    conn := r.Meta().ExampleClient(ctx)

    input := &example.CreateExampleInput{
        Name: data.Name.ValueStringPointer(),
    }

    output, err := conn.CreateExample(ctx, input)
    if err != nil {
        resp.Diagnostics.AddError(
            "Error creating Example",
            fmt.Sprintf("Could not create example %s: %s", data.Name.ValueString(), err),
        )
        return
    }

    data.ID = types.StringPointerValue(output.Id)
    data.ARN = types.StringPointerValue(output.Arn)

    resp.Diagnostics.Append(resp.State.Set(ctx, &data)...)
}
```

### Read Operation

```go
func (r *resourceExample) Read(ctx context.Context, req resource.ReadRequest, resp *resource.ReadResponse) {
    var data resourceExampleModel
    resp.Diagnostics.Append(req.State.Get(ctx, &data)...)
    if resp.Diagnostics.HasError() {
        return
    }

    conn := r.Meta().ExampleClient(ctx)

    output, err := findExampleByID(ctx, conn, data.ID.ValueString())
    if tfresource.NotFound(err) {
        resp.Diagnostics.AddWarning(
            "Resource not found",
            fmt.Sprintf("Example %s not found, removing from state", data.ID.ValueString()),
        )
        resp.State.RemoveResource(ctx)
        return
    }
    if err != nil {
        resp.Diagnostics.AddError(
            "Error reading Example",
            fmt.Sprintf("Could not read example %s: %s", data.ID.ValueString(), err),
        )
        return
    }

    data.Name = types.StringPointerValue(output.Name)
    data.ARN = types.StringPointerValue(output.Arn)

    resp.Diagnostics.Append(resp.State.Set(ctx, &data)...)
}
```

### Update Operation

```go
func (r *resourceExample) Update(ctx context.Context, req resource.UpdateRequest, resp *resource.UpdateResponse) {
    var plan, state resourceExampleModel
    resp.Diagnostics.Append(req.Plan.Get(ctx, &plan)...)
    resp.Diagnostics.Append(req.State.Get(ctx, &state)...)
    if resp.Diagnostics.HasError() {
        return
    }

    conn := r.Meta().ExampleClient(ctx)

    if !plan.Description.Equal(state.Description) {
        input := &example.UpdateExampleInput{
            Id:          plan.ID.ValueStringPointer(),
            Description: plan.Description.ValueStringPointer(),
        }

        _, err := conn.UpdateExample(ctx, input)
        if err != nil {
            resp.Diagnostics.AddError(
                "Error updating Example",
                fmt.Sprintf("Could not update example %s: %s", plan.ID.ValueString(), err),
            )
            return
        }
    }

    resp.Diagnostics.Append(resp.State.Set(ctx, &plan)...)
}
```

### Delete Operation

```go
func (r *resourceExample) Delete(ctx context.Context, req resource.DeleteRequest, resp *resource.DeleteResponse) {
    var data resourceExampleModel
    resp.Diagnostics.Append(req.State.Get(ctx, &data)...)
    if resp.Diagnostics.HasError() {
        return
    }

    conn := r.Meta().ExampleClient(ctx)

    _, err := conn.DeleteExample(ctx, &example.DeleteExampleInput{
        Id: data.ID.ValueStringPointer(),
    })

    if tfresource.NotFound(err) {
        return
    }

    if err != nil {
        resp.Diagnostics.AddError(
            "Error deleting Example",
            fmt.Sprintf("Could not delete example %s: %s", data.ID.ValueString(), err),
        )
        return
    }
}
```

## Schema Design

### Attribute Types

| Terraform Type | Framework Type | Use Case |
|----------------|----------------|----------|
| `string` | `schema.StringAttribute` | Names, ARNs, IDs |
| `number` | `schema.Int64Attribute`, `schema.Float64Attribute` | Counts, sizes |
| `bool` | `schema.BoolAttribute` | Feature flags |
| `list` | `schema.ListAttribute` | Ordered collections |
| `set` | `schema.SetAttribute` | Unordered unique items |
| `map` | `schema.MapAttribute` | Key-value pairs |
| `object` | `schema.SingleNestedAttribute` | Complex nested config |

### Plan Modifiers

```go
// Force replacement when value changes
stringplanmodifier.RequiresReplace()

// Preserve unknown value during plan
stringplanmodifier.UseStateForUnknown()

// Custom plan modifier
stringplanmodifier.RequiresReplaceIf(
    func(ctx context.Context, req planmodifier.StringRequest, resp *stringplanmodifier.RequiresReplaceIfFuncResponse) {
        // Custom logic
    },
    "description",
    "markdown description",
)
```

### Validators

```go
// String validators
stringvalidator.LengthBetween(1, 255)
stringvalidator.RegexMatches(regexp.MustCompile(`^[a-z0-9-]+$`), "must be lowercase alphanumeric with hyphens")
stringvalidator.OneOf("option1", "option2", "option3")

// Int64 validators
int64validator.Between(1, 100)
int64validator.AtLeast(1)
int64validator.AtMost(1000)

// List validators
listvalidator.SizeAtLeast(1)
listvalidator.SizeAtMost(10)
```

### Sensitive Attributes

```go
"password": schema.StringAttribute{
    Required:  true,
    Sensitive: true,
    Validators: []validator.String{
        stringvalidator.LengthAtLeast(8),
    },
}
```

## State Management

### Handling Resource Not Found

```go
func findExampleByID(ctx context.Context, conn *example.Client, id string) (*example.Example, error) {
    input := &example.GetExampleInput{
        Id: &id,
    }

    output, err := conn.GetExample(ctx, input)
    if err != nil {
        var notFound *types.ResourceNotFoundException
        if errors.As(err, &notFound) {
            return nil, &retry.NotFoundError{
                LastError:   err,
                LastRequest: input,
            }
        }
        return nil, err
    }

    if output == nil || output.Example == nil {
        return nil, tfresource.NewEmptyResultError(input)
    }

    return output.Example, nil
}
```

### Waiting for Resource States

```go
func waitExampleCreated(ctx context.Context, conn *example.Client, id string, timeout time.Duration) (*example.Example, error) {
    stateConf := &retry.StateChangeConf{
        Pending: []string{"CREATING", "PENDING"},
        Target:  []string{"ACTIVE", "AVAILABLE"},
        Refresh: statusExample(ctx, conn, id),
        Timeout: timeout,
    }

    outputRaw, err := stateConf.WaitForStateContext(ctx)
    if output, ok := outputRaw.(*example.Example); ok {
        return output, err
    }

    return nil, err
}

func statusExample(ctx context.Context, conn *example.Client, id string) retry.StateRefreshFunc {
    return func() (interface{}, string, error) {
        output, err := findExampleByID(ctx, conn, id)
        if tfresource.NotFound(err) {
            return nil, "", nil
        }
        if err != nil {
            return nil, "", err
        }
        return output, string(output.Status), nil
    }
}
```

## Testing

### Basic Acceptance Test

```go
func TestAccExampleResource_basic(t *testing.T) {
    ctx := acctest.Context(t)
    rName := sdkacctest.RandomWithPrefix(acctest.ResourcePrefix)
    resourceName := "provider_example.test"

    resource.ParallelTest(t, resource.TestCase{
        PreCheck:                 func() { acctest.PreCheck(ctx, t) },
        ProtoV5ProviderFactories: acctest.ProtoV5ProviderFactories,
        CheckDestroy:             testAccCheckExampleDestroy(ctx),
        Steps: []resource.TestStep{
            {
                Config: testAccExampleConfig_basic(rName),
                Check: resource.ComposeTestCheckFunc(
                    testAccCheckExampleExists(ctx, resourceName),
                    resource.TestCheckResourceAttr(resourceName, "name", rName),
                    resource.TestCheckResourceAttrSet(resourceName, "arn"),
                ),
            },
            {
                ResourceName:      resourceName,
                ImportState:       true,
                ImportStateVerify: true,
            },
        },
    })
}
```

### Disappears Test

```go
func TestAccExampleResource_disappears(t *testing.T) {
    ctx := acctest.Context(t)
    rName := sdkacctest.RandomWithPrefix(acctest.ResourcePrefix)
    resourceName := "provider_example.test"

    resource.ParallelTest(t, resource.TestCase{
        PreCheck:                 func() { acctest.PreCheck(ctx, t) },
        ProtoV5ProviderFactories: acctest.ProtoV5ProviderFactories,
        CheckDestroy:             testAccCheckExampleDestroy(ctx),
        Steps: []resource.TestStep{
            {
                Config: testAccExampleConfig_basic(rName),
                Check: resource.ComposeTestCheckFunc(
                    testAccCheckExampleExists(ctx, resourceName),
                    acctest.CheckResourceDisappears(ctx, acctest.Provider, ResourceExample(), resourceName),
                ),
                ExpectNonEmptyPlan: true,
            },
        },
    })
}
```

### Test Helper Functions

```go
func testAccCheckExampleExists(ctx context.Context, name string) resource.TestCheckFunc {
    return func(s *terraform.State) error {
        rs, ok := s.RootModule().Resources[name]
        if !ok {
            return fmt.Errorf("Not found: %s", name)
        }

        conn := acctest.Provider.Meta().(*conns.Client).ExampleClient(ctx)
        _, err := findExampleByID(ctx, conn, rs.Primary.ID)

        return err
    }
}

func testAccCheckExampleDestroy(ctx context.Context) resource.TestCheckFunc {
    return func(s *terraform.State) error {
        conn := acctest.Provider.Meta().(*conns.Client).ExampleClient(ctx)

        for _, rs := range s.RootModule().Resources {
            if rs.Type != "provider_example" {
                continue
            }

            _, err := findExampleByID(ctx, conn, rs.Primary.ID)
            if tfresource.NotFound(err) {
                continue
            }
            if err != nil {
                return err
            }

            return fmt.Errorf("Example %s still exists", rs.Primary.ID)
        }

        return nil
    }
}
```

### Running Tests

```bash
# Compile tests
go test -c -o /dev/null ./internal/service/<service>

# Run acceptance tests
TF_ACC=1 go test ./internal/service/<service> -run TestAccExample -v -timeout 60m

# Run with specific provider version
TF_ACC=1 go test ./internal/service/<service> -run TestAccExample -v

# Run sweeper to clean up
TF_ACC=1 go test ./internal/service/<service> -sweep=<region> -v
```

## Error Handling

### Common Error Patterns

```go
// Handle specific API errors
var notFound *types.ResourceNotFoundException
if errors.As(err, &notFound) {
    // Resource doesn't exist
}

var conflict *types.ConflictException
if errors.As(err, &conflict) {
    // Resource state conflict
}

var throttle *types.ThrottlingException
if errors.As(err, &throttle) {
    // Rate limited - SDK handles retry
}
```

### Diagnostics

```go
// Add error
resp.Diagnostics.AddError(
    "Error creating resource",
    fmt.Sprintf("Could not create resource: %s", err),
)

// Add warning
resp.Diagnostics.AddWarning(
    "Resource modified outside Terraform",
    "Resource was modified outside of Terraform, state may be inconsistent",
)

// Add attribute error
resp.Diagnostics.AddAttributeError(
    path.Root("name"),
    "Invalid name",
    "Name must be lowercase alphanumeric",
)
```

## Documentation Standards

### Resource Documentation

```markdown
---
subcategory: "Service Name"
layout: "provider"
page_title: "Provider: provider_example"
description: |-
  Manages an Example resource.
---

# Resource: provider_example

Manages an Example resource.

## Example Usage

### Basic Usage

\```hcl
resource "provider_example" "example" {
  name = "my-example"
}
\```

## Argument Reference

* `name` - (Required) Name of the example.
* `description` - (Optional) Description of the example.

## Attribute Reference

* `id` - ID of the example.
* `arn` - ARN of the example.

## Import

Example can be imported using the ID:

\```
$ terraform import provider_example.example example-id-12345
\```
```

## Pre-Submission Checklist

- [ ] Code compiles without errors
- [ ] All tests pass locally
- [ ] Resource has all CRUD operations implemented
- [ ] Import is implemented and tested
- [ ] Disappears test is included
- [ ] Documentation is complete with examples
- [ ] Error messages are clear and actionable
- [ ] Sensitive attributes are marked
- [ ] Plan modifiers are appropriate
- [ ] Validators cover edge cases

## References

- [Terraform Plugin Framework](https://developer.hashicorp.com/terraform/plugin/framework)
- [Terraform Plugin SDKv2](https://developer.hashicorp.com/terraform/plugin/sdkv2)
- [Acceptance Testing](https://developer.hashicorp.com/terraform/plugin/testing/acceptance-tests)
- [terraform-plugin-framework GitHub](https://github.com/hashicorp/terraform-plugin-framework)
