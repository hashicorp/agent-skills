# __generated__ by Terraform
# Please review these resources and move them into your main configuration files.

# __generated__ by Terraform
resource "aws_ssm_parameter" "by_aws_region_0_0" {
  provider         = aws
  allowed_pattern  = null
  arn              = "arn:aws:ssm:us-east-2:904233096703:parameter/UnlockCode"
  data_type        = "text"
  description      = null
  key_id           = "alias/aws/ssm"
  name             = "UnlockCode"
  overwrite        = null
  region           = "us-east-2"
  tags             = {}
  tags_all         = {}
  tier             = "Standard"
  type             = "SecureString"
  value            = null # sensitive
  value_wo         = null # sensitive
  value_wo_version = null
}

import {
  to       = aws_ssm_parameter.by_aws_region_0_0
  provider = aws
  identity = {
    account_id = "904233096703"
    name       = "UnlockCode"
    region     = "us-east-2"
  }
}

resource "aws_ssm_parameter" "by_aws_region_0_1" {
  provider         = aws
  allowed_pattern  = null
  arn              = "arn:aws:ssm:us-east-2:904233096703:parameter/foo"
  data_type        = "text"
  description      = null
  name             = "foo"
  overwrite        = null
  region           = "us-east-2"
  tags             = {}
  tags_all         = {}
  tier             = "Standard"
  type             = "String"
  value            = null # sensitive
  value_wo         = null # sensitive
  value_wo_version = null
}

import {
  to       = aws_ssm_parameter.by_aws_region_0_1
  provider = aws
  identity = {
    account_id = "904233096703"
    name       = "foo"
    region     = "us-east-2"
  }
}



# __generated__ by Terraform
resource "awscc_autoscaling_auto_scaling_group" "global_0_0" {
  provider                = awscc
  auto_scaling_group_name = "terraform-20260412125441192100000003"
  availability_zone_distribution = {
    capacity_distribution_strategy = "balanced-best-effort"
  }
  availability_zone_ids = ["use2-az3"]
  availability_zones    = ["us-east-2c"]
  capacity_reservation_specification = {
    capacity_reservation_preference = "default"
  }
  cooldown                  = "300"
  desired_capacity          = "1"
  health_check_grace_period = 300
  health_check_type         = "EC2"
  instance_lifecycle_policy = {
    retention_triggers = {
      terminate_hook_abandon = "terminate"
    }
  }
  launch_configuration_name             = "terraform-20260416020319060500000001"
  max_size                              = "1"
  min_size                              = "1"
  new_instances_protected_from_scale_in = false
  service_linked_role_arn               = "arn:aws:iam::904233096703:role/aws-service-role/autoscaling.amazonaws.com/AWSServiceRoleForAutoScaling"
  tags = [
    {
      key                 = "owner"
      propagate_at_launch = true
      value               = "noreply@example.org"
    },
  ]
  termination_policies = ["Default"]
}

import {
  to       = awscc_autoscaling_auto_scaling_group.global_0_0
  provider = awscc
  identity = {
    account_id              = "904233096703"
    auto_scaling_group_name = "terraform-20260412125441192100000003"
    region                  = "us-east-2"
  }
}



# __generated__ by Terraform
resource "aws_instance" "by_aws_region_0_0" {
  provider                             = aws
  ami                                  = "ami-0c13074f00e476295"
  associate_public_ip_address          = false
  availability_zone                    = "us-east-2a"
  disable_api_stop                     = false
  disable_api_termination              = false
  ebs_optimized                        = false
  force_destroy                        = null
  get_password_data                    = false
  hibernation                          = false
  instance_initiated_shutdown_behavior = "stop"
  instance_type                        = "t4g.nano"
  ipv6_address_count                   = 0
  ipv6_addresses                       = []
  monitoring                           = false
  placement_partition_number           = 0
  private_ip                           = "172.31.3.80"
  region                               = "us-east-2"
  secondary_private_ips                = []
  security_groups                      = ["default"]
  source_dest_check                    = true
  subnet_id                            = "subnet-07dfd740d46f2971c"
  tags = {
    Name  = "pi-in-the-sky"
    owner = "noreply@example.org"
  }
  tags_all = {
    Name  = "pi-in-the-sky"
    owner = "noreply@example.org"
  }
  tenancy                     = "default"
  user_data_replace_on_change = null
  volume_tags                 = null
  vpc_security_group_ids      = ["sg-0ce804325eb0f5ca9"]
  capacity_reservation_specification {
    capacity_reservation_preference = "open"
  }
  cpu_options {
    core_count       = 2
    threads_per_core = 1
  }
  credit_specification {
    cpu_credits = "unlimited"
  }
  enclave_options {
    enabled = false
  }
  maintenance_options {
    auto_recovery = "default"
  }
  metadata_options {
    http_endpoint               = "enabled"
    http_protocol_ipv6          = "disabled"
    http_put_response_hop_limit = 2
    http_tokens                 = "required"
    instance_metadata_tags      = "disabled"
  }
  private_dns_name_options {
    enable_resource_name_dns_a_record    = false
    enable_resource_name_dns_aaaa_record = false
    hostname_type                        = "ip-name"
  }
  root_block_device {
    delete_on_termination = true
    encrypted             = false
    iops                  = 3000
    tags                  = {}
    tags_all              = {}
    throughput            = 125
    volume_size           = 8
    volume_type           = "gp3"
  }
  timeouts {
    create = null
    delete = null
    read   = null
    update = null
  }
}

