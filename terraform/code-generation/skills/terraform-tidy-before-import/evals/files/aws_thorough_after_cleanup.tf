# __generated__ by Terraform
# Please review these resources and move them into your main configuration files.

# __generated__ by Terraform
variable "aws_account_id" {
  type    = string
  default = "904233096703"
}

variable "aws_primary_region" {
  type    = string
  default = "us-east-2"
}

variable "aws_secondary_region" {
  type    = string
  default = "us-west-2"
}

variable "azurerm_resource_group_name" {
  type    = string
  default = "mapreduce"
}

variable "primary_owner_email" {
  type    = string
  default = "noreply@example.org"
}

resource "aws_ssm_parameter" "unlock_code" {
  provider         = aws
  data_type        = "text"
  key_id           = "alias/aws/ssm"
  name             = "UnlockCode"
  region           = var.aws_primary_region
  tags             = {}
  tags_all         = {}
  tier             = "Standard"
  type             = "SecureString"
  value_wo         = "__imported__"
  value_wo_version = 1

  lifecycle {
    ignore_changes = [value_wo_version]
  }
}

import {
  to       = aws_ssm_parameter.unlock_code
  provider = aws
  identity = {
    account_id = var.aws_account_id
    name       = "UnlockCode"
    region     = var.aws_primary_region
  }
}

resource "aws_ssm_parameter" "foo_parameter" {
  provider         = aws
  data_type        = "text"
  name             = "foo"
  region           = var.aws_primary_region
  tags             = {}
  tags_all         = {}
  tier             = "Standard"
  type             = "String"
  value_wo         = "__imported__"
  value_wo_version = 1

  lifecycle {
    ignore_changes = [value_wo_version]
  }
}

import {
  to       = aws_ssm_parameter.foo_parameter
  provider = aws
  identity = {
    account_id = var.aws_account_id
    name       = "foo"
    region     = var.aws_primary_region
  }
}

# __generated__ by Terraform
resource "awscc_autoscaling_auto_scaling_group" "terraform_20260412_group" {
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
      value               = var.primary_owner_email
    },
  ]
  termination_policies = ["Default"]
}

import {
  to       = awscc_autoscaling_auto_scaling_group.terraform_20260412_group
  provider = awscc
  identity = {
    account_id              = var.aws_account_id
    auto_scaling_group_name = "terraform-20260412125441192100000003"
    region                  = var.aws_primary_region
  }
}

# __generated__ by Terraform
resource "aws_instance" "pi_in_the_sky" {
  provider                             = aws
  ami                                  = "ami-0c13074f00e476295"
  availability_zone                    = "us-east-2a"
  disable_api_stop                     = false
  disable_api_termination              = false
  ebs_optimized                        = false
  get_password_data                    = false
  hibernation                          = false
  instance_initiated_shutdown_behavior = "stop"
  instance_type                        = "t4g.nano"
  monitoring                           = false
  placement_partition_number           = 0
  region                               = var.aws_primary_region
  security_groups                      = ["default"]
  source_dest_check                    = true
  subnet_id                            = "subnet-07dfd740d46f2971c"
  tags = {
    Name  = "pi-in-the-sky"
    owner = var.primary_owner_email
  }
  tags_all = {
    Name  = "pi-in-the-sky"
    owner = var.primary_owner_email
  }
  tenancy                = "default"
  vpc_security_group_ids = ["sg-0ce804325eb0f5ca9"]

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
}

import {
  to       = aws_instance.pi_in_the_sky
  provider = aws
  identity = {
    account_id = var.aws_account_id
    id         = "i-042b87bcd5bd6012c"
    region     = var.aws_primary_region
  }
}

# __generated__ by Terraform
resource "aws_instance" "computer_1" {
  provider                             = aws
  ami                                  = "ami-0049c21f5d9fb57c2"
  availability_zone                    = "us-west-2d"
  disable_api_stop                     = false
  disable_api_termination              = false
  ebs_optimized                        = false
  get_password_data                    = false
  hibernation                          = false
  iam_instance_profile                 = "team-awesome"
  instance_initiated_shutdown_behavior = "stop"
  instance_type                        = "t4g.nano"
  monitoring                           = false
  placement_partition_number           = 0
  region                               = var.aws_secondary_region
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
  tenancy                = "default"
  vpc_security_group_ids = ["sg-0d186b4390fe6e7b8"]

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
}

import {
  to       = aws_instance.computer_1
  provider = aws
  identity = {
    account_id = var.aws_account_id
    id         = "i-06e6fc683132a44ff"
    region     = var.aws_secondary_region
  }
}

# __generated__ by Terraform
resource "azurerm_resource_group" "mapreduce" {
  provider = azurerm
  location = "westeurope"
  name     = var.azurerm_resource_group_name
  tags = {
    availability = "online"
  }
}

import {
  to       = azurerm_resource_group.mapreduce
  provider = azurerm
  identity = {
    name            = var.azurerm_resource_group_name
    subscription_id = "6365c18e-b304-4096-a2c5-56e6dd2dbbe7"
  }
}

# __generated__ by Terraform
resource "azurerm_storage_account" "mapreduce_garage" {
  provider                          = azurerm
  access_tier                       = "Hot"
  account_kind                      = "StorageV2"
  account_replication_type          = "GRS"
  account_tier                      = "Standard"
  allow_nested_items_to_be_public   = true
  cross_tenant_replication_enabled  = false
  default_to_oauth_authentication   = false
  dns_endpoint_type                 = "Standard"
  https_traffic_only_enabled        = true
  infrastructure_encryption_enabled = false
  is_hns_enabled                    = false
  large_file_share_enabled          = false
  local_user_enabled                = true
  location                          = "westeurope"
  min_tls_version                   = "TLS1_2"
  name                              = "mapreducegarage"
  nfsv3_enabled                     = false
  public_network_access_enabled     = true
  queue_encryption_key_type         = "Service"
  resource_group_name               = var.azurerm_resource_group_name
  sftp_enabled                      = false
  shared_access_key_enabled         = true
  table_encryption_key_type         = "Service"
  tags = {
    availability = "online"
  }

  blob_properties {
    change_feed_enabled      = false
    last_access_time_enabled = false
    versioning_enabled       = false
  }

  share_properties {
    retention_policy {
      days = 7
    }
  }
}

import {
  to       = azurerm_storage_account.mapreduce_garage
  provider = azurerm
  identity = {
    name                = "mapreducegarage"
    resource_group_name = var.azurerm_resource_group_name
    subscription_id     = "6365c18e-b304-4096-a2c5-56e6dd2dbbe7"
  }
}
