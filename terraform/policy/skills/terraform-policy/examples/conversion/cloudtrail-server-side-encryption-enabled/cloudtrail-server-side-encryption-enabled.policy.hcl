# Converted from HashiCorp PCI DSS Sentinel example: cloudtrail-server-side-encryption-enabled.sentinel
# Conversion quality: Good

resource_policy "aws_cloudtrail" "cloudtrail_server_side_encryption_enabled" {
    locals {
        kms_key_id = core::try(attrs.kms_key_id, "")
    }

    enforce {
        condition = local.kms_key_id != ""
        error_message = "CloudTrail resources must set kms_key_id for server-side encryption"
    }
}