import {
  to       = aws_instance.by_aws_region_0_0
  provider = aws
  identity = {
    account_id = "904233096703"
    id         = "i-042b87bcd5bd6012c"
    region     = "us-east-2"
  }
}



# __generated__ by Terraform
resource "aws_instance" "by_aws_region_2_0" {
  provider                             = aws
  ami                                  = "ami-0049c21f5d9fb57c2"
  associate_public_ip_address          = true
  availability_zone                    = "us-west-2d"
  disable_api_stop                     = false
  disable_api_termination              = false
  ebs_optimized                        = false
  force_destroy                        = null
  get_password_data                    = false
  hibernation                          = false
  iam_instance_profile                 = "team-awesome"
  instance_initiated_shutdown_behavior = "stop"
  instance_type                        = "t4g.nano"
  ipv6_address_count                   = 0
  ipv6_addresses                       = []
  monitoring                           = false
  placement_partition_number           = 0
  private_ip                           = "172.31.48.66"
  region                               = "us-west-2"
  secondary_private_ips                = []
  security_groups                      = ["default"]
  source_dest_check                    = true
  subnet_id                            = "subnet-077c9d307457f4512"
  tags = {
    Name  = "computer-1"
    owner = "team-awesome@example.org"
  }
  tags_all = {
    Name  = "computer-1"
    owner = "team-awesome@example.org"
  }
  tenancy                     = "default"
  user_data                   = null
  user_data_replace_on_change = null
  volume_tags                 = null
  vpc_security_group_ids      = ["sg-0d186b4390fe6e7b8"]
  capacity_reservation_specification {
    capacity_reservation_preference = "open"
  }
  cpu_options {
    core_count       = 2
    threads_per_core = 1
  }
  credit_specification {
    cpu_credits = "unlimited"
  }
  enclave_options {
    enabled = false
  }
  maintenance_options {
    auto_recovery = "default"
  }
  metadata_options {
    http_endpoint               = "enabled"
    http_protocol_ipv6          = "disabled"
    http_put_response_hop_limit = 2
    http_tokens                 = "required"
    instance_metadata_tags      = "disabled"
  }
  private_dns_name_options {
    enable_resource_name_dns_a_record    = false
    enable_resource_name_dns_aaaa_record = false
    hostname_type                        = "ip-name"
  }
  root_block_device {
    delete_on_termination = true
    encrypted             = false
    iops                  = 3000
    tags                  = {}
    tags_all              = {}
    throughput            = 125
    volume_size           = 8
    volume_type           = "gp3"
  }
  timeouts {
    create = null
    delete = null
    read   = null
    update = null
  }
}

import {
  to       = aws_instance.by_aws_region_2_0
  provider = aws
  identity = {
    account_id = "904233096703"
    id         = "i-06e6fc683132a44ff"
    region     = "us-west-2"
  }
}



# __generated__ by Terraform
resource "azurerm_resource_group" "global_0_0" {
  provider   = azurerm
  location   = "westeurope"
  managed_by = null
  name       = "mapreduce"
  tags = {
    availability = "online"
  }
  timeouts {
    create = null
    delete = null
    read   = null
    update = null
  }
}

import {
  to       = azurerm_resource_group.global_0_0
  provider = azurerm
  identity = {
    name            = "mapreduce"
    subscription_id = "6365c18e-b304-4096-a2c5-56e6dd2dbbe7"
  }
}



# __generated__ by Terraform
resource "azurerm_storage_account" "by_resource_group_0_0" {
  provider                          = azurerm
  access_tier                       = "Hot"
  account_kind                      = "StorageV2"
  account_replication_type          = "GRS"
  account_tier                      = "Standard"
  allow_nested_items_to_be_public   = true
  allowed_copy_scope                = null
  cross_tenant_replication_enabled  = false
  default_to_oauth_authentication   = false
  dns_endpoint_type                 = "Standard"
  edge_zone                         = null
  https_traffic_only_enabled        = true
  infrastructure_encryption_enabled = false
  is_hns_enabled                    = false
  large_file_share_enabled          = false
  local_user_enabled                = true
  location                          = "westeurope"
  min_tls_version                   = "TLS1_2"
  name                              = "mapreducegarage"
  nfsv3_enabled                     = false
  provisioned_billing_model_version = null
  public_network_access_enabled     = true
  queue_encryption_key_type         = "Service"
  resource_group_name               = "mapreduce"
  sftp_enabled                      = false
  shared_access_key_enabled         = true
  table_encryption_key_type         = "Service"
  tags = {
    availability = "online"
  }
  blob_properties {
    change_feed_enabled           = false
    change_feed_retention_in_days = 0
    last_access_time_enabled      = false
    versioning_enabled            = false
  }
  share_properties {
    retention_policy {
      days = 7
    }
  }
  timeouts {
    create = null
    delete = null
    read   = null
    update = null
  }
}

import {
  to       = azurerm_storage_account.by_resource_group_0_0
  provider = azurerm
  identity = {
    name                = "mapreducegarage"
    resource_group_name = "mapreduce"
    subscription_id     = "6365c18e-b304-4096-a2c5-56e6dd2dbbe7"
  }
}


