# Approximation of HashiCorp PCI DSS Sentinel example: elasticsearch-in-vpc-only.sentinel
# Exact conversion quality: Limited

resource_policy "aws_elasticsearch_domain" "elasticsearch_in_vpc_only" {
    locals {
        vpc_options = core::try(attrs.vpc_options, [])
        subnet_ids = core::try(local.vpc_options[0].subnet_ids, [])
    }

    enforce {
        condition = core::length(local.subnet_ids) > 0
        error_message = "Elasticsearch domains should define one or more subnet_ids in vpc_options"
    }
}
