# CloudTrail Server-Side Encryption Enabled

## Source Sentinel Policy
`cloudtrail-server-side-encryption-enabled.sentinel`

## Conversion Quality
`Good`

## Why this is Good
The Sentinel policy is config-oriented and checks whether `kms_key_id` is present as a configured value. tfpolicy can preserve the same enforcement intent by validating the planned end-state value for `attrs.kms_key_id`.

## Key translation notes
- `tfconfig/v2` config inspection becomes a planned-value check in tfpolicy
- The converted policy focuses on whether `kms_key_id` is ultimately present, not whether it originated as a constant in the config

## Limitations encountered
The tfpolicy version does not preserve the config-level distinction between explicit constant values and other configuration forms. It validates the final planned attribute value instead.
