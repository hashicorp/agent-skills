# Secrets Manager Auto Rotation Enabled Check

## Source Sentinel Policy
`secretsmanager-auto-rotation-enabled-check.sentinel`

## Conversion Quality
`Limited`

## Why this is limited
The Sentinel policy uses `tfconfig/v2` reference metadata to determine whether each `aws_secretsmanager_secret` is connected to an `aws_secretsmanager_secret_rotation` resource through `config.secret_id`. Current tfpolicy guidance does not expose equivalent config-level reference metadata.

## What the tfpolicy approximation does
The tfpolicy version uses `core::getresources()` to collect `aws_secretsmanager_secret_rotation` resources and matches them to secrets by planned `secret_id` / `id` values.

## Limitations encountered
- This is value matching, not true Terraform graph reasoning
- It may fail or behave differently when secret identifiers are not resolved yet during creation
- It does not preserve Sentinel's module-aware reference reconstruction exactly
