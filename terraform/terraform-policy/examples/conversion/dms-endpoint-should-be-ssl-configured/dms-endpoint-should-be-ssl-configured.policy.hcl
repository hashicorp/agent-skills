# Converted from HashiCorp PCI DSS Sentinel example: dms-endpoint-should-be-ssl-configured.sentinel
# Conversion quality: Good

resource_policy "aws_dms_endpoint" "dms_endpoint_should_be_ssl_configured" {
    locals {
        certificate_arn = core::try(attrs.certificate_arn, "")
    }

    enforce {
        condition = local.certificate_arn != ""
        error_message = "DMS endpoints should set certificate_arn for SSL configuration"
    }
}
