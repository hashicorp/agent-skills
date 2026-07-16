# Converted from HashiCorp PCI DSS Sentinel example: step-functions-state-machine-logging-enabled.sentinel
# Conversion quality: Good

resource_policy "aws_sfn_state_machine" "step_functions_state_machine_logging_enabled" {
    locals {
        logging_configuration = core::try(attrs.logging_configuration, [])
        log_level = core::try(local.logging_configuration[0].level, "")
        allowed_levels = ["ALL", "ERROR", "FATAL"]
    }

    enforce {
        condition = core::contains(local.allowed_levels, local.log_level)
        error_message = "Step Functions state machines must set logging_configuration.level to ALL, ERROR, or FATAL"
    }
}
