# Retries, Waiters, and Eventual Consistency

Most real APIs are eventually consistent: a successful Create response does
not mean the object is ready, visible, or even findable yet. Providers that
ignore this produce flaky applies that "work on retry" — the worst kind of
bug report. This reference gives the standard patterns; the primitives
(`retry.StateChangeConf`, `retry.NotFoundError`) come from
`github.com/hashicorp/terraform-plugin-sdk/v2/helper/retry` and are usable
from Plugin Framework providers.

## Three failure classes

1. **Not yet visible** — Create returned, but an immediate Get 404s because
   replicas haven't converged. Fix: retry *not-found* errors briefly right
   after create.
2. **Temporarily refused** — the API rejects an operation because a
   dependency hasn't propagated (auth policy, newly created parent). Fix:
   retry on the *specific* error for a bounded window.
3. **Asynchronous completion** — the API accepts the request and works in
   the background (status field: `CREATING` → `ACTIVE`). Fix: a waiter that
   polls status until it reaches a target.

Diagnose which class you have before coding; the fixes look similar but
retry different conditions.

## Waiters: status + wait function pairs

Split waiting into a *status* function (one poll, built on the package's
finder) and a *wait* function (the state machine). Keeping them separate
makes each waiter one obvious declaration and lets tests call the status
function directly.

```go
const (
    widgetCreatedTimeout = 5 * time.Minute
    widgetDeletedTimeout = 10 * time.Minute
)

func statusWidget(ctx context.Context, client *examplecloud.Client, id string) retry.StateRefreshFunc {
    return func() (any, string, error) {
        output, err := findWidgetByID(ctx, client, id)
        if isNotFound(err) {
            return nil, "", nil // nil result, empty status = "gone"
        }
        if err != nil {
            return nil, "", err
        }
        return output, string(output.Status), nil
    }
}

func waitWidgetCreated(ctx context.Context, client *examplecloud.Client, id string) (*examplecloud.Widget, error) {
    stateConf := &retry.StateChangeConf{
        Pending: []string{"CREATING", "PENDING"},
        Target:  []string{"ACTIVE"},
        Refresh: statusWidget(ctx, client, id),
        Timeout: widgetCreatedTimeout,
    }
    outputRaw, err := stateConf.WaitForStateContext(ctx)
    if output, ok := outputRaw.(*examplecloud.Widget); ok {
        return output, err
    }
    return nil, err
}

func waitWidgetDeleted(ctx context.Context, client *examplecloud.Client, id string) error {
    stateConf := &retry.StateChangeConf{
        Pending: []string{"ACTIVE", "DELETING"},
        Target:  []string{}, // empty target: wait until the status func reports gone
        Refresh: statusWidget(ctx, client, id),
        Timeout: widgetDeletedTimeout,
    }
    _, err := stateConf.WaitForStateContext(ctx)
    return err
}
```

Rules of thumb:

- **Enumerate `Pending` states** you expect to pass through; an unexpected
  state fails fast with a clear error instead of hanging to timeout. Include
  failure states (`FAILED`, `ERROR`) in neither list so they error
  immediately — or check for them in the status function and return a
  descriptive error carrying the API's failure reason.
- **Timeouts in named constants**, generous but bounded. If users of the
  resource legitimately need control, add schema-level timeouts.
- Call `waitWidgetCreated` at the end of `Create` (and `waitWidgetDeleted`
  in `Delete`) so downstream resources can rely on readiness.

## Post-create not-found retries

For class 1 (visible-lag) failures, wrap the first read after create in a
short not-found retry rather than a full waiter:

```go
const propagationTimeout = 2 * time.Minute

func findWidgetByIDRetryOnCreate(ctx context.Context, client *examplecloud.Client, id string) (*examplecloud.Widget, error) {
    var output *examplecloud.Widget
    err := retry.RetryContext(ctx, propagationTimeout, func() *retry.RetryError {
        var err error
        output, err = findWidgetByID(ctx, client, id)
        if isNotFound(err) {
            return retry.RetryableError(err) // just created: keep looking
        }
        if err != nil {
            return retry.NonRetryableError(err)
        }
        return nil
    })
    return output, err
}
```

Only use this immediately after create. In a normal `Read`, a not-found must
*not* be retried — it is the signal to remove the resource from state.

## Operation-specific error retries

For class 2, retry only the specific, recognizable error, for a bounded
window:

```go
err := retry.RetryContext(ctx, propagationTimeout, func() *retry.RetryError {
    _, err := client.AttachPolicy(ctx, input)
    var conflictErr *examplecloud.DependencyNotReadyError
    if errors.As(err, &conflictErr) {
        return retry.RetryableError(err)
    }
    if err != nil {
        return retry.NonRetryableError(err)
    }
    return nil
})
```

Never retry on error *message substrings* if the SDK offers typed errors,
and never retry broad classes ("any 400") — that converts real
misconfigurations into 2-minute hangs followed by a confusing timeout.

## Attribute-value waiters for updates

When an update is itself asynchronous (the API acknowledges but the field
reads back stale), wait for the attribute to reach its planned value using
the same StateChangeConf shape, with the attribute value as the "status".
Symptoms that you need this: tests fail on the post-apply refresh plan with
a diff on the just-updated attribute.

## Where this code lives

Small providers: same file as the resource. Larger packages: `status.go` and
`wait.go` per the file taxonomy in the main skill, so every resource's
waiters are discoverable in one place.
