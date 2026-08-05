.provider_schemas | to_entries[] | 
  .key as $provider | (.value|to_entries[]) | 
  .key as $block_type | (.value|del(.version)|to_entries[]) |
  .key as $resource_type | (.value.block.attributes // {} |to_entries[]) |
  .provider = $provider | .block_type = $block_type | .resource_type = $resource_type | .attribute_name = .key | del(.key) | . + .value | del(.value)

