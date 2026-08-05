# SDKv2 → Plugin Framework Translation Reference

Mechanical mappings for porting a resource. Every row preserves the user's
configuration syntax and state layout — the invariant of a safe migration.

## Schema: types

| SDKv2 | Framework |
|---|---|
| `Type: schema.TypeString` | `schema.StringAttribute` |
| `Type: schema.TypeBool` | `schema.BoolAttribute` |
| `Type: schema.TypeInt` | `schema.Int64Attribute` |
| `Type: schema.TypeFloat` | `schema.Float64Attribute` |
| `Type: schema.TypeList, Elem: &schema.Schema{Type: schema.TypeString}` | `schema.ListAttribute{ElementType: types.StringType}` |
| `Type: schema.TypeSet, Elem: &schema.Schema{...}` | `schema.SetAttribute{ElementType: ...}` |
| `Type: schema.TypeMap, Elem: &schema.Schema{...}` | `schema.MapAttribute{ElementType: ...}` |
| `Type: schema.TypeList, Elem: &schema.Resource{...}` (block syntax in configs) | `schema.ListNestedBlock` under `Blocks:` — **not** a nested attribute (attribute syntax would break existing configs) |
| `Type: schema.TypeSet, Elem: &schema.Resource{...}` | `schema.SetNestedBlock` under `Blocks:` |
| `MaxItems: 1` block used as a pseudo-object | `ListNestedBlock` + `listvalidator.SizeAtMost(1)` for migrations; `SingleNestedAttribute` only for net-new schema |

## Schema: behaviors

| SDKv2 | Framework |
|---|---|
| `Required: true` / `Optional: true` / `Computed: true` | Same fields, same meanings |
| `ForceNew: true` | `PlanModifiers: []planmodifier.String{stringplanmodifier.RequiresReplace()}` |
| `Default: "foo"` | `Default: stringdefault.StaticString("foo")` (from `resource/schema/stringdefault`; requires `Computed: true` alongside `Optional`) |
| `ValidateFunc` / `ValidateDiagFunc` | `Validators: []validator.String{...}` (from `terraform-plugin-framework-validators`) |
| `ConflictsWith` / `ExactlyOneOf` / `AtLeastOneOf` / `RequiredWith` | `stringvalidator.ConflictsWith(path.Expressions...)`, `ExactlyOneOf(...)`, `AtLeastOneOf(...)`, `AlsoRequires(...)` |
| `Sensitive: true` | Same field |
| `Deprecated: "..."` | `DeprecationMessage: "..."` |
| `Description` | `Description` / `MarkdownDescription` |
| `DiffSuppressFunc` | No direct equivalent. Use a custom type with semantic equality (preferred; e.g. case-insensitive or JSON-normalized string types) or a plan modifier. If the suppression logic is intricate, reconsider migrating this resource |
| `StateFunc` | No equivalent — normalize in Create/Read before setting state, or use a custom type |
| `CustomizeDiff` | Resource-level plan modification: `ResourceWithModifyPlan.ModifyPlan`, or per-attribute plan modifiers |
| `Timeouts` in schema | `timeouts` block via `terraform-plugin-framework-timeouts`; read with `data.Timeouts.Create(ctx, defaultTimeout)` |

## Resource shape

| SDKv2 | Framework |
|---|---|
| `func resourceWidget() *schema.Resource` returning struct of funcs | Struct implementing `resource.Resource` (+ `ResourceWithConfigure`, `ResourceWithImportState`) |
| `CreateWithoutTimeout: resourceWidgetCreate` | `func (r *widgetResource) Create(ctx, req resource.CreateRequest, resp *resource.CreateResponse)` |
| `meta.(*Client)` in every CRUD func | Client stored once by `Configure(req.ProviderData)` |
| `Importer: &schema.ResourceImporter{StateContext: schema.ImportStatePassthroughContext}` | `func (r *widgetResource) ImportState(...)` calling `resource.ImportStatePassthroughID(ctx, path.Root("id"), req, resp)` |
| Registration in `ResourcesMap: map[string]*schema.Resource` | Constructor listed in the provider's `Resources() []func() resource.Resource` |

## Data access inside CRUD

| SDKv2 | Framework |
|---|---|
| `d.Get("name").(string)` | Typed model: `data.Name.ValueString()` after `req.Plan.Get(ctx, &data)` |
| `d.GetOk("name")` | `!data.Name.IsNull()` — and decide unknown handling explicitly (`IsUnknown()`) |
| `d.Set("name", v)` | Assign model field (`data.Name = types.StringPointerValue(v)`), then `resp.State.Set(ctx, &data)` |
| `d.SetId(id)` | Set the `id` model field like any attribute |
| `d.SetId("")` in Read (gone) | `resp.State.RemoveResource(ctx)` |
| `d.Id()` | `data.ID.ValueString()` from `req.State.Get` |
| `d.HasChange("field")` | Compare plan vs state models: `!plan.Field.Equal(state.Field)` |
| `d.IsNewResource()` | Does not exist — Create simply *is* the new-resource path; post-create read-retry logic moves into Create |
| `diag.Diagnostics` returns | `resp.Diagnostics.AddError/AddWarning/Append` |

## The null/zero trap (the migration's main behavioral risk)

SDKv2 collapses "not set" into Go zero values: `d.Get` on an unset string
returns `""`, an unset int `0`, an unset bool `false`. The Framework keeps
null, unknown, and zero distinct. Consequences:

```go
// SDKv2 — unset and "" are the same thing:
if v, ok := d.GetOk("description"); ok {
    input.Description = aws.String(v.(string))
}

// Framework — express the same "omit when not set" explicitly:
if !data.Description.IsNull() {
    input.Description = data.Description.ValueStringPointer()
}
```

Audit every attribute for three cases: user set a value, user set the zero
value (`""`, `0`, `false` — SDKv2 could not tell this apart from unset;
users may depend on either interpretation), and user omitted it. The API
must receive exactly what the SDKv2 version sent in each case, or existing
configurations change behavior. `ImportStateVerify` and empty-plan upgrade
tests catch most, not all, of these — grep for `GetOk` and zero-value
comparisons and reason through each.

## What does not change

- `retry.StateChangeConf` waiters and `retry.NotFoundError` finders — the
  `helper/retry` package works from Framework code; port them untouched.
- Acceptance tests — `terraform-plugin-testing` runs against the muxed
  provider; existing tests must pass unchanged (switch factories to
  `ProtoV6ProviderFactories` serving the muxed server).
- API client code, expand/flatten helpers operating on API types.

## Tooling

Some providers script the first pass (terraform-provider-aws has an
internal `tfsdk2fw` scaffolder). No public tool produces a safe migration
end-to-end — treat any generated port as a draft to audit against this
reference, especially the null/zero table above.
