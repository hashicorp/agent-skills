# Approximation of HashiCorp PCI DSS Sentinel example: cloudfront-associated-with-waf.sentinel
# Exact conversion quality: Not convertible
# This tfpolicy only checks for a non-empty web_acl_id value.

resource_policy "aws_cloudfront_distribution" "require_web_acl_id" {
    locals {
        web_acl_id = core::try(attrs.web_acl_id, "")
    }

    enforce {
        condition = local.web_acl_id != ""
        error_message = "CloudFront distributions should set web_acl_id to associate a WAF or WAF Classic ACL"
    }
}
