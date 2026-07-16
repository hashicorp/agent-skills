#!/bin/bash
# Extract ephemeral resources supported by Terraform providers
# Usage: ./check_ephemeral_support.sh [provider_name]
# Requires: terraform, jq
# Note: Run from an initialized Terraform directory (terraform init)
#
# This script checks ONLY providers declared in the current configuration.
# It queries the provider schema after terraform init has downloaded the providers.

set -e

PROVIDER=$1

# Ensure terraform is initialized
if [ ! -d ".terraform" ]; then
    echo "Initializing Terraform..." >&2
    terraform init -upgrade > /dev/null 2>&1
fi

# Cache provider schema output for reuse within script
SCHEMA=$(terraform providers schema -json 2>/dev/null)

# Get provider schema and extract ephemeral_resource_schemas
if [ -n "$PROVIDER" ]; then
    # Specific provider (must be declared in current config)
    provider_key=$(jq -r '.provider_schemas | keys[]' <<< "$SCHEMA" | grep "/$1$" || true)
    if [ -n "$provider_key" ]; then
        jq -r "{\"$PROVIDER\": (.provider_schemas.\"${provider_key}\" | .ephemeral_resource_schemas // {} | keys | sort)}" <<< "$SCHEMA"
    else
        echo "{\"$PROVIDER\": []}" >&2
        echo "Note: Provider '${PROVIDER}' not found in current configuration." >&2
        echo "Add provider to terraform {} block and run terraform init first." >&2
        exit 1
    fi
else
    # All providers declared in current config
    jq -r '
        .provider_schemas
        | to_entries
        | map({key: (.key | split("/")[-1]), value: (.value.ephemeral_resource_schemas // {} | keys | sort)})
        | from_entries
    ' <<< "$SCHEMA"
fi
