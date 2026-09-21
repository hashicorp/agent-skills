# Copyright IBM Corp. 2025, 2026
# SPDX-License-Identifier: MPL-2.0

# Converted from HashiCorp PCI DSS Sentinel example: efs-access-point-should-enforce-user-identity.sentinel
# Conversion quality: Perfect

resource_policy "aws_efs_access_point" "efs_access_point_should_enforce_user_identity" {
    enforce {
        condition = core::try(attrs.posix_user, null) != null
        error_message = "EFS access points must define posix_user"
    }
}
