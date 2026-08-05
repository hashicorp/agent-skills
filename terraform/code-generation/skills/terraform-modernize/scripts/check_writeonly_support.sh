#!/bin/bash
# Check which resources/attributes support write-only arguments
# Usage: ./check_writeonly_support.sh <provider_name> [resource_type]
# Requires: terraform, jq
# Note: Run from an initialized Terraform directory (terraform init)
#
# This script checks ONLY providers declared in the current configuration.
# It looks for resource attributes ending in _wo (write-only suffix).

set -e

PROVIDER=$1
RESOURCE=$2

if [ -z "$PROVIDER" ]; then
    echo "Usage: $0 <provider_name> [resource_type]" >&2
    echo "Example: $0 aws" >&2
    echo "Example: $0 aws aws_db_instance" >&2
    exit 1
fi

# Ensure terraform is initialized
if [ ! -d ".terraform" ]; then
    echo "Initializing Terraform..." >&2
    terraform init -upgrade > /dev/null 2>&1
fi

# Cache provider schema output for reuse within script
SCHEMA=$(terraform providers schema -json 2>/dev/null)
provider_key=$(jq -r '.provider_schemas | keys[]' <<< "$SCHEMA" | grep "/$1$" || true)

if [ -z "$provider_key" ]; then
    echo "{}" >&2
    echo "Error: Provider '${PROVIDER}' not found in current configuration." >&2
    echo "Add provider to terraform {} block and run terraform init first." >&2
    exit 1
fi

# Extract write-only capable attributes from provider schema
if [ -n "$RESOURCE" ]; then
    # Specific resource
    jq -r --arg provider "$provider_key" --arg resource "$RESOURCE" '
        .provider_schemas[$provider].resource_schemas[$resource] // {} |
        {
            resource: $resource,
            write_only_arguments: [
                (.block.attributes // {})
                | to_entries[]
                | select(.key | endswith("_wo"))
                | .key
            ]
        }
    ' <<< "$SCHEMA"
else
    # All resources for provider - show which have write-only arguments
    jq -r --arg provider "$provider_key" '
        .provider_schemas[$provider].resource_schemas // {} |
        to_entries |
        map({
            resource: .key,
            write_only_arguments: [
                (.value.block.attributes // {})
                | to_entries[]
                | select(.key | endswith("_wo"))
                | .key
            ]
        }) |
        map(select(.write_only_arguments | length > 0))
    ' <<< "$SCHEMA"
fi
