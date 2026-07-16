# Approximation of HashiCorp PCI DSS Sentinel example: ec2-network-acl-should-have-subnet-ids.sentinel
# Exact conversion quality: Limited

locals {
    all_network_acl_associations = core::getresources("aws_network_acl_association", {})
    associated_network_acl_ids = {
        for association in local.all_network_acl_associations :
        core::try(association.network_acl_id, "") => true
    }
}

resource_policy "aws_network_acl" "network_acl_should_have_subnet_ids" {
    locals {
        subnet_ids = core::try(attrs.subnet_ids, [])
        has_subnet_ids = core::length(local.subnet_ids) > 0
        network_acl_id = core::try(attrs.id, "")
        has_association = core::try(local.associated_network_acl_ids[local.network_acl_id], false)
    }

    enforce {
        condition = local.has_subnet_ids || local.has_association
        error_message = "Network ACLs should define subnet_ids directly or have a matching aws_network_acl_association"
    }
}
