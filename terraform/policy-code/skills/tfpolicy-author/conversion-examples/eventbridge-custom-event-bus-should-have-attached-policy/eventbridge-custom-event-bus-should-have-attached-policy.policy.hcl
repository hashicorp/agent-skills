# Converted from HashiCorp PCI DSS Sentinel example: eventbridge-custom-event-bus-should-have-attached-policy.sentinel
# Conversion quality: Limited

locals {
    all_event_bus_policies = core::getresources("aws_cloudwatch_event_bus_policy", {})
    event_bus_policy_map = {
        for policy in local.all_event_bus_policies :
        policy.event_bus_name => true
    }
}

resource_policy "aws_cloudwatch_event_bus" "require_attached_policy" {
    locals {
        bus_name = core::try(attrs.name, "")
        has_attached_policy = core::try(local.event_bus_policy_map[local.bus_name], false)
    }

    enforce {
        condition = local.has_attached_policy
        error_message = "EventBridge buses must have a matching aws_cloudwatch_event_bus_policy resource"
    }
}
