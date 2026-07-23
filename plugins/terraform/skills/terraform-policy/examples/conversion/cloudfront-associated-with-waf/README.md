# CloudFront Associated with WAF

## Source Sentinel Policy
`cloudfront-associated-with-waf.sentinel`

## Conversion Quality
`Not convertible` as an exact translation

## What the approximation does
The included tfpolicy approximation checks only that `web_acl_id` is set to a non-empty value on `aws_cloudfront_distribution` resources.

## Why exact conversion is not possible today
The Sentinel policy uses `tfconfig/v2` plus reference metadata (`references`) to reason about whether the CloudFront distribution is associated with a WAF resource. Current tfpolicy guidance does not expose equivalent reference metadata, so it cannot distinguish:
- literal values
- references to WAF resources
- computed values

## Key limitation
This means tfpolicy can enforce presence of a `web_acl_id`, but it cannot safely reproduce the Sentinel policy's reference-aware behavior.
