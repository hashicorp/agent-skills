# Step Functions State Machine Logging Enabled

## Source Sentinel Policy
`step-functions-state-machine-logging-enabled.sentinel`

## Conversion Quality
`Good`

## Why this is Good
This policy is still a single-resource planned-value check, but it relies on a nested block (`logging_configuration`) and an allowlist of valid levels. tfpolicy can express that clearly with `core::try()` and a small local allowlist.

## Key translation notes
- Nested map access becomes direct block access through `attrs.logging_configuration[0].level`
- The allowed log levels carry over directly into the tfpolicy version

## Limitations encountered
This relies on the provider exposing `logging_configuration` in the expected block/list shape. Otherwise, the enforcement intent maps cleanly.
