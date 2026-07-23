---
name: provider-resources
description: >-
  Implement Terraform Provider resources and data sources using the Plugin
  Framework: CRUD operations, schema design, plan modifiers and validators,
  not-found handling, waiters for eventually consistent APIs, import support,
  resource design principles, and required acceptance test coverage. Use when
  adding or changing a resource or data source, deciding whether an API
  concept should be a resource, wiring a resource to the provider's
  configured client, handling drift or resource-not-found, or reviewing a
  resource implementation before submission.
license: MPL-2.0
metadata:
  copyright: Copyright IBM Corp. 2026
  version: "0.0.1"
---

# Terraform Provider Resources Implementation Guide

## Overview

This guide covers developing Terraform Provider resources and data sources.
Resources represent infrastructure objects that Terraform manages through
Create, Read, Update, and Delete (CRUD) operations.

**Use the [Plugin Framework](https://developer.hashicorp.com/terraform/plugin/framework)
for all net-new resources and data sources.** Plugin SDKv2 is for maintaining
resources that already exist on it; do not write new code against it. A
provider can serve both during migration by muxing
([terraform-plugin-mux](https://developer.hashicorp.com/terraform/plugin/mux)),
so adopting the Framework never requires a big-bang rewrite. To tell which
mode an existing provider is in, check `go.mod`: `terraform-plugin-mux`
present means it serves both SDKv2 and Framework code; only
`terraform-plugin-sdk/v2` means SDKv2-only; only
`terraform-plugin-framework` means Framework-only. Be cautious about
*migrating* existing SDKv2 resources: the Framework distinguishes null from
zero values, so naive migrations change behavior for existing users (use the
`provider-framework-migration` skill, if available).

**References** (load when needed):
- `references/design-principles.md` — what should (and should not) become a
  resource; data source semantics; relationship and async-task modeling
- `references/retries-and-waiters.md` — eventual consistency, retry
  patterns, and status/wait function structure

## File Structure

Most providers keep every resource in a single package:

```
internal/provider/
├── provider.go                  # Provider schema + Configure
├── widget_resource.go           # Resource implementation
├── widget_resource_test.go      # Acceptance tests
├── widget_data_source.go        # Data source (if applicable)
└── widget_data_source_test.go
```

Large multi-service providers (e.g. terraform-provider-aws) split into
`internal/service/<service>/` packages instead, with an idiomatic file
taxonomy worth adopting once a package grows: `consts.go`, `find.go`
(finders), `status.go` (status functions), `wait.go` (waiters), `sweep.go`
(test sweepers), `exports_test.go`.

Documentation lives in `docs/` and is generated with `tfplugindocs`:

```
docs/
├── resources/<name>.md          # generated; optional <name>.md.tmpl template
└── data-sources/<name>.md
```

(Hand-written `website/docs/r/*.html.markdown` trees exist in some older,
large providers — follow the target repo's convention when editing one.)

## Resource Structure

A Framework resource is a struct holding the API client, with interface
assertions making the implemented behaviors explicit:

```go
var (
    _ resource.Resource                = &widgetResource{}
    _ resource.ResourceWithConfigure   = &widgetResource{}
    _ resource.ResourceWithImportState = &widgetResource{}
)

func NewWidgetResource() resource.Resource {
    return &widgetResource{}
}

type widgetResource struct {
    client *examplecloud.Client
}

func (r *widgetResource) Metadata(_ context.Context, req resource.MetadataRequest, resp *resource.MetadataResponse) {
    resp.TypeName = req.ProviderTypeName + "_widget"
}

// Configure receives the client the provider built in its own Configure.
func (r *widgetResource) Configure(_ context.Context, req resource.ConfigureRequest, resp *resource.ConfigureResponse) {
    if req.ProviderData == nil {
        return // provider not yet configured (e.g. validation phase)
    }
    client, ok := req.ProviderData.(*examplecloud.Client)
    if !ok {
        resp.Diagnostics.AddError(
            "Unexpected Resource Configure Type",
            fmt.Sprintf("Expected *examplecloud.Client, got: %T.", req.ProviderData),
        )
        return
    }
    r.client = client
}

func (r *widgetResource) Schema(ctx context.Context, req resource.SchemaRequest, resp *resource.SchemaResponse) {
    resp.Schema = schema.Schema{
        Attributes: map[string]schema.Attribute{
            "name": schema.StringAttribute{
                Required: true,
                PlanModifiers: []planmodifier.String{
                    stringplanmodifier.RequiresReplace(),
                },
                Validators: []validator.String{
                    stringvalidator.LengthBetween(1, 255),
                },
            },
            "id": schema.StringAttribute{
                Computed: true,
                PlanModifiers: []planmodifier.String{
                    stringplanmodifier.UseStateForUnknown(),
                },
            },
        },
    }
}
```

How the provider's `Configure` produces that client — schema, credential
resolution, validation — is covered by the `provider-configuration` skill
(if available).

**On `id`:** SDKv2 required a magic `id` attribute; the Framework does not.
If the API has its own identifier, expose it under its real meaning and do
not add a second, redundant `id`. Only keep `id` when it *is* the API's
identifier (as above).

## CRUD Operations

### Create

```go
func (r *widgetResource) Create(ctx context.Context, req resource.CreateRequest, resp *resource.CreateResponse) {
    var data widgetResourceModel
    resp.Diagnostics.Append(req.Plan.Get(ctx, &data)...)
    if resp.Diagnostics.HasError() {
        return
    }

    input := &examplecloud.CreateWidgetInput{
        Name: data.Name.ValueStringPointer(),
    }

    output, err := r.client.CreateWidget(ctx, input)
    if err != nil {
        resp.Diagnostics.AddError(
            "Error creating Widget",
            fmt.Sprintf("creating Widget (%s): %s", data.Name.ValueString(), err),
        )
        return
    }

    data.ID = types.StringPointerValue(output.ID)

    // For eventually consistent APIs, wait for the resource to be usable
    // before returning — see references/retries-and-waiters.md.

    resp.Diagnostics.Append(resp.State.Set(ctx, &data)...)
}
```

### Read

Read must handle out-of-band deletion by removing the resource from state so
the next plan recreates it, rather than erroring forever:

```go
func (r *widgetResource) Read(ctx context.Context, req resource.ReadRequest, resp *resource.ReadResponse) {
    var data widgetResourceModel
    resp.Diagnostics.Append(req.State.Get(ctx, &data)...)
    if resp.Diagnostics.HasError() {
        return
    }

    output, err := findWidgetByID(ctx, r.client, data.ID.ValueString())
    if isNotFound(err) {
        tflog.Warn(ctx, "Widget not found, removing from state", map[string]any{"id": data.ID.ValueString()})
        resp.State.RemoveResource(ctx)
        return
    }
    if err != nil {
        resp.Diagnostics.AddError(
            "Error reading Widget",
            fmt.Sprintf("reading Widget (%s): %s", data.ID.ValueString(), err),
        )
        return
    }

    data.Name = types.StringPointerValue(output.Name)

    resp.Diagnostics.Append(resp.State.Set(ctx, &data)...)
}
```

### Update

Only call the API for attributes that actually changed; compare plan against
state:

```go
func (r *widgetResource) Update(ctx context.Context, req resource.UpdateRequest, resp *resource.UpdateResponse) {
    var plan, state widgetResourceModel
    resp.Diagnostics.Append(req.Plan.Get(ctx, &plan)...)
    resp.Diagnostics.Append(req.State.Get(ctx, &state)...)
    if resp.Diagnostics.HasError() {
        return
    }

    if !plan.Description.Equal(state.Description) {
        input := &examplecloud.UpdateWidgetInput{
            ID:          plan.ID.ValueStringPointer(),
            Description: plan.Description.ValueStringPointer(),
        }
        if _, err := r.client.UpdateWidget(ctx, input); err != nil {
            resp.Diagnostics.AddError(
                "Error updating Widget",
                fmt.Sprintf("updating Widget (%s): %s", plan.ID.ValueString(), err),
            )
            return
        }
    }

    resp.Diagnostics.Append(resp.State.Set(ctx, &plan)...)
}
```

### Delete

Treat "already gone" as success — the desired end state is reached:

```go
func (r *widgetResource) Delete(ctx context.Context, req resource.DeleteRequest, resp *resource.DeleteResponse) {
    var data widgetResourceModel
    resp.Diagnostics.Append(req.State.Get(ctx, &data)...)
    if resp.Diagnostics.HasError() {
        return
    }

    _, err := r.client.DeleteWidget(ctx, &examplecloud.DeleteWidgetInput{
        ID: data.ID.ValueStringPointer(),
    })
    if isNotFound(err) {
        return
    }
    if err != nil {
        resp.Diagnostics.AddError(
            "Error deleting Widget",
            fmt.Sprintf("deleting Widget (%s): %s", data.ID.ValueString(), err),
        )
        return
    }
}
```

### Import

With `ResourceWithImportState` asserted, passthrough of the identifier is
one line:

```go
func (r *widgetResource) ImportState(ctx context.Context, req resource.ImportStateRequest, resp *resource.ImportStateResponse) {
    resource.ImportStatePassthroughID(ctx, path.Root("id"), req, resp)
}
```

For multi-part identifiers, parse a delimited import ID (commonly
comma-separated) and set each attribute explicitly.

## Resource Design Principles

Before implementing, check the shape of the thing being modeled (full
treatment in `references/design-principles.md`):

- A resource is the *smallest* useful building block; if the API offers
  CRUD for it, it likely deserves its own resource.
- A resource should talk to **one** API/service only — cross-service
  resources break permissions, auditing, and endpoint configuration.
- Data sources are read-only and side-effect free. A *singular* data source
  errors on zero or multiple matches; a *plural* data source (plural noun
  name) returns zero-or-more as a collection and errors on neither.
- Attached policies/rules, long-running task invocations, and versioned
  artifacts usually deserve their *own* resources rather than attributes on
  the parent.
- Start/stop or enable/disable state belongs as an attribute *in* the
  resource, not as a separate resource.

## Schema Design

### Attribute Types

| Terraform Type | Framework Type | Use Case |
|----------------|----------------|----------|
| `string` | `schema.StringAttribute` | Names, identifiers |
| `number` | `schema.Int64Attribute`, `schema.Float64Attribute` | Counts, sizes |
| `bool` | `schema.BoolAttribute` | Feature flags |
| `list` | `schema.ListAttribute` | Ordered collections |
| `set` | `schema.SetAttribute` | Unordered unique items |
| `map` | `schema.MapAttribute` | Key-value pairs |
| `object` | `schema.SingleNestedAttribute` | Complex nested config |

Give every attribute a `MarkdownDescription` — `tfplugindocs` publishes it,
and it is the primary user-facing documentation.

### Plan Modifiers

```go
// Force replacement when value changes
stringplanmodifier.RequiresReplace()

// Keep a known value during plan instead of (known after apply)
stringplanmodifier.UseStateForUnknown()
```

### Validators

```go
stringvalidator.LengthBetween(1, 255)
stringvalidator.RegexMatches(regexp.MustCompile(`^[a-z0-9-]+$`), "must be lowercase alphanumeric with hyphens")
stringvalidator.OneOf("small", "medium", "large")
int64validator.Between(1, 100)
listvalidator.SizeAtLeast(1)
```

### Sensitive Attributes

```go
"password": schema.StringAttribute{
    Required:  true,
    Sensitive: true,
},
```

## State Management

### Finders

Centralize "get one thing or a typed not-found" in a finder so Read, Delete,
waiters, and tests all share identical not-found semantics:

```go
func findWidgetByID(ctx context.Context, client *examplecloud.Client, id string) (*examplecloud.Widget, error) {
    output, err := client.GetWidget(ctx, &examplecloud.GetWidgetInput{ID: &id})
    if err != nil {
        var apiErr *examplecloud.NotFoundError
        if errors.As(err, &apiErr) {
            return nil, &retry.NotFoundError{LastError: err}
        }
        return nil, fmt.Errorf("getting Widget (%s): %w", id, err)
    }
    if output == nil || output.Widget == nil {
        return nil, &retry.NotFoundError{Message: "empty result"}
    }
    return output.Widget, nil
}

func isNotFound(err error) bool {
    var nfe *retry.NotFoundError
    return errors.As(err, &nfe)
}
```

### Waiting for Resource States

Many APIs return from Create/Delete before the resource is usable/gone. Use
`retry.StateChangeConf` (from
`github.com/hashicorp/terraform-plugin-sdk/v2/helper/retry` — usable from
Framework providers), with a status function built on the finder and
timeouts in named constants:

```go
stateConf := &retry.StateChangeConf{
    Pending: []string{"CREATING", "PENDING"},
    Target:  []string{"ACTIVE"},
    Refresh: statusWidget(ctx, r.client, id), // one poll of the finder: (obj, status, err)
    Timeout: widgetCreatedTimeout,
}
outputRaw, err := stateConf.WaitForStateContext(ctx)
```

The full status/wait function pairs (create and delete waiters, failure-state
handling, post-create not-found retries, eventual-consistency patterns) are
in `references/retries-and-waiters.md` — read it whenever the API is
asynchronous or eventually consistent.

## Testing

Every resource ships with, at minimum:

- **`_basic`** — create with minimal config, assert attributes, then an
  import step (`ImportState: true`, `ImportStateVerify: true`)
- **`_disappears`** — delete the object out-of-band mid-test; the next plan
  must propose recreation, not error
- **Per-attribute tests** — exercise updates for each non-trivial argument

Naming grammar: tests `TestAcc{Resource}_{group?}_{description}`, helpers
`testAccCheck{Resource}Exists` / `testAccCheck{Resource}Destroy`, config
functions `testAcc{Resource}Config_{description}`. Keep configs
self-contained, randomize real resource names, and never hardcode
environment-specific values (account IDs, zones, versions).

```go
func TestAccWidget_basic(t *testing.T) {
    rName := acctest.RandStringFromCharSet(10, acctest.CharSetAlphaNum)
    resourceName := "examplecloud_widget.test"

    resource.ParallelTest(t, resource.TestCase{
        PreCheck:                 func() { testAccPreCheck(t) },
        ProtoV6ProviderFactories: testAccProtoV6ProviderFactories,
        CheckDestroy:             testAccCheckWidgetDestroy,
        Steps: []resource.TestStep{
            {
                Config: testAccWidgetConfig_basic(rName),
                ConfigStateChecks: []statecheck.StateCheck{
                    statecheck.ExpectKnownValue(resourceName, tfjsonpath.New("name"), knownvalue.StringExact(rName)),
                    statecheck.ExpectKnownValue(resourceName, tfjsonpath.New("id"), knownvalue.NotNull()),
                },
            },
            {
                ResourceName:      resourceName,
                ImportState:       true,
                ImportStateVerify: true,
            },
        },
    })
}

func testAccWidgetConfig_basic(rName string) string {
    return fmt.Sprintf(`
resource "examplecloud_widget" "test" {
  name = %[1]q
}
`, rName)
}
```

Use the `provider-test-patterns` skill (if available) for the full testing
treatment: config helper style (`%[1]q` indexed verbs), statecheck/plancheck,
CompareValue, custom StateCheck implementations for exists/disappears
helpers, sweepers, and ephemeral resource testing. Use the
`run-acceptance-tests` skill for executing and debugging test runs.

## Error Handling

Match API errors by type, not message text, and wrap with context:

```go
var notFound *examplecloud.NotFoundError
if errors.As(err, &notFound) {
    // resource doesn't exist
}

// Wrapping inside helpers: preserve the cause with %w
return fmt.Errorf("creating Widget (%s): %w", name, err)
```

Diagnostics follow a consistent grammar — summary names the operation and
type, detail carries identifier and cause:

```go
resp.Diagnostics.AddError(
    "Error creating Widget",
    fmt.Sprintf("creating Widget (%s): %s", name, err),
)

resp.Diagnostics.AddAttributeError(
    path.Root("name"),
    "Invalid name",
    "Name must be lowercase alphanumeric",
)
```

## Documentation

Write attribute `MarkdownDescription`s first — they are the source of
truth. Then generate Registry documentation with `tfplugindocs`
(`go generate ./...` where wired up), adding `docs/**/*.md.tmpl` templates
only for prose and examples the generator cannot derive. Use the
`provider-docs` skill (if available) for the full documentation workflow and
Registry publication rules.

## Pre-Submission Checklist

- [ ] Plugin Framework used (no new SDKv2 code)
- [ ] Resource has all CRUD operations implemented
- [ ] Read removes missing resources from state; Delete tolerates already-deleted
- [ ] No redundant `id` attribute (real API identifier exposed instead)
- [ ] Import implemented and covered by an `ImportStateVerify` step
- [ ] `_basic`, `_disappears`, and per-attribute tests present
- [ ] Waiters used where the API is eventually consistent
- [ ] Error messages name the operation, type, and identifier
- [ ] Sensitive attributes marked; every attribute has a description
- [ ] Docs generated with `tfplugindocs`
- [ ] Changelog entry added, if the repo tracks release notes (check CONTRIBUTING)

## References

- [Terraform Plugin Framework](https://developer.hashicorp.com/terraform/plugin/framework)
- [Resource Development](https://developer.hashicorp.com/terraform/plugin/framework/resources)
- [Data Source Development](https://developer.hashicorp.com/terraform/plugin/framework/data-sources)
- [HashiCorp Provider Design Principles](https://developer.hashicorp.com/terraform/plugin/best-practices/hashicorp-provider-design-principles)
