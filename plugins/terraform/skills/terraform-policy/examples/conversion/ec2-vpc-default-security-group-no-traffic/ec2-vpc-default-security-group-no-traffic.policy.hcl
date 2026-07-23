# Approximation of HashiCorp PCI DSS Sentinel example: ec2-vpc-default-security-group-no-traffic.sentinel
# Exact conversion quality: Not convertible
# This tfpolicy only checks inline ingress/egress on aws_default_security_group resources.

resource_policy "aws_default_security_group" "ec2_vpc_default_security_group_no_traffic" {
    locals {
        ingress_rules = core::try(attrs.ingress, [])
        egress_rules = core::try(attrs.egress, [])
    }

    enforce {
        condition = core::length(local.ingress_rules) == 0
        error_message = "Default security groups should not allow inline ingress traffic"
    }

    enforce {
        condition = core::length(local.egress_rules) == 0
        error_message = "Default security groups should not allow inline egress traffic"
    }
}
