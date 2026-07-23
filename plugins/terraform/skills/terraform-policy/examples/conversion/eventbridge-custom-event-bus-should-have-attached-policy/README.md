# EventBridge Bus Must Have Attached Policy

## Source Sentinel Policy
`eventbridge-custom-event-bus-should-have-attached-policy.sentinel`

## Conversion Quality
`Limited`

## Why this is only a partial conversion
The Sentinel version can compare planned event bus resources against planned policy resources cleanly inside its own collection-processing model. tfpolicy can approximate that by using `core::getresources()` and matching on `event_bus_name`, but this is not a full graph-aware translation.

## Key translation notes
- Related resources are discovered with `core::getresources("aws_cloudwatch_event_bus_policy", {})`
- Matching is done by explicit value (`event_bus_name`) rather than graph/reference semantics
- A top-level lookup map keeps the tfpolicy example readable and performant

## Limitations encountered
- This approach relies on resolved attribute values, not reference metadata
- New resources with unresolved references may not match reliably on initial creation
- `core::getresources()` is useful for scoped lookups but is not a full replacement for Sentinel graph traversal
