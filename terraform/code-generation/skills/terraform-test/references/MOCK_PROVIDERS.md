# Mock Providers

Mock providers simulate provider behavior without creating real infrastructure (Terraform 1.7.0+). Use them for fast, credential-free unit tests.

## Basic Mock Provider

```hcl
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

  mock_data "aws_ami" {
    defaults = {
      id = "ami-0c55b159cbfafe1f0"
    }
  }

  mock_data "aws_availability_zones" {
    defaults = {
      names = ["us-west-2a", "us-west-2b", "us-west-2c"]
    }
  }
}

run "test_with_mocks" {
  command = plan  # Mocks only work with plan mode

  assert {
    condition     = aws_instance.example.id == "i-1234567890abcdef0"
    error_message = "Mock instance ID should match"
  }
}
```

## Aliased Mock Provider

```hcl
mock_provider "aws" {
  alias = "mocked"

  mock_resource "aws_s3_bucket" {
    defaults = {
      id  = "test-bucket-12345"
      arn = "arn:aws:s3:::test-bucket-12345"
    }
  }
}

run "test_with_aliased_mock" {
  command = plan

  providers = {
    aws = provider.aws.mocked
  }

  assert {
    condition     = aws_s3_bucket.example.id == "test-bucket-12345"
    error_message = "Bucket ID should match mock"
  }
}
```

## Common Mock Defaults

```hcl
mock_provider "aws" {
  mock_resource "aws_vpc" {
    defaults = {
      id                    = "vpc-12345678"
      cidr_block            = "10.0.0.0/16"
      enable_dns_hostnames  = true
      enable_dns_support    = true
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

  mock_resource "aws_s3_bucket" {
    defaults = {
      id     = "test-bucket-12345"
      arn    = "arn:aws:s3:::test-bucket-12345"
      region = "us-west-2"
    }
  }

  mock_data "aws_vpc" {
    defaults = {
      id         = "vpc-12345678"
      cidr_block = "10.0.0.0/16"
    }
  }
}
```

## When to Use Mocks

**Good fit:**
- Testing Terraform logic, conditionals, `for_each`/`count` expressions
- Validating variable transformations and output calculations
- Local development without cloud credentials
- Fast CI/CD feedback loops

**Not a good fit:**
- Validating actual provider API behavior
- Testing real resource creation side effects
- End-to-end integration testing

## Limitations

- **Plan mode only** — mocks don't work with `command = apply`
- Mock defaults may not reflect real computed attribute values
- Mocks need manual updates when provider schemas change
- Can't test real resource dependencies or timing
