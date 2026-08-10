---
name: provider-ephemeral-resources
description: >-
  Implement Terraform provider ephemeral resources with the Plugin
  Framework: the Open/Renew/Close lifecycle, ephemeral schema design,
  registration via EphemeralResources, renewal for expiring credentials,
  and how ephemeral values flow into write-only attributes and provider
  configuration. Use when adding an ephemeral resource, exposing
  secrets/tokens/certificates that must never persist in state or plan,
  deciding between an ephemeral resource and a data source, or wiring
  short-lived credentials from one provider into another.
license: MPL-2.0
metadata:
  lifecycle-status: active
  copyright: Copyright IBM Corp. 2026
  version: "0.0.1"
---

# Terraform Provider Ephemeral Resources

Ephemeral resources (Terraform 1.10+) produce values that are **never
persisted to state or plan**. They exist for exactly one job: handing
secrets — tokens, generated passwords, short-lived certificates, decrypted
values — to the parts of a configuration that need them, without writing
them to disk. Any data source that returns a sensitive value is a candidate
to be (or to also exist as) an ephemeral resource.

Official docs: [Ephemeral Resources](https://developer.hashicorp.com/terraform/plugin/framework/ephemeral-resources).

## When to Use One

| Situation | Use |
|---|---|
| Read-only lookup of non-sensitive data | Data source |
| Value is sensitive and only needed at apply time (DB password for a provider block, token for a write-only attribute) | Ephemeral resource |
| Sensitive value that downstream *managed resources* must store (e.g. as an attribute) | Regular resource/data source — but pair with write-only attributes where possible |
| Credential that expires mid-operation (STS-style tokens, short-TTL leases) | Ephemeral resource with `Renew` |

Ephemeral results can be used in provider configuration, write-only
attributes, provisioner configuration, and other ephemeral contexts — but
not in regular attributes, because those persist to state.

## Lifecycle

Terraform calls up to three methods per operation:

- **`Open`** (required) — fetch or create the value; runs during plan
  and/or apply whenever the result is needed. There is no state to refresh
  and nothing to import.
- **`Renew`** (optional) — called when the wall clock passes the
  `RenewAt` returned by `Open`/`Renew`, for values that expire while
  Terraform is still running. Renew cannot return a new result — it can
  only extend/refresh what `Open` produced (e.g. re-lease the same
  credential); if the value itself changes on renewal, the API is not
  renewable in this sense and `Open` must return a longer-lived value.
- **`Close`** (optional) — called when Terraform is done with the value;
  revoke leases or delete temporary credentials here.

`Open` can pass bytes forward via `resp.Private`; `Renew` and `Close`
receive them — use this for lease IDs needed to renew/revoke.

## Implementation

```go
var (
    _ ephemeral.EphemeralResource              = &tokenEphemeralResource{}
    _ ephemeral.EphemeralResourceWithConfigure = &tokenEphemeralResource{}
    _ ephemeral.EphemeralResourceWithRenew     = &tokenEphemeralResource{}
    _ ephemeral.EphemeralResourceWithClose     = &tokenEphemeralResource{}
)

func NewTokenEphemeralResource() ephemeral.EphemeralResource {
    return &tokenEphemeralResource{}
}

type tokenEphemeralResource struct {
    client *examplecloud.Client
}

type tokenEphemeralResourceModel struct {
    RoleName types.String `tfsdk:"role_name"`
    Token    types.String `tfsdk:"token"`
    LeaseID  types.String `tfsdk:"lease_id"`
}

func (r *tokenEphemeralResource) Metadata(_ context.Context, req ephemeral.MetadataRequest, resp *ephemeral.MetadataResponse) {
    resp.TypeName = req.ProviderTypeName + "_token"
}

func (r *tokenEphemeralResource) Schema(_ context.Context, _ ephemeral.SchemaRequest, resp *ephemeral.SchemaResponse) {
    resp.Schema = schema.Schema{
        Attributes: map[string]schema.Attribute{
            "role_name": schema.StringAttribute{
                Required:            true,
                MarkdownDescription: "Role to obtain a token for.",
            },
            "token": schema.StringAttribute{
                Computed:            true,
                Sensitive:           true,
                MarkdownDescription: "The issued token. Never persisted to state.",
            },
            "lease_id": schema.StringAttribute{
                Computed:            true,
                MarkdownDescription: "Identifier of the token lease.",
            },
        },
    }
}

func (r *tokenEphemeralResource) Open(ctx context.Context, req ephemeral.OpenRequest, resp *ephemeral.OpenResponse) {
    var data tokenEphemeralResourceModel
    resp.Diagnostics.Append(req.Config.Get(ctx, &data)...)
    if resp.Diagnostics.HasError() {
        return
    }

    lease, err := r.client.IssueToken(ctx, data.RoleName.ValueString())
    if err != nil {
        resp.Diagnostics.AddError(
            "Error opening Token",
            fmt.Sprintf("issuing token for role (%s): %s", data.RoleName.ValueString(), err),
        )
        return
    }

    data.Token = types.StringValue(lease.Token)
    data.LeaseID = types.StringValue(lease.ID)

    resp.RenewAt = lease.ExpiresAt.Add(-2 * time.Minute) // renew with margin
    resp.Private.SetKey(ctx, "lease_id", []byte(lease.ID))
    resp.Diagnostics.Append(resp.Result.Set(ctx, &data)...)
}

func (r *tokenEphemeralResource) Renew(ctx context.Context, req ephemeral.RenewRequest, resp *ephemeral.RenewResponse) {
    leaseID, diags := req.Private.GetKey(ctx, "lease_id")
    resp.Diagnostics.Append(diags...)
    if resp.Diagnostics.HasError() {
        return
    }

    lease, err := r.client.RenewLease(ctx, string(leaseID))
    if err != nil {
        resp.Diagnostics.AddError("Error renewing Token", err.Error())
        return
    }
    resp.RenewAt = lease.ExpiresAt.Add(-2 * time.Minute)
}

func (r *tokenEphemeralResource) Close(ctx context.Context, req ephemeral.CloseRequest, resp *ephemeral.CloseResponse) {
    leaseID, diags := req.Private.GetKey(ctx, "lease_id")
    resp.Diagnostics.Append(diags...)
    if resp.Diagnostics.HasError() {
        return
    }

    if err := r.client.RevokeLease(ctx, string(leaseID)); err != nil {
        resp.Diagnostics.AddError("Error closing Token", err.Error())
    }
}
```

`Configure` follows the same ProviderData-cast pattern as resources (the
`provider-resources` skill, if available, shows it); the client comes from
`resp.EphemeralResourceData` set in the provider's `Configure`.

## Registration

The provider opts in via `provider.ProviderWithEphemeralResources`:

```go
var _ provider.ProviderWithEphemeralResources = &examplecloudProvider{}

func (p *examplecloudProvider) EphemeralResources(_ context.Context) []func() ephemeral.EphemeralResource {
    return []func() ephemeral.EphemeralResource{
        NewTokenEphemeralResource(),
    }
}
```

Set `resp.EphemeralResourceData = client` in the provider's `Configure`
alongside `ResourceData`/`DataSourceData`.

## Design Rules

- **Never log the value, never put it in a diagnostic.** The whole point is
  non-persistence; an error message containing the token defeats it.
- Mark the secret attribute `Sensitive: true` anyway — it guards rendering
  in the ephemeral value's own lifecycle output.
- No plan modifiers, no import, no `id` convention — there is no state for
  any of them to act on.
- Schema inputs follow the same rules as data source arguments; expose the
  API's identifiers (`role_name`), not invented ones.
- Set `RenewAt` with a safety margin before the real expiry; Terraform
  renews lazily, not on a precise timer.
- If the upstream value cannot be revoked, skip `Close` rather than
  implementing a no-op that suggests revocation happens.

## Testing

Ephemeral results never reach state, so tests assert them indirectly — the
standard pattern echoes the ephemeral value through the `echoprovider` into
a regular resource the test can inspect. Minimum coverage: a basic
open-and-use test and per-attribute tests alongside required fields. Use
the `provider-test-patterns` skill (if available) — its ephemeral testing
reference covers the echoprovider setup, version gating
(`tfversion.SkipBelow(tfversion.Version1_10_0)`), and multi-step patterns.

## Documentation

Registry docs live at `docs/ephemeral-resources/<name>.md`, generated by
`tfplugindocs` like every other page type. Use the `provider-docs` skill
(if available) for the workflow; document the renewal/revocation behavior
explicitly — users need to know whether closing their Terraform run revokes
the credential.

## Checklist

- [ ] Value genuinely must not persist (otherwise a data source is simpler)
- [ ] `Open` implemented; `Renew`/`Close` only where the API supports them
- [ ] Secret attributes `Sensitive: true`; value never logged or in diagnostics
- [ ] Lease/handle passed via `Private`, not via the result
- [ ] `RenewAt` set with margin for expiring credentials
- [ ] Registered in `EphemeralResources()`; `EphemeralResourceData` set in provider Configure
- [ ] Echo-provider acceptance tests, version-gated to Terraform >= 1.10
- [ ] Docs page explains lifetime, renewal, and revocation behavior
