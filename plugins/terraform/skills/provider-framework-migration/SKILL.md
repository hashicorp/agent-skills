---
name: provider-framework-migration
description: >-
  Migrate Terraform provider resources and data sources from Plugin SDKv2 to
  the Plugin Framework: muxing both plugins in one provider
  (terraform-plugin-mux, tf5to6server), per-resource migration workflow,
  SDKv2-to-Framework schema mapping (ForceNew, ValidateFunc,
  DiffSuppressFunc, Default, Timeouts, blocks), null-vs-zero-value
  behavioral traps, and state-compatibility verification. Use when
  converting or translating SDKv2 resources to the Framework, setting up a
  muxed provider server, deciding whether a resource should be migrated at
  all, or debugging plan diffs and state errors that appeared after a
  migration.
license: MPL-2.0
metadata:
  lifecycle-status: active
  copyright: Copyright IBM Corp. 2026
  version: "0.0.1"
---

# Migrating from Plugin SDKv2 to the Plugin Framework

The Plugin Framework is required for net-new resources and data sources;
SDKv2 is maintenance-only. Migration is **per-resource and incremental**: a
muxed provider serves SDKv2 and Framework implementations side by side, so
you never need a big-bang rewrite. This skill covers the mux setup, the
per-resource workflow, and the behavioral traps that turn a mechanical
translation into a silent breaking change.

**Reference** (load when needed):
- `references/schema-mapping.md` — the full SDKv2 → Framework translation
  table with code pairs

