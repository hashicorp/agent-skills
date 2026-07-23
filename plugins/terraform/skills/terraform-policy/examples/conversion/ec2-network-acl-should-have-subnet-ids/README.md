# EC2 Network ACL Should Have Subnet IDs

## Source Sentinel Policy
`ec2-network-acl-should-have-subnet-ids.sentinel`

## Conversion Quality
`Limited`

## Why this is limited
The Sentinel policy uses `tfconfig/v2`, reference metadata, and module-aware address reconstruction to determine whether a network ACL is connected through `aws_network_acl_association`. Current tfpolicy guidance does not expose equivalent reference metadata, so an exact translation is not possible.

## What the approximation does
The tfpolicy version checks either:
- `subnet_ids` is present directly on the network ACL, or
- a matching `aws_network_acl_association` can be found via `core::getresources()` and a value-based lookup

## Limitations encountered
- This is value matching, not true Terraform graph reasoning
- It may behave differently for newly created resources with unresolved values
- It does not reproduce the Sentinel policy's module-aware reference reconstruction exactly
