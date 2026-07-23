# Converted from HashiCorp PCI DSS Sentinel example: elasticsearch-encrypted-at-rest.sentinel
# Conversion quality: Good

resource_policy "aws_elasticsearch_domain" "elasticsearch_encrypted_at_rest" {
    locals {
        encrypt_at_rest = core::try(attrs.encrypt_at_rest, [])
        encryption_enabled = core::try(local.encrypt_at_rest[0].enabled, false)
    }

    enforce {
        condition = local.encryption_enabled == true
        error_message = "Elasticsearch domains must enable encrypt_at_rest"
    }
}
