# Example Test Suite

Complete example testing a VPC module with unit, integration, and mock tests.

## Unit Tests (Plan Mode)

```hcl
# tests/vpc_module_unit_test.tftest.hcl

variables {
  environment = "test"
  aws_region  = "us-west-2"
}

run "test_defaults" {
  command = plan

  variables {
    vpc_cidr = "10.0.0.0/16"
    vpc_name = "test-vpc"
  }

  assert {
    condition     = aws_vpc.main.cidr_block == "10.0.0.0/16"
    error_message = "VPC CIDR should match input"
  }

  assert {
    condition     = aws_vpc.main.enable_dns_hostnames == true
    error_message = "DNS hostnames should be enabled by default"
  }

  assert {
    condition     = aws_vpc.main.tags["Name"] == "test-vpc"
    error_message = "VPC name tag should match input"
  }
}

run "test_subnets" {
  command = plan

  variables {
    vpc_cidr        = "10.0.0.0/16"
    vpc_name        = "test-vpc"
    public_subnets  = ["10.0.1.0/24", "10.0.2.0/24"]
    private_subnets = ["10.0.10.0/24", "10.0.11.0/24"]
  }

  assert {
    condition     = length(aws_subnet.public) == 2
    error_message = "Should create 2 public subnets"
  }

  assert {
    condition     = length(aws_subnet.private) == 2
    error_message = "Should create 2 private subnets"
  }

  assert {
    condition = alltrue([
      for subnet in aws_subnet.private :
      subnet.map_public_ip_on_launch == false
    ])
    error_message = "Private subnets should not assign public IPs"
  }
}

run "test_outputs" {
  command = plan

  variables {
    vpc_cidr = "10.0.0.0/16"
    vpc_name = "test-vpc"
  }

  assert {
    condition     = output.vpc_id != ""
    error_message = "VPC ID output should not be empty"
  }

  assert {
    condition     = can(regex("^vpc-", output.vpc_id))
    error_message = "VPC ID should have correct format"
  }

  assert {
    condition     = output.vpc_cidr == "10.0.0.0/16"
    error_message = "VPC CIDR output should match input"
  }
}

run "test_invalid_cidr" {
  command = plan

  variables {
    vpc_cidr = "invalid"
    vpc_name = "test-vpc"
  }

  expect_failures = [
    var.vpc_cidr
  ]
}
```

## Integration Tests (Apply Mode)

```hcl
# tests/vpc_module_integration_test.tftest.hcl

variables {
  environment = "integration-test"
  aws_region  = "us-west-2"
}

run "integration_test_vpc_creation" {
  # command defaults to apply — creates real AWS resources

  variables {
    vpc_cidr = "10.100.0.0/16"
    vpc_name = "integration-test-vpc"
  }

  assert {
    condition     = aws_vpc.main.id != ""
    error_message = "VPC should be created with valid ID"
  }

  assert {
    condition     = aws_vpc.main.state == "available"
    error_message = "VPC should be in available state"
  }
}
```

## Mock Tests (Plan Mode, No Credentials)

```hcl
# tests/vpc_module_mock_test.tftest.hcl

mock_provider "aws" {
  mock_resource "aws_instance" {
    defaults = {
      id            = "i-1234567890abcdef0"
      instance_type = "t2.micro"
      ami           = "ami-12345678"
      public_ip     = "203.0.113.1"
      private_ip    = "10.0.1.100"
    }
  }

  mock_resource "aws_vpc" {
    defaults = {
      id                   = "vpc-12345678"
      cidr_block           = "10.0.0.0/16"
      enable_dns_hostnames = true
      enable_dns_support   = true
    }
  }

  mock_resource "aws_subnet" {
    defaults = {
      id                      = "subnet-12345678"
      vpc_id                  = "vpc-12345678"
      cidr_block              = "10.0.1.0/24"
      availability_zone       = "us-west-2a"
      map_public_ip_on_launch = false
    }
  }

  mock_data "aws_ami" {
    defaults = {
      id   = "ami-0c55b159cbfafe1f0"
      name = "ubuntu-focal-20.04-amd64"
    }
  }

  mock_data "aws_availability_zones" {
    defaults = {
      names = ["us-west-2a", "us-west-2b", "us-west-2c"]
    }
  }
}

run "test_instance_with_mocks" {
  command = plan

  variables {
    instance_type = "t2.micro"
    ami_id        = "ami-12345678"
  }

  assert {
    condition     = aws_instance.example.instance_type == "t2.micro"
    error_message = "Instance type should match input variable"
  }

  assert {
    condition     = aws_instance.example.id == "i-1234567890abcdef0"
    error_message = "Mock should return consistent instance ID"
  }
}

run "test_data_source_with_mocks" {
  command = plan

  assert {
    condition     = data.aws_ami.ubuntu.id == "ami-0c55b159cbfafe1f0"
    error_message = "Mock data source should return predictable AMI ID"
  }

  assert {
    condition     = length(data.aws_availability_zones.available.names) == 3
    error_message = "Should return 3 mocked availability zones"
  }

  assert {
    condition     = contains(data.aws_availability_zones.available.names, "us-west-2a")
    error_message = "Should include us-west-2a in mocked zones"
  }
}

run "test_outputs_with_mocks" {
  command = plan

  assert {
    condition     = output.vpc_id == "vpc-12345678"
    error_message = "VPC ID output should match mocked value"
  }

  assert {
    condition     = can(regex("^vpc-", output.vpc_id))
    error_message = "VPC ID output should have correct format"
  }
}

run "test_conditional_resources_with_mocks" {
  command = plan

  variables {
    create_bastion     = true
    create_nat_gateway = false
  }

  assert {
    condition     = length(aws_instance.bastion) == 1
    error_message = "Bastion should be created when enabled"
  }

  assert {
    condition     = length(aws_nat_gateway.nat) == 0
    error_message = "NAT gateway should not be created when disabled"
  }
}

run "test_tag_inheritance_with_mocks" {
  command = plan

  variables {
    common_tags = {
      Environment = "test"
      ManagedBy   = "Terraform"
    }
  }

  assert {
    condition = alltrue([
      for key in keys(var.common_tags) :
      contains(keys(aws_instance.example.tags), key)
    ])
    error_message = "All common tags should be present on instance"
  }
}

run "test_invalid_cidr_with_mocks" {
  command = plan

  variables {
    vpc_cidr = "invalid"
  }

  expect_failures = [
    var.vpc_cidr
  ]
}

run "setup_vpc_with_mocks" {
  command = plan

  variables {
    vpc_cidr = "10.0.0.0/16"
    vpc_name = "test-vpc"
  }

  assert {
    condition     = aws_vpc.main.cidr_block == "10.0.0.0/16"
    error_message = "VPC CIDR should match input"
  }
}

run "test_subnet_references_vpc_with_mocks" {
  command = plan

  variables {
    vpc_id      = run.setup_vpc_with_mocks.vpc_id
    subnet_cidr = "10.0.1.0/24"
  }

  assert {
    condition     = aws_subnet.example.vpc_id == run.setup_vpc_with_mocks.vpc_id
    error_message = "Subnet should reference VPC from previous run"
  }
}
```
