---
name: provider-development-with-sdk
description: Implement Terraform Provider resources and data sources using the Terraform Plugin SDKv2. Use for SDKv2-only providers, or when maintaining existing SDKv2 resources in a combined mux provider.
metadata:
  copyright: Copyright IBM Corp. 2026
  version: "0.0.1"
---

# Terraform Provider Resources — Plugin SDKv2

## Overview

This guide covers developing Terraform Provider resources and data sources using the [Terraform Plugin SDKv2](https://developer.hashicorp.com/terraform/plugin/sdkv2). Resources represent infrastructure objects that Terraform manages through Create, Read, Update, and Delete (CRUD) operations.

**References:**
- [Terraform Plugin SDKv2](https://developer.hashicorp.com/terraform/plugin/sdkv2)
- [Resource Development](https://developer.hashicorp.com/terraform/plugin/sdkv2/resources)
- [Data Source Development](https://developer.hashicorp.com/terraform/plugin/sdkv2/data-sources)

## File Structure

Resources follow the standard service package structure:

```
internal/service/<service>/
├── <resource_name>.go                # Resource implementation
├── <resource_name>_test.go           # Acceptance tests
├── <resource_name>_data_source.go    # Data source (if applicable)
├── find.go                           # Finder functions
├── exports_test.go                   # Test exports
└── service_package_gen.go            # Auto-generated registration
```

Documentation structure:
```
website/docs/r/
└── <service>_<resource_name>.html.markdown  # Resource documentation

website/docs/d/
└── <service>_<resource_name>.html.markdown  # Data source documentation
```

## Resource Structure

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

        Timeouts: &schema.ResourceTimeout{
            Create: schema.DefaultTimeout(30 * time.Minute),
            Update: schema.DefaultTimeout(30 * time.Minute),
            Delete: schema.DefaultTimeout(30 * time.Minute),
        },

        Schema: map[string]*schema.Schema{
            "name": {
                Type:         schema.TypeString,
                Required:     true,
                ForceNew:     true,
                ValidateFunc: validation.StringLenBetween(1, 255),
            },
            "description": {
                Type:     schema.TypeString,
                Optional: true,
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

## CRUD Operations

### Create

```go
func resourceExampleCreate(ctx context.Context, d *schema.ResourceData, meta interface{}) diag.Diagnostics {
    conn := meta.(*conns.AWSClient).ExampleConn(ctx)

    name := d.Get("name").(string)
    input := &example.CreateExampleInput{
        Name: aws.String(name),
    }

    output, err := conn.CreateExampleWithContext(ctx, input)
    if err != nil {
        return diag.Errorf("creating Example (%s): %s", name, err)
    }

    d.SetId(aws.StringValue(output.Id))

    if _, err := waitExampleCreated(ctx, conn, d.Id(), d.Timeout(schema.TimeoutCreate)); err != nil {
        return diag.Errorf("waiting for Example (%s) creation: %s", d.Id(), err)
    }

    return resourceExampleRead(ctx, d, meta)
}
```

### Read

```go
func resourceExampleRead(ctx context.Context, d *schema.ResourceData, meta interface{}) diag.Diagnostics {
    conn := meta.(*conns.AWSClient).ExampleConn(ctx)

    output, err := findExampleByID(ctx, conn, d.Id())
    if tfresource.NotFound(err) {
        log.Printf("[WARN] Example (%s) not found, removing from state", d.Id())
        d.SetId("")
        return nil
    }
    if err != nil {
        return diag.Errorf("reading Example (%s): %s", d.Id(), err)
    }

    d.Set("name", output.Name)
    d.Set("description", output.Description)
    d.Set("arn", output.Arn)

    return nil
}
```

### Update

```go
func resourceExampleUpdate(ctx context.Context, d *schema.ResourceData, meta interface{}) diag.Diagnostics {
    conn := meta.(*conns.AWSClient).ExampleConn(ctx)

    if d.HasChanges("description") {
        input := &example.UpdateExampleInput{
            Id:          aws.String(d.Id()),
            Description: aws.String(d.Get("description").(string)),
        }

        _, err := conn.UpdateExampleWithContext(ctx, input)
        if err != nil {
            return diag.Errorf("updating Example (%s): %s", d.Id(), err)
        }
    }

    return resourceExampleRead(ctx, d, meta)
}
```

### Delete

```go
func resourceExampleDelete(ctx context.Context, d *schema.ResourceData, meta interface{}) diag.Diagnostics {
    conn := meta.(*conns.AWSClient).ExampleConn(ctx)

    log.Printf("[DEBUG] Deleting Example: %s", d.Id())

    _, err := conn.DeleteExampleWithContext(ctx, &example.DeleteExampleInput{
        Id: aws.String(d.Id()),
    })

    if tfawserr.ErrCodeEquals(err, example.ErrCodeResourceNotFoundException) {
        return nil
    }

    if err != nil {
        return diag.Errorf("deleting Example (%s): %s", d.Id(), err)
    }

    if _, err := waitExampleDeleted(ctx, conn, d.Id(), d.Timeout(schema.TimeoutDelete)); err != nil {
        return diag.Errorf("waiting for Example (%s) deletion: %s", d.Id(), err)
    }

    return nil
}
```

## Schema Design

### Attribute Types

| Terraform Type | SDKv2 Type | Use Case |
|---|---|---|
| `string` | `schema.TypeString` | Names, ARNs, IDs |
| `int` | `schema.TypeInt` | Counts, ports |
| `float` | `schema.TypeFloat` | Numeric values |
| `bool` | `schema.TypeBool` | Feature flags |
| `list` | `schema.TypeList` | Ordered collections |
| `set` | `schema.TypeSet` | Unordered unique items |
| `map` | `schema.TypeMap` | Key-value pairs |

### Nested Objects

Use `schema.TypeList` with `MaxItems: 1` for single nested objects:

```go
"config": {
    Type:     schema.TypeList,
    Optional: true,
    MaxItems: 1,
    Elem: &schema.Resource{
        Schema: map[string]*schema.Schema{
            "timeout": {
                Type:         schema.TypeInt,
                Optional:     true,
                Default:      30,
                ValidateFunc: validation.IntBetween(1, 3600),
            },
        },
    },
},
```

### Sensitive Attributes

```go
"password": {
    Type:         schema.TypeString,
    Required:     true,
    Sensitive:    true,
    ValidateFunc: validation.StringLenBetween(8, 128),
},
```

### ForceNew

Use `ForceNew: true` on attributes where an in-place update is not possible:

```go
"name": {
    Type:     schema.TypeString,
    Required: true,
    ForceNew: true,
},
```

## State Management

### Handling Resource Not Found

```go
func findExampleByID(ctx context.Context, conn *example.Client, id string) (*example.Example, error) {
    input := &example.GetExampleInput{
        Id: aws.String(id),
    }

    output, err := conn.GetExampleWithContext(ctx, input)

    if tfawserr.ErrCodeEquals(err, example.ErrCodeResourceNotFoundException) {
        return nil, &retry.NotFoundError{
            LastError:   err,
            LastRequest: input,
        }
    }

    if err != nil {
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

func waitExampleDeleted(ctx context.Context, conn *example.Client, id string, timeout time.Duration) (*example.Example, error) {
    stateConf := &retry.StateChangeConf{
        Pending: []string{"DELETING"},
        Target:  []string{},
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
        return output, aws.StringValue(output.Status), nil
    }
}
```

## Error Handling

```go
// Match specific AWS error codes
if tfawserr.ErrCodeEquals(err, example.ErrCodeResourceNotFoundException) {
    // Resource doesn't exist
}

if tfawserr.ErrMessageContains(err, example.ErrCodeConflictException, "already exists") {
    // Conflict on creation
}
```

Return errors as diagnostics:

```go
return diag.Errorf("creating Example (%s): %s", name, err)
```

## Testing

### Basic Acceptance Test

Use `ProviderFactories` for SDKv2-only providers. For mux providers, use `ProtoV5ProviderFactories` even when testing SDKv2 resources, since the provider binary exposes a Protocol v5 server.

```go
func TestAccExampleResource_basic(t *testing.T) {
    ctx := acctest.Context(t)
    rName := sdkacctest.RandomWithPrefix(acctest.ResourcePrefix)
    resourceName := "provider_example.test"

    resource.ParallelTest(t, resource.TestCase{
        PreCheck:                 func() { acctest.PreCheck(ctx, t) },
        ProtoV5ProviderFactories: acctest.ProtoV5ProviderFactories, // use ProviderFactories for SDKv2-only providers
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

        conn := acctest.Provider.Meta().(*conns.AWSClient).ExampleConn(ctx)
        _, err := findExampleByID(ctx, conn, rs.Primary.ID)

        return err
    }
}

func testAccCheckExampleDestroy(ctx context.Context) resource.TestCheckFunc {
    return func(s *terraform.State) error {
        conn := acctest.Provider.Meta().(*conns.AWSClient).ExampleConn(ctx)

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

# Run sweeper to clean up
TF_ACC=1 go test ./internal/service/<service> -sweep=<region> -v
```

## Documentation Standards

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

* `name` - (Required) Name of the example. Forces a new resource.
* `description` - (Optional) Description of the example.

## Attribute Reference

* `id` - ID of the example.
* `arn` - ARN of the example.

## Timeouts

`provider_example` provides the following Timeouts configuration block:

* `create` - (Default `30 minutes`) Used when creating the example.
* `update` - (Default `30 minutes`) Used when updating the example.
* `delete` - (Default `30 minutes`) Used when deleting the example.

## Import

Example can be imported using the ID:

\```
$ terraform import provider_example.example example-id-12345
\```
```

## Pre-Submission Checklist

- [ ] Code compiles: `go build -o /dev/null .`
- [ ] Tests compile: `go test -c -o /dev/null ./internal/service/<service>`
- [ ] All CRUD operations implemented
- [ ] `ForceNew` set on immutable attributes
- [ ] Import is implemented and tested
- [ ] Disappears test is included
- [ ] `Timeouts` block defined and used in waiter calls
- [ ] Documentation is complete with examples and Timeouts section
- [ ] Error messages are clear and include resource identifiers
- [ ] Sensitive attributes are marked

## References

- [Terraform Plugin SDKv2](https://developer.hashicorp.com/terraform/plugin/sdkv2)
- [Acceptance Testing](https://developer.hashicorp.com/terraform/plugin/testing/acceptance-tests)
- [terraform-plugin-sdk GitHub](https://github.com/hashicorp/terraform-plugin-sdk)
