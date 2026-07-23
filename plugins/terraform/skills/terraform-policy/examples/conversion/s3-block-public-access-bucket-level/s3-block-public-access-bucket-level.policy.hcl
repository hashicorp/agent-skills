# Approximation of HashiCorp PCI DSS Sentinel example: s3-block-public-access-bucket-level.sentinel
# Exact conversion quality: Not convertible

locals {
    all_public_access_blocks = core::getresources("aws_s3_bucket_public_access_block", {})
    compliant_public_access_blocks = {
        for block in local.all_public_access_blocks :
        core::try(block.bucket, "") => (
            core::try(block.ignore_public_acls, false) == true &&
            core::try(block.restrict_public_buckets, false) == true &&
            core::try(block.block_public_acls, false) == true &&
            core::try(block.block_public_policy, false) == true
        )
    }
}

resource_policy "aws_s3_bucket" "s3_block_public_access_bucket_level" {
    locals {
        bucket_name = core::try(attrs.bucket, "")
        block_is_compliant = core::try(local.compliant_public_access_blocks[local.bucket_name], false)
    }

    enforce {
        condition = local.block_is_compliant
        error_message = "S3 buckets should have a matching aws_s3_bucket_public_access_block with all four public access settings enabled"
    }
}