Official guide: [Framework migration](https://developer.hashicorp.com/terraform/plugin/framework/migrating).

## Decide Whether to Migrate at All

Migration has real risk and little user-visible payoff, so triage first:

- **Do not migrate complex or heavily-used resources** without a driving
  need (a Framework-only feature, a bug that SDKv2 cannot fix). The two
  SDKs differ behaviorally — most importantly around null versus zero
  values — and those differences surface as breaking changes for existing
  users. This is the standing policy in large providers like
  terraform-provider-aws.
- **Simple resources migrate safely**: flat schemas, no `DiffSuppressFunc`,
  no `CustomizeDiff`, no `StateFunc`, no complex nested blocks.
- New capabilities never require migrating old code — mux and write the new
  resource in the Framework alongside the old ones.

To tell what mode a provider is in, check `go.mod`: `terraform-plugin-mux`
present means it already serves both; only `terraform-plugin-sdk/v2` means
SDKv2-only (mux setup is your first step); only
`terraform-plugin-framework` means the migration is done.

## Step 1: Mux the Provider

Combine both plugin servers in `main.go`. Serving protocol version 6
requires upgrading the SDKv2 server with `tf5to6server` (protocol 6 needs
Terraform CLI >= 1.0; if you must support 0.12+, mux at protocol 5 with
`tf6to5server`/`tf5muxserver` instead — but the Framework provider then
cannot use protocol-6-only features like nested attributes):

```go
package main

import (
    "context"
    "flag"
    "log"

    "github.com/hashicorp/terraform-plugin-framework/providerserver"
    "github.com/hashicorp/terraform-plugin-go/tfprotov6"
    "github.com/hashicorp/terraform-plugin-go/tfprotov6/tf6server"
    "github.com/hashicorp/terraform-plugin-mux/tf5to6server"
    "github.com/hashicorp/terraform-plugin-mux/tf6muxserver"

    "example.org/terraform-provider-examplecloud/internal/provider"
    sdkprovider "example.org/terraform-provider-examplecloud/internal/sdkprovider"
)

func main() {
    var debug bool
    flag.BoolVar(&debug, "debug", false, "run with support for debuggers")
    flag.Parse()

    ctx := context.Background()

    upgradedSDKServer, err := tf5to6server.UpgradeServer(
        ctx,
        sdkprovider.Provider().GRPCProvider,
    )
    if err != nil {
        log.Fatal(err)
    }

    providers := []func() tfprotov6.ProviderServer{
        providerserver.NewProtocol6(provider.New(version)()),
        func() tfprotov6.ProviderServer { return upgradedSDKServer },
    }

    muxServer, err := tf6muxserver.NewMuxServer(ctx, providers...)
    if err != nil {
        log.Fatal(err)
    }

    var serveOpts []tf6server.ServeOpt
    if debug {
        serveOpts = append(serveOpts, tf6server.WithManagedDebug())
    }

    err = tf6server.Serve("registry.terraform.io/example/examplecloud",
        muxServer.ProviderServer, serveOpts...)
    if err != nil {
        log.Fatal(err)
    }
}
```

Mux requirements that bite in practice:

- **Provider schemas must match exactly** across both plugins — same
  provider-level attributes, same types, same descriptions. Keep one source
  of truth for the provider configuration and mirror it.
- **Each resource and data source may exist in only one** of the two
  plugins. Migration's final step is deleting the SDKv2 registration.
- If publishing to the Registry with protocol 6, set
  `"metadata": {"protocol_versions": ["6.0"]}` in
  `terraform-registry-manifest.json`.

## Step 2: Baseline Before You Touch Anything

The migrated resource must be indistinguishable to users. Prove it with
tests that exist *before* the migration:

1. Ensure the resource has passing acceptance coverage: `_basic` with an
   import step (`ImportStateVerify: true`), `_disappears`, and per-attribute
   update tests. If coverage is missing, write it against the SDKv2
   implementation first — these tests are the migration's acceptance
   criteria and must pass **unchanged** afterward.
2. Note behaviors tests don't capture: attribute defaults, what happens
   when optional attributes are omitted (null vs `""`/`0`/`false` is about
   to matter), and any `DiffSuppressFunc`/`StateFunc` normalization.

## Step 3: Port the Resource

Translate schema and CRUD using the mapping table in
`references/schema-mapping.md`. The rules that prevent breaking changes:

- **Blocks stay blocks.** An SDKv2 `Elem: &schema.Resource{...}` written as
  `block { ... }` syntax in user configs must become a Framework **Block**
  (`schema.ListNestedBlock`/`SetNestedBlock`) — converting it to a nested
  *attribute* changes the HCL syntax users must write, which is a breaking
  change. Nested attributes are for new schema only.
- **Null is not zero.** SDKv2 `d.Get("name")` returned `""` for unset;
  the Framework model gives you `types.String` that distinguishes null,
  unknown, and `""`. Everywhere the old code checked `== ""` or relied on
  `GetOk`, decide explicitly what null means, and make sure you send the
  API the same thing SDKv2 sent (usually: omit the field when null).
- **Keep the `id` attribute.** Net-new Framework resources may omit a
  redundant `id`, but a *migrated* resource must keep its exact schema —
  removing or renaming attributes breaks existing state and configs.
- **State must round-trip.** The Framework reads the state SDKv2 wrote. If
  every attribute keeps its name and type, no state upgrade is needed. If
  the old schema stored a value the new types package normalizes
  differently, you need a `StateUpgrader` — treat that as a signal the
  resource may be in the do-not-migrate bucket.

## Step 4: Move the Registration

Register the resource in the Framework provider's `Resources()` and delete
it from the SDKv2 provider's `ResourcesMap` in the same commit — mux errors
on duplicates.

## Step 5: Verify

1. The pre-existing acceptance tests pass **without modification** —
   especially `ImportStateVerify`, which diffs imported state against
   stored state and catches most null-vs-zero regressions.
2. Add a state-compatibility step: apply a config with the last released
   (SDKv2) provider version, then plan with the migrated build — the plan
   must be empty. In `terraform-plugin-testing` this is a two-step test
   using `ExternalProviders` for the old version, then
   `ProtoV6ProviderFactories` with `ConfigPlanChecks` asserting an empty
   plan. The `provider-test-patterns` skill (if available) documents the
   pattern.
3. `terraform plan` against a real pre-migration state file shows no diff.

## Checklist

- [ ] Resource is simple enough to migrate (no complex diff customization), or there's a driving need
- [ ] Mux serves both plugins; provider-level schemas identical in both
- [ ] Acceptance tests existed before migration and pass unchanged after
- [ ] Blocks remained blocks; attribute names and types unchanged; `id` kept
- [ ] Null/omitted semantics preserved (API receives what SDKv2 sent)
- [ ] SDKv2 registration removed in the same change
- [ ] Empty-plan verified against state written by the previous release
- [ ] Changelog entry added, if the repo tracks release notes

## Related Skills

Use the `provider-resources` skill (if available) for Framework CRUD,
finder, and waiter patterns in the ported code, and `provider-test-patterns`
for the regression and version-upgrade test patterns.
