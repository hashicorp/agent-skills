# Elasticsearch In VPC Only

## Source Sentinel Policy
`elasticsearch-in-vpc-only.sentinel`

## Conversion Quality
`Limited`

## Why this is limited
The Sentinel policy is config-oriented and accepts either constant subnet IDs or references inside `vpc_options.subnet_ids`. tfpolicy does not expose the same config-level `constant_value` and `references` metadata, so it cannot preserve that distinction exactly.

## What the tfpolicy approximation does
The tfpolicy version checks the planned end state and requires `vpc_options[0].subnet_ids` to contain one or more values.

## Limitations encountered
- It validates the resulting planned subnet IDs, not whether they originated from constants vs references
- It assumes the provider exposes `vpc_options` and `subnet_ids` in the expected schema shape
- It is a useful enforcement approximation, but not a one-to-one tfconfig translation
