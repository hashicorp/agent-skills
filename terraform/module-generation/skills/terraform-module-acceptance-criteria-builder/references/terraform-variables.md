## 1. Prefer Input Variables Over Hard‑Coding

- Use variables for anything that can change across:
  - environments (dev/stage/prod),
  - regions/accounts,
  - sizes (instance types, node counts),
  - feature toggles.
- Keep resource blocks mostly static; inject variability through variables and locals.

Example:

```hcl
variable "environment" {
  type        = string
  description = "Deployment environment (dev, stage, prod)"
}

resource "aws_s3_bucket" "logs" {
  bucket = "logs-${var.environment}"
}
```

---

## 2. Always Specify Type and Description

- Avoid untyped variables; they make refactoring and validation harder.
- Use `description` to document intent, not just what the value is.

```hcl
variable "instance_count" {
  type        = number
  description = "Number of application instances per AZ"
  default     = 2
}
```

Benefits:

- Clearer error messages.
- Better editor/IDE assistance.
- Safer future changes.

---

## 3. Use Sensible Defaults, but Don’t Overdo Them

- Provide defaults for common, low‑risk values (e.g., small instance size in dev).
- Omit defaults for:
  - credentials,
  - IDs of external resources,
  - environment‑critical choices (e.g., `environment`, `region` if you must choose carefully).

If a value is required, leave out `default` so Terraform forces the user to supply it.

---

## 4. Validate Variables Explicitly

Use `validation` blocks to catch errors early:

```hcl
variable "environment" {
  type        = string
  description = "Deployment environment: dev, stage, or prod"

  validation {
    condition     = contains(["dev", "stage", "prod"], var.environment)
    error_message = "environment must be one of: dev, stage, prod."
  }
}
```

Common validations:

- Allowed enums (`environment`, `tier`).
- Ranges (min/max for counts, sizes).
- Basic string patterns (e.g., prefix/suffix rules).

---

## 5. Structure Complex Data with Object/Map Types

Use structured types instead of many loosely related variables.

Bad:

```hcl
variable "app_cpu" {}
variable "app_memory" {}
variable "app_replicas" {}
```

Better:

```hcl
variable "app_config" {
  type = object({
    cpu      = number
    memory   = number
    replicas = number
  })
}
```

For environment‑specific overrides:

```hcl
variable "env_config" {
  type = map(object({
    instance_type = string
    min_size      = number
    max_size      = number
  }))
}

# Example value in a *.tfvars file
env_config = {
  dev = {
    instance_type = "t3.small"
    min_size      = 1
    max_size      = 2
  }
  prod = {
    instance_type = "m6i.large"
    min_size      = 3
    max_size      = 10
  }
}
```

---

## 6. Separate Locals from Variables

- **Variables**: external inputs (what callers/users can set).
- **Locals**: internal derived values or convenience expressions.

Example:

```hcl
variable "project" {
  type        = string
  description = "Project name used for tagging and naming"
}

variable "environment" {
  type        = string
  description = "Environment name"
}

locals {
  common_tags = {
    Project     = var.project
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}
```

Use `locals` to:

- centralize naming standards,
- centralize tags/labels,
- keep resource blocks clean.

---

## 7. Manage Sensitive and Secret Values Properly

- Mark secrets as `sensitive = true`:

```hcl
variable "db_password" {
  type        = string
  description = "Database password"
  sensitive   = true
}
```

- Never commit secrets to:
  - `.tf` files,
  - `*.tfvars` in version control,
  - shell history.

Better approaches:
- Use remote backends and secret managers (Vault, AWS SSM Parameter Store, AWS Secrets Manager, etc.) and feed values via:
  - environment variables with `-var` / `TF_VAR_...`,
  - pipelines that inject `*.auto.tfvars` at runtime (not stored in git).

Always add `*.tfvars`, `*.auto.tfvars`, and any secret files to `.gitignore` if they may contain secrets.

---

## 8. Use Variable Files for Environments

Standard pattern:

- `variables.tf` – definitions (type, description, validation).
- `dev.tfvars`, `stage.tfvars`, `prod.tfvars` – concrete values.
- Optionally, `terraform.tfvars` or `*.auto.tfvars` for defaults in a specific workspace.

Run:

```bash
terraform apply -var-file=dev.tfvars
terraform apply -var-file=prod.tfvars
```

Benefits:

- Clear separation between code and configuration.
- Easy automation per environment.

---

## 9. Keep Naming Consistent and Clear

- Use lowercase with underscores: `db_username`, `instance_type`.
- Make names reflect purpose, not implementation:
  - `app_subnet_ids` is better than `subnet_ids` in a large module.
  - `asg_min_size`/`asg_max_size` better than `min`/`max`.

Consistent naming makes modules easier to reuse across teams.

---

## 10. Design Module Variables for Reuse and Stability

When writing reusable modules:

- Start with a small, opinionated set of variables; add more only when needed.
- Prefer **higher‑level** variables over exposing every underlying option.
- Provide conservative defaults that are safe.
- Use `nullable = false` when you truly require values.
- Treat variable changes as part of the module's "public API version":
  - Avoid renaming variables without compatibility plans.
  - Removing variables is a breaking change for consumers.

---

## 11. Avoid Over‑Parameterization

Too many variables can be as bad as too few:

- Don't expose every possible Terraform argument as a variable.
- Keep inputs focused on what really changes between deployments.
- Use `locals` and opinionated defaults for the rest.

This improves:

- readability,
- maintainability,
- onboarding for new users of the module.

---

## 12. Use Environment Variables Carefully

Terraform supports `TF_VAR_name`:

```bash
export TF_VAR_environment=dev
export TF_VAR_db_password=...
terraform apply
```

Good for secrets injected from CI/CD or local secret stores.

However:

- Harder to reproduce manually unless documented.
- For non‑secret configuration, prefer checked‑in `*.tfvars` files.

---

## 13. Document Variables

- Add clear `description` for every variable.
- Consider using `README.md` with a variables table for reusable modules:
  - name,
  - type,
  - required/optional,
  - default,
  - description.

This helps teams understand how to use your modules without reading all the code.