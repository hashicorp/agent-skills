---
name: provider-configuration
description: >-
  Implement Terraform provider configuration and authentication with the
  Plugin Framework: provider schema for credentials (Optional + Sensitive
  attributes), environment variable fallbacks, credential provider chains
  (static config > environment variables > shared credentials file >
  platform identity), unknown-value guards in Configure(), secret redaction,
  configure-time credential validation, and diagnostics that name every
  source tried. Use when implementing or reviewing a provider's Configure
  method or provider schema, adding authentication options (API keys,
  tokens, profiles, credentials files, assume-role), deciding how a provider
  should resolve credentials, debugging "no valid credential sources" or
  missing-credentials errors, or unit testing credential resolution.
license: MPL-2.0
metadata:
  lifecycle-status: active
  copyright: Copyright IBM Corp. 2026
  version: "0.0.1"
---

# Terraform Provider Configuration and Authentication

How a provider accepts connection settings and resolves credentials. Poor
authentication UX is the first thing every user of a provider hits; a
well-designed credential provider chain is what separates a production-grade
provider from a demo. The examples use a fictional `examplecloud` provider
and the [Plugin Framework](https://developer.hashicorp.com/terraform/plugin/framework/providers).

**References** (load when needed):
- `references/credential-chain.md` — complete, compilable credential chain
  implementation (providers, chain, file profiles, Configure wiring, tests)
- `references/case-studies.md` — how the AWS provider (`aws-sdk-go-base`)
  and smaller providers structure real credential chains

---

## Provider Schema for Authentication

Every authentication attribute must be `Optional`, never `Required` — a
`Required` attribute forces users to put credentials in configuration and
makes environment-variable and credentials-file resolution impossible. Mark
secrets `Sensitive` so Terraform redacts them in plan output, and state the
environment-variable fallback in each description so `tfplugindocs` publishes
the resolution rules.

```go
func (p *examplecloudProvider) Schema(ctx context.Context, req provider.SchemaRequest, resp *provider.SchemaResponse) {
    resp.Schema = schema.Schema{
        Attributes: map[string]schema.Attribute{
            "endpoint": schema.StringAttribute{
                Optional:            true,
                MarkdownDescription: "API endpoint. May also be set via the `EXAMPLECLOUD_ENDPOINT` environment variable.",
            },
            "api_key": schema.StringAttribute{
                Optional:            true,
                MarkdownDescription: "API key. May also be set via the `EXAMPLECLOUD_API_KEY` environment variable, or in a shared credentials file.",
            },
            "api_secret": schema.StringAttribute{
                Optional:            true,
                Sensitive:           true,
                MarkdownDescription: "API secret. May also be set via the `EXAMPLECLOUD_API_SECRET` environment variable, or in a shared credentials file.",
            },
            "profile": schema.StringAttribute{
                Optional:            true,
                MarkdownDescription: "Named profile in the shared credentials file. May also be set via the `EXAMPLECLOUD_PROFILE` environment variable. Defaults to `default`.",
            },
            "skip_credentials_validation": schema.BoolAttribute{
                Optional:            true,
                MarkdownDescription: "Skip the identity check normally performed during provider configuration.",
            },
        },
    }
}
```

Never add a `Default` to a credential attribute, and never hardcode a
credential anywhere in the provider. Defaults belong in the resolution logic
(where environment variables and files can override them), not in the schema.

## The Credential Provider Chain

Resolve credentials by consulting an ordered list of sources and taking the
first one that produces a **complete** set. This is the pattern the AWS
provider uses via [`aws-sdk-go-base`](https://github.com/hashicorp/aws-sdk-go-base),
and it generalizes to any provider. The canonical precedence, highest first:

1. **Static configuration** — values set directly in the `provider` block.
   Explicit always wins.
2. **Environment variables** — `EXAMPLECLOUD_API_KEY`, etc. The CI-friendly
   path.
3. **Shared credentials file** — named profiles in
   `~/.examplecloud/credentials`, for humans with multiple accounts.
4. **Platform identity** — instance metadata, workload identity, or OIDC
   token exchange, where the platform offers it. Credentials nobody has to
   store.

Two rules make the chain predictable:

- **Resolve secrets as a set, not field-by-field.** If the environment
  supplies an API key but no secret, that source offers nothing — fall
  through to the next source for *both* values. Mixing an env-var key with a
  file-profile secret produces authentication failures that are nearly
  impossible for users to debug.
- **Resolve non-secret connection settings field-by-field.** `endpoint`,
  `profile`, or `insecure` can each independently follow
  config > env > file > default, because a mismatch there is visible and
  harmless.

The core abstraction is a single-method interface with a sentinel error that
distinguishes "this source has nothing to offer" (fall through) from "this
source is misconfigured" (surface it):

```go
// ErrNoCredentials signals a source had nothing to offer. The chain falls
// through to the next source. Any other error means the source was
// configured but unusable (e.g. malformed credentials file) and is
// preserved so the final diagnostics can surface it.
var ErrNoCredentials = errors.New("no credentials found")

type Credentials struct {
    APIKey    string
    APISecret string
    Source    string // which provider supplied them, for logging
}

func (c Credentials) Complete() bool {
    return c.APIKey != "" && c.APISecret != ""
}

type Provider interface {
    Retrieve(ctx context.Context) (Credentials, error)
    Name() string
}
```

A `Chain` (itself a `Provider`, so chains compose) walks the providers in
order and returns the first complete set of credentials. Every skipped
source is recorded into an aggregate `ChainError` whose `Error()` lists each
source with the reason it was skipped, and whose `Is` method makes
`errors.Is(err, ErrNoCredentials)` true only when every source fell through
cleanly — so `Configure` can tell "nothing supplied" from "something
supplied but broken" with one check. The full implementation — the chain
loop, the static, environment, and file providers, and the
`NewDefaultChain` constructor that owns the canonical order — lives in
`references/credential-chain.md`.

## Wiring the Chain into Configure

`Configure` runs once per Terraform operation, before any resource CRUD.
The shape:

```go
func (p *examplecloudProvider) Configure(ctx context.Context, req provider.ConfigureRequest, resp *provider.ConfigureResponse) {
    var config examplecloudProviderModel
    resp.Diagnostics.Append(req.Config.Get(ctx, &config)...)
    if resp.Diagnostics.HasError() {
        return
    }

    // 1. Guard against unknown values (e.g. api_key = some_resource.output).
    if config.APIKey.IsUnknown() {
        resp.Diagnostics.AddAttributeError(
            path.Root("api_key"),
            "Unknown API Key",
            "The provider cannot connect because api_key depends on a value known only after apply. "+
                "Set a static value, or use the EXAMPLECLOUD_API_KEY environment variable.",
        )
    }
    // ... repeat for each auth attribute, then:
    if resp.Diagnostics.HasError() {
        return
    }

    // 2. Resolve credentials through the chain.
    chain := credentials.NewDefaultChain(
        config.APIKey.ValueString(),
        config.APISecret.ValueString(),
        credentials.Options{Profile: config.Profile.ValueString()},
    )
    creds, err := chain.Retrieve(ctx)
    if err != nil {
        if errors.Is(err, credentials.ErrNoCredentials) {
            resp.Diagnostics.AddError(
                "No Valid Credential Sources Found",
                "No examplecloud credentials were found. Sources tried, in order:\n\n"+err.Error()+
                    "\n\nSet api_key and api_secret in the provider block, export "+
                    "EXAMPLECLOUD_API_KEY and EXAMPLECLOUD_API_SECRET, or add a profile to "+
                    "~/.examplecloud/credentials. See https://example.com/docs/auth.",
            )
        } else {
            resp.Diagnostics.AddError("Failed to Resolve Credentials", err.Error())
        }
        return
    }
    tflog.Debug(ctx, "resolved credentials", map[string]any{"source": creds.Source})

    // 3. Build the client once; share it with every resource and data source.
    client := examplecloud.NewClient(endpoint, creds.APIKey, creds.APISecret)
    resp.DataSourceData = client
    resp.ResourceData = client
}
```

Why each step matters:

- **Unknown-value guards.** During planning, an attribute wired to another
  resource's output is *unknown*, not null. Without the guard the provider
  silently treats it as empty, falls through the chain, and authenticates as
  the wrong identity — or fails with a misleading "missing credentials"
  error. Name the environment-variable workaround in the guard message.
- **The sentinel check picks the right message.** "You gave me nothing"
  (actionable list of options) is a different failure from "you gave me
  something broken" (show the parse error). Collapsing them into one message
  is how providers end up with users pasting secrets into config to debug.
- **Log the source, never the secret.** Knowing *which* source won is the
  single most useful debugging fact and costs nothing to log.

## Diagnostics That Unblock Users

An authentication error message is the provider's most-read documentation.
Every credential failure diagnostic should name:

- **Every source tried, in order, with why it was skipped** — the
  `ChainError` provides this. `aws-sdk-go-base` does the same with its
  `NoValidCredentialSourcesError`.
- **The exact environment variable names** and the credentials file path and
  profile that were consulted — not "set the appropriate environment
  variables".
- **A documentation URL** for the provider's authentication guide.

Use warnings (not errors) for conditions that are suspicious but not fatal,
naming what took precedence: a `profile` set while environment credentials
are also present (which wins?), or a credentials file with group/world-read
permissions (suggest `chmod 0600`).

## Secret Hygiene

- Give the `Credentials` type `String()` and `GoString()` methods that
  redact secret fields, so a stray `%v`, `%+v`, or error wrap can never leak
  a secret into logs or diagnostics.
- Never include credential *values* in diagnostics, log lines, or wrapped
  errors — log the source name and non-secret identifiers only.
- Warn when a credentials file is readable by other users
  (`info.Mode().Perm()&0o077 != 0`); skip this check on Windows, where POSIX
  permission bits are not meaningful.

## Configure-Time Validation

Resolve the chain eagerly in `Configure` — never lazily on first resource
use — so a credentials problem fails one time, at plan, with a good message,
instead of failing in the middle of an apply. If the API has a cheap
identity endpoint (the equivalent of AWS `sts:GetCallerIdentity` or a
`/whoami`), call it after resolving credentials so *invalid* (not just
missing) credentials also fail at configure time. Gate it behind a
`skip_credentials_validation` attribute for air-gapped or stubbed
environments.

## Unit Testing the Chain

The chain is pure logic — test it with unit tests (`Test` prefix, no
`TF_ACC`), not acceptance tests. Make the environment injectable (a
`getenv func(string) string` field defaulting to `os.Getenv`, or use
`t.Setenv`) and point the file provider at `t.TempDir()` fixtures. The
tests that matter:

- **Per-source**: each provider returns its credentials when set and
  `ErrNoCredentials` when incomplete (a key with no secret is incomplete).
- **Precedence**: static beats env; env beats file; chain falls through to
  the file when nothing above supplies a complete set.
- **Failure aggregation**: with all sources empty,
  `errors.Is(err, ErrNoCredentials)` is true and the message names every
  source.
- **Hard errors**: a malformed credentials file or an *explicitly requested*
  profile that does not exist surfaces a descriptive error rather than
  silently falling through (a merely defaulted profile falls through).
- **Redaction**: `fmt.Sprintf("%v")` and `%+v` of a `Credentials` value
  never contain the secret.

Full test examples are in `references/credential-chain.md`.

## Checklist

- [ ] All auth attributes `Optional`; secrets marked `Sensitive: true`
- [ ] Attribute descriptions name their environment-variable fallbacks
- [ ] Unknown-value guards on every auth attribute in `Configure`
- [ ] Chain precedence: static config > env vars > credentials file > platform identity
- [ ] Secrets resolved as a complete set; non-secret settings field-by-field
- [ ] Sentinel `ErrNoCredentials` distinguishes fall-through from hard failure
- [ ] Missing-credentials diagnostic lists every source tried + docs URL
- [ ] `Credentials` type redacts secrets in `String()`/`GoString()`
- [ ] Credentials-file permission warning (non-Windows)
- [ ] Eager resolution in `Configure`; optional identity check with `skip_credentials_validation`
- [ ] Unit tests cover per-source behavior, precedence, aggregation, redaction
- [ ] No credential value ever logged or embedded in an error

## Related Skills

Use the `new-terraform-provider` skill (if available) to scaffold the
provider this configuration lives in, and the `provider-resources` skill for
consuming the configured client from resources and data sources.
