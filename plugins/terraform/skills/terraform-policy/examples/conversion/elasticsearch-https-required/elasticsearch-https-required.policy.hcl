# Converted from HashiCorp PCI DSS Sentinel example: elasticsearch-https-required.sentinel
# Conversion quality: Good

resource_policy "aws_elasticsearch_domain" "https_required" {
    locals {
        endpoint_options = core::try(attrs.domain_endpoint_options, [])
        endpoint_options_present = core::length(local.endpoint_options) > 0
        enforce_https = core::try(local.endpoint_options[0].enforce_https, false)
        tls_security_policy = core::try(local.endpoint_options[0].tls_security_policy, "")
    }

    enforce {
        condition = local.endpoint_options_present
        error_message = "Elasticsearch domains must define domain_endpoint_options"
    }

    enforce {
        condition = local.enforce_https == true
        error_message = "Elasticsearch domains must set domain_endpoint_options.enforce_https = true"
    }

    enforce {
        condition = local.tls_security_policy == "Policy-Min-TLS-1-2-PFS-2023-10"
        error_message = "Elasticsearch domains must use tls_security_policy 'Policy-Min-TLS-1-2-PFS-2023-10'"
    }
}
