# Elasticsearch HTTPS Required

## Source Sentinel Policy
`elasticsearch-https-required.sentinel`

## Conversion Quality
`Good`

## Why it is not labeled Perfect
The enforcement intent is preserved, but the structure changes more noticeably than in a simple attribute check. The Sentinel version uses helper functions plus nested map lookups. The tfpolicy version rewrites that logic into direct block access with `core::try()` and separate `enforce` blocks.

## Key translation notes
- Nested `maps.get()` calls become `core::try(local.endpoint_options[0]....)`
- One compound Sentinel predicate becomes multiple focused `enforce` blocks
- The end-state requirement is preserved clearly in tfpolicy

## Limitations encountered
This conversion depends on provider schema shape for `domain_endpoint_options`. As with other tfpolicy policies, block/list/set handling must match the exposed schema exactly.
