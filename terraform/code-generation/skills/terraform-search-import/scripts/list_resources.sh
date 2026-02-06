#!/bin/bash
# Extract list resources supported by Terraform providers
# Usage: ./list_resources.sh [provider_name]
# Requires: terraform, jq
# Note: Run from an initialized Terraform directory (terraform init)

set -e

PROVIDER=$1

# Ensure terraform is initialized
if [ ! -d ".terraform" ]; then
    echo "Initializing Terraform..." >&2
    terraform init -upgrade > /dev/null 2>&1
fi

# Get provider schema and extract list_resource_schemas
if [ -n "$PROVIDER" ]; then
    # Specific provider
    provider_key=$(terraform providers schema -json 2>/dev/null | jq -r '.provider_schemas | keys[]' | grep "/${PROVIDER}$" || true)
    if [ -n "$provider_key" ]; then
        terraform providers schema -json 2>/dev/null | jq -r \
            "{\"$PROVIDER\": (.provider_schemas.\"${provider_key}\" | .list_resource_schemas // {} | keys | sort)}"
    else
        echo "{\"$PROVIDER\": []}"
    fi
else
    # All providers
    terraform providers schema -json 2>/dev/null | jq -r '
        .provider_schemas
        | to_entries
        | map({key: (.key | split("/")[-1]), value: (.value.list_resource_schemas // {} | keys | sort)})
        | from_entries
    '
fi
