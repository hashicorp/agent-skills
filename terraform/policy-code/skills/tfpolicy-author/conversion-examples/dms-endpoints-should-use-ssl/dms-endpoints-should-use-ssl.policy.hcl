# Converted from HashiCorp PCI DSS Sentinel example: dms-endpoints-should-use-ssl.sentinel
# Conversion quality: Perfect

resource_policy "aws_dms_endpoint" "require_ssl_mode" {
    locals {
        ssl_mode = core::try(attrs.ssl_mode, "")
        valid_ssl_modes = ["require", "verify-ca", "verify-full"]
    }

    enforce {
        condition = core::contains(local.valid_ssl_modes, local.ssl_mode)
        error_message = "DMS endpoints must set ssl_mode to one of: require, verify-ca, verify-full"
    }
}
