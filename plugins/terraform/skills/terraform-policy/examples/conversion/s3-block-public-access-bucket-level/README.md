# S3 Block Public Access Bucket Level

## Source Sentinel Policy
`s3-block-public-access-bucket-level.sentinel`

## Conversion Quality
`Not convertible` as an exact translation

## What the approximation does
The tfpolicy approximation checks whether an `aws_s3_bucket` has a matching `aws_s3_bucket_public_access_block` resource and whether all four public access settings are enabled.

## Why exact conversion is not possible today
The Sentinel policy combines:
- `tfconfig/v2`
- `tfconfig-functions`
- plan-time variable resolution
- config reference metadata
- module-aware address reconstruction

Current tfpolicy guidance does not expose that full config-analysis surface. In particular, tfpolicy cannot safely reproduce the Sentinel behavior that inspects variable references and configuration graph relationships before values are fully materialized.

## Limitations encountered
- The approximation relies on resolved values via `core::getresources()`
- It cannot reproduce variable-reference evaluation from the Sentinel policy
- It may differ from Sentinel on first creation or heavily parameterized module usage
