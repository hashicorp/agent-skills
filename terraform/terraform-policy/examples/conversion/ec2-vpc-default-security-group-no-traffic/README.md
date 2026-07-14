# EC2 VPC Default Security Group No Traffic

## Source Sentinel Policy
`ec2-vpc-default-security-group-no-traffic.sentinel`

## Conversion Quality
`Not convertible` as an exact translation

## What the approximation does
The included tfpolicy checks only inline `ingress` and `egress` rules on `aws_default_security_group` resources.

## Why exact conversion is not possible today
The Sentinel policy combines several config-level resource types:
- `aws_default_security_group`
- `aws_security_group_rule`
- `aws_vpc_security_group_ingress_rule`
- `aws_vpc_security_group_egress_rule`

It then uses `tfconfig/v2` reference metadata and regex checks to determine whether those separate rule resources target the default security group of a VPC. Current tfpolicy guidance does not expose equivalent config graph metadata, so it cannot safely reproduce that full relationship-aware behavior.

## Key limitation
This means tfpolicy can approximate the inline-rule case, but it cannot fully enforce the broader Sentinel policy that also reasons over separate security group rule resources attached by reference.
