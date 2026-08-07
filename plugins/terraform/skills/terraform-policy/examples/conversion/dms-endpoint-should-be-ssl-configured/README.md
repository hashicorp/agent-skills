# DMS Endpoint Should Be SSL Configured

## Source Sentinel Policy
`dms-endpoint-should-be-ssl-configured.sentinel`

## Conversion Quality
`Good`

## Why this converts reasonably well
The Sentinel version uses `tfconfig/v2` to accept either a constant value or a reference for `certificate_arn`. tfpolicy cannot inspect Terraform config reference metadata the same way, but it can still validate that the planned `certificate_arn` value is non-empty.

## Key translation notes
- Config-oriented Sentinel checks become an end-state tfpolicy check on `attrs.certificate_arn`
- tfpolicy focuses on the resulting planned value instead of whether it came from a literal or a reference

## Limitations encountered
The tfpolicy version does not preserve the source-level distinction between constant values and references. It only checks that the final planned value is present.
