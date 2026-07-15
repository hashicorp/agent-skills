# S3 Bucket Should Have Object Lock Enabled

## Source Sentinel Policy
`s3-bucket-should-have-object-lock-enabled.sentinel`

## Conversion Quality
`Limited`

## Why this is limited
The Sentinel policy uses `tfconfig/v2` plus reference metadata to trace `aws_s3_bucket_object_lock_configuration` resources back to their `aws_s3_bucket` resources, including module-aware address reconstruction. tfpolicy does not expose equivalent config graph metadata.

## What the tfpolicy approximation does
The tfpolicy version uses `core::getresources()` to find `aws_s3_bucket_object_lock_configuration` resources, then matches them to buckets by the resolved `bucket` value and checks the retention mode.

## Limitations encountered
- Matching depends on resolved values, not reference metadata
- Initial creation with unresolved bucket references may not match reliably
- The approximation checks the end-state relationship but cannot reproduce the Sentinel config-graph logic exactly
