# Credential Chain Case Studies

Two production designs at opposite ends of the complexity scale. Read these
to calibrate how much chain your provider actually needs — then implement
with the generic pattern in `credential-chain.md`.

## Case study 1: The AWS provider (`aws-sdk-go-base`)

The Terraform AWS provider, the AWSCC provider, and the S3 backend all
resolve credentials through one shared library,
[`hashicorp/aws-sdk-go-base`](https://github.com/hashicorp/aws-sdk-go-base)
(MPL-2.0). Its entry point `GetAwsConfig(ctx, *Config)` is the most
battle-tested credential chain in the Terraform ecosystem.

### Resolution order

1. **Static credentials short-circuit.** If the provider config carries any
   of access key / secret key / token, it builds a static credentials
   provider immediately and skips the rest of the chain. Explicit config
   always wins, and partial static credentials fail loudly rather than
   falling through — a deliberate choice for secrets.
2. **The SDK default chain**, with the profile pinned first when the
   provider config sets one. The AWS SDK then resolves, in order:
   environment variables → shared credentials/config files (including SSO,
   web-identity, and source-profile assume-role directives declared *inside*
   those files) → container credentials → EC2 instance metadata (IMDS).
3. **Explicit web identity override.** An `assume_role_with_web_identity`
   block replaces whatever the default chain produced with an STS
   web-identity provider (validated: role ARN required, exactly one token
   source).
4. **Assume-role wrapping.** `assume_role` is a *list*; each entry wraps the
   previously resolved credentials in an STS assume-role provider, enabling
   role *chaining* (credentials → role A → role B). Each hop carries its own
   session name, external ID, policy, tags, and duration, wrapped in a
   credentials cache.

### Techniques worth copying regardless of scale

- **Eager verification.** The resolved provider's `Retrieve()` is called
  during configuration, and — unless `skip_credentials_validation` is set —
  an `sts:GetCallerIdentity` call proves the credentials actually work.
  Failures surface at plan time with configuration-shaped errors instead of
  mid-apply with API-shaped ones.
- **`NoValidCredentialSourcesError`.** The missing-credentials diagnostic
  embeds a caller-supplied documentation URL (`CallerDocumentationURL`) and
  the underlying error. Every downstream product (provider, backend) points
  users at *its own* auth docs through the same error type.
- **Conflict warnings.** If both a `profile` and static env-var credentials
  are present, it emits a "configuration conflict" warning explaining which
  source took precedence — and if resolution then fails, the error is
  annotated with that context.
- **Endpoint injection for the chain itself.** Custom STS/SSO/IAM endpoints
  are threaded into the chain's own calls, so air-gapped and
  government-partition deployments can authenticate at all. If your platform
  has regional or private auth endpoints, the chain must honor them too.
- **Legacy env-var migration.** Deprecated variables (e.g.
  `AWS_METADATA_URL`) are still read, with a warning naming the replacement.
  Renaming an env var without a migration warning breaks users silently.

### What this scale of chain costs

`Config` carries dozens of fields (proxies, CA bundles, retry modes, IMDS
toggles, account-ID allow/deny lists), and the behavioral spec lives in a
very large test suite exercising every precedence branch. Do not start
here — grow toward it.

## Case study 2: A hand-rolled chain in a small provider

A recently built provider for an appliance-style API (IBM Power HMC) needed
exactly three sources — provider block, environment variables, and a YAML
credentials file with named profiles — and implemented the chain by hand in
a self-contained `internal/credentials` package, the same shape as
`credential-chain.md`. Its design choices, generalized:

- **A one-method `Provider` interface + sentinel error.** `Retrieve(ctx)`
  returns the credentials or `ErrNoCredentials` to mean "fall through". An
  aggregate `ChainError` records every source tried and implements
  `Is(ErrNoCredentials)` so the provider's `Configure` can pick between
  "here is how to supply credentials" and "your file is broken" with a
  single `errors.Is`.
- **Secrets as a set; connection settings field-by-field.** Username and
  password resolve together through the chain, while `host` and `insecure`
  each independently follow config > env > file profile > default. A profile
  can therefore hold only connection settings while credentials come from
  the environment.
- **Redaction at the type level.** The credentials struct's
  `String()`/`GoString()` print `***REDACTED***` for the secret, making the
  value log-safe by construction.
- **File semantics tuned for humans.** A missing file or profile that was
  merely *defaulted* falls through silently; a missing file at an
  *explicitly configured* path, an *explicitly requested* profile that does
  not exist, or a malformed file are hard errors — each one is a user
  mistake worth reporting precisely.
- **Warnings for the almost-right.** Group/world-readable credentials files
  produce a `chmod 0600` warning; disabling TLS verification produces a
  warning naming the risk.
- **Hermetic unit tests.** An injectable `getenv` function and temp-dir
  credential files make precedence tests (`StaticWins`, `EnvBeatsFile`,
  `FallsThroughToFile`), aggregate-error tests, and redaction tests run
  without touching the real environment.

## Choosing your chain

| Your situation | Chain to build |
|---|---|
| Single API token, no files | Static + env. Two providers, still worth the chain for its error aggregation |
| Human operators, multiple accounts | Add a credentials file with profiles (case study 2) |
| Runs inside the platform it manages | Add a platform-identity source (metadata/OIDC) at the end |
| Delegation/role semantics in the API | Add assume-role *wrapping* on top of the chain (case study 1) |

Whatever the size: keep the order in one constructor, aggregate every
skipped source into the failure message, and validate eagerly in
`Configure`.
