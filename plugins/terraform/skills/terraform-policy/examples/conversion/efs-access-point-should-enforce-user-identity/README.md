# EFS Access Point Should Enforce User Identity

## Source Sentinel Policy
`efs-access-point-should-enforce-user-identity.sentinel`

## Conversion Quality
`Perfect`

## Why it converts well
This is a simple presence check on a single planned resource type. The Sentinel policy rejects `aws_efs_access_point` resources that do not define `posix_user`, and tfpolicy can express that directly with one `resource_policy` and one `enforce` block.

## Key translation notes
- `maps.get(res.values, "posix_user", {}) is not empty` becomes `core::try(attrs.posix_user, null) != null`
- No cross-resource reasoning or reference metadata is required

## Limitations encountered
No significant tfpolicy limitation blocks this conversion.
