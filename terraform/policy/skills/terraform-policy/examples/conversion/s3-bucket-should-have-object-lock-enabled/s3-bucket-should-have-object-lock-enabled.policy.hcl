# Approximation of HashiCorp PCI DSS Sentinel example: s3-bucket-should-have-object-lock-enabled.sentinel
# Exact conversion quality: Limited

locals {
    all_object_lock_configs = core::getresources("aws_s3_bucket_object_lock_configuration", {})
    object_lock_bucket_map = {
        for config in local.all_object_lock_configs :
        core::try(config.bucket, "") => core::try(config.rule[0].default_retention[0].mode, "")
    }
}

resource_policy "aws_s3_bucket" "s3_bucket_should_have_object_lock_enabled" {
    locals {
        bucket_name = core::try(attrs.bucket, "")
        retention_mode = core::try(local.object_lock_bucket_map[local.bucket_name], "")
        object_lock_enabled = core::contains(["GOVERNANCE", "COMPLIANCE"], local.retention_mode)
    }

    enforce {
        condition = local.object_lock_enabled
        error_message = "S3 buckets should have object lock enabled with default retention mode GOVERNANCE or COMPLIANCE"
    }
}
