# Resource and Data Source Design Principles

Distilled from HashiCorp's
[Provider Design Principles](https://developer.hashicorp.com/terraform/plugin/best-practices/hashicorp-provider-design-principles)
and the conventions of large production providers (notably
terraform-provider-aws). Apply these *before* writing code — most painful
provider mistakes are modeling mistakes.

## Providers wrap a single API surface

A provider abstracts one platform's API/SDK into Terraform's lifecycle. Keep
out of a provider:

- Raw HTTP/protocol clients bolted onto an SDK-based provider
- Functionality that requires extra binaries or agents on the host running
  Terraform
- Data sources whose only purpose is exporting the provider's own
  credentials to other configuration (a credential-exfiltration hazard)

## Resources: the smallest useful building block

**Heuristic: if the API offers create/read/(update)/delete for a thing, that
thing is a resource.** Prefer many small resources over one large one —
practitioners compose small blocks far more easily than they fight a
mega-resource with intertwined attribute behaviors.

**One resource, one API.** A resource should call a single service's API.
Cross-service resources look convenient but:

- force users to grant permissions for services they may not know are
  involved,
- scatter audit trails across services,
- break per-service endpoint/partition configuration, and
- silently break one service's users when the other service changes.

If two services must cooperate, model each side as its own resource and let
configuration connect them.

## Relationship and lifecycle modeling

| API concept | Model as |
|---|---|
| Attached policy / rule document | Separate resource referencing the parent, not a blob attribute on the parent |
| One-to-many attachment (e.g. member of group) | Separate "attachment/membership" resource |
| Start/stop/enable/disable running state | An attribute *in* the resource — a separate "power state" resource fights the parent's lifecycle |
| Long-running task / job / operation the API exposes | Separate resource representing the task; Create starts it, Read polls it |
| Invitation / handshake / approval flows | Resource on the accepting side: Create = accept, Read = status, Delete = reject/leave |
| Versioned artifact (function version, template version) | Usually a separate `<thing>_version` resource so versions can pin and iterate independently |

When a single API object has two defensible modelings (one resource with
nested attributes vs. parent + child resources), prefer the one whose
*update* semantics match the API: if children can be added/removed
independently server-side, separate resources avoid the classic
"whole-list replacement" diff problem — but never ship both patterns for the
same underlying collection without conflict warnings in both.

## Data sources

Data sources are read-only views. They must not create, modify, or delete
anything, ever — a data source with side effects breaks `terraform plan`'s
promise of being safe to run.

**Singular data sources** (`examplecloud_widget`) fetch exactly one object:

- zero matches → error ("no Widget matched; adjust the filters")
- more than one match → error ("multiple Widgets matched; add filters until
  exactly one matches")

Returning an arbitrary element instead of erroring hides real environmental
problems and produces non-deterministic plans.

**Plural data sources** (`examplecloud_widgets`) fetch a collection:

- return zero-or-more as a list/set attribute
- zero matches is a *valid, empty* result, not an error
- name them with the plural noun; keep filters consistent with the singular
  form

## Naming

- Resource type: `<provider>_<service?>_<noun>`, all lowercase snake_case,
  noun derived from the API's own CRUD operation names (`CreateWidget` →
  `_widget`) so users can map docs ↔ API.
- Go: factory functions `NewWidgetResource`, correct initialisms in
  MixedCaps (`VPCEndpoint`, not `VpcEndpoint`).
- Attribute names: snake_case translations of the API's field names; do not
  invent new vocabulary the API's docs won't explain.

## When *not* to add a resource

- The "resource" is really an RPC with no persistent object behind it — a
  provider **action** may fit better (see the `provider-actions` skill, if
  available).
- The object is read-only in the API → data source.
- The object is a singleton account-level setting that cannot be created or
  destroyed → resource with Create = adopt/configure and Delete = reset to
  defaults, documented as such; or omit it.
