# Copyright IBM Corp. 2025, 2026
# SPDX-License-Identifier: MPL-2.0

# Converted from HashiCorp PCI DSS Sentinel example: elasticache-redis-replication-group-encryption-at-transit-enabled.sentinel
# Conversion quality: Perfect

resource_policy "aws_elasticache_replication_group" "elasticache_redis_replication_group_encryption_at_transit_enabled" {
    enforce {
        condition = core::try(attrs.transit_encryption_enabled, false) == true
        error_message = "ElastiCache replication groups must enable transit_encryption_enabled"
    }
}
