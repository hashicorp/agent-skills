# Approximation of HashiCorp PCI DSS Sentinel example: secretsmanager-auto-rotation-enabled-check.sentinel
# Exact conversion quality: Limited

locals {
    all_secret_rotations = core::getresources("aws_secretsmanager_secret_rotation", {})
    rotation_secret_ids = {
        for rotation in local.all_secret_rotations :
        core::try(rotation.secret_id, "") => true
    }
}

resource_policy "aws_secretsmanager_secret" "secretsmanager_auto_rotation_enabled_check" {
    locals {
        secret_id = core::try(attrs.id, "")
        has_rotation = core::try(local.rotation_secret_ids[local.secret_id], false)
    }

    enforce {
        condition = local.has_rotation
        error_message = "Secrets Manager secrets should have a matching aws_secretsmanager_secret_rotation resource"
    }
}
