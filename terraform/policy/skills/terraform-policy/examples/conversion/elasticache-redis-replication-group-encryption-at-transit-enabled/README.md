# ElastiCache Redis Replication Group Encryption at Transit Enabled

## Source Sentinel Policy
`elasticache-redis-replication-group-encryption-at-transit-enabled.sentinel`

## Conversion Quality
`Perfect`

## Why it converts well
This is a direct boolean check on a single planned resource type. The Sentinel logic checks whether `transit_encryption_enabled` is true on `aws_elasticache_replication_group`, and tfpolicy can express the same rule directly.

## Key translation notes
- `maps.get(res, "values.transit_encryption_enabled", ...)` becomes `core::try(attrs.transit_encryption_enabled, false)`
- No resource graph traversal, config metadata, or cross-resource matching is required

## Limitations encountered
No significant tfpolicy limitation blocks this conversion.
