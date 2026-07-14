# DMS Endpoint SSL Mode

## Source Sentinel Policy
`dms-endpoints-should-use-ssl.sentinel`

## Conversion Quality
`Perfect`

## Why it converts well
This policy is a straightforward single-resource attribute check. The Sentinel version iterates over `aws_dms_endpoint` resources and rejects any resource whose `ssl_mode` is not in an allowlist. tfpolicy can express the same intent directly with one `resource_policy`, one allowlist, and one `enforce` block.

## Key translation notes
- Sentinel `collection.reject()` becomes one positive `condition`
- `maps.get(res, "values.ssl_mode", null)` becomes `core::try(attrs.ssl_mode, "")`
- No cross-resource logic, state inspection, or reference metadata is involved

## Limitations encountered
No significant tfpolicy limitation blocks this conversion.
