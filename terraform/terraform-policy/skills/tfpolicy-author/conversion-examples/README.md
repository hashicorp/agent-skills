# Sentinel to tfpolicy Conversion Examples

This folder packages representative Sentinel-to-tfpolicy conversion examples for sharing with teammates.

Each example subfolder contains:
- `<sentinel-policy-name>.sentinel` - the actual Sentinel policy file included for comparison
- `<sentinel-policy-name>.policy.hcl` - the tfpolicy version or best approximation
- `README.md` - explanation of the conversion quality, what changed, and any limitations

Converted tfpolicy examples in this bundle prefer remediation-focused diagnostics over repeating Terraform addresses from Sentinel `summary {}` output. Terraform Policy diagnostics already identify the failing object and point to the relevant location, so converted examples avoid `${meta.address}` in error messages.

Included examples:
- `dms-endpoints-should-use-ssl` - direct attribute conversion (`Perfect`)
- `elasticsearch-https-required` - nested block conversion (`Good`)
- `eventbridge-custom-event-bus-should-have-attached-policy` - cross-resource conversion via `core::getresources()` (`Limited`)
- `cloudfront-associated-with-waf` - approximation only due to missing reference metadata (`Not convertible` as an exact translation)
- `efs-access-point-should-enforce-user-identity` - direct presence check (`Perfect`)
- `elasticsearch-encrypted-at-rest` - nested encryption block check (`Good`)
- `dms-endpoint-should-be-ssl-configured` - config-derived certificate check (`Good`)
- `ec2-network-acl-should-have-subnet-ids` - association-aware approximation (`Limited`)
- `secretsmanager-auto-rotation-enabled-check` - secret-to-rotation relationship via `core::getresources()` (`Good`)
- `s3-bucket-should-have-object-lock-enabled` - object lock association approximation (`Limited`)
- `ec2-vpc-default-security-group-no-traffic` - inline-only approximation of a broader graph check (`Not convertible` as an exact translation)
- `elasticsearch-in-vpc-only` - config-to-end-state VPC placement approximation (`Limited`)
- `cloudtrail-server-side-encryption-enabled` - config-to-end-state encryption check (`Good`)
- `step-functions-state-machine-logging-enabled` - nested logging block conversion (`Good`)
- `elasticache-redis-replication-group-encryption-at-transit-enabled` - direct boolean check (`Perfect`)
- `s3-block-public-access-bucket-level` - variable and association heavy approximation (`Not convertible` as an exact translation)

Note: The Sentinel policy files in this bundle come from the locally cloned policy library so reviewers can inspect the original Sentinel and converted tfpolicy side by side in one place.
