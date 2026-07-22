## 1. Output Only What Consumers Actually Need

Outputs are the "public interface" of your root module or reusable modules. Treat them like an API:

- Only expose values that:
  - are needed by other modules/stacks or external systems (CI/CD, scripts),
  - are useful for humans (e.g., URLs, IDs for debugging).
- Avoid exposing:
  - large or noisy structures that aren't really consumed,
  - full resource objects (use specific attributes instead).

Example: instead of outputting the entire VPC resource:

```hcl
# Avoid
output "vpc" {
  value = aws_vpc.main
}
```

Prefer specific, stable attributes:

```hcl
output "vpc_id" {
  value       = aws_vpc.main.id
  description = "ID of the main VPC"
}
```

---

## 2. Use `description` on Every Output

Descriptions help both humans and tooling understand your module's interface:

```hcl
output "alb_dns_name" {
  description = "DNS name of the public Application Load Balancer"
  value       = aws_lb.public.dns_name
}
```

This is especially important for shared modules that others will consume.

---

## 3. Mark Sensitive Outputs as `sensitive = true`

Never expose secrets in plain text outputs. If an output could contain:

- passwords,
- API keys,
- private keys,
- tokens,
- connection strings,

mark it as sensitive:

```hcl
output "db_password" {
  description = "Database password"
  value       = random_password.db.result
  sensitive   = true
}
```

This:

- hides values from `terraform apply`/`terraform output` CLI by default,
- helps prevent secrets from being logged in CI/CD pipelines.

Note: if a consumer explicitly runs `terraform output -json` and processes it somewhere else, they can still access the values; the sensitivity is mainly about display/logging.

---

## 4. Keep Outputs Stable (Treat Them as an API)

Changing outputs is a breaking change for:

- other Terraform configurations using `terraform_remote_state`,
- scripts or CI stages that parse `terraform output` or `terraform output -json`,
- teams that rely on those values.

Good practices:

- Choose clear, stable names from the start (`vpc_id`, `public_subnet_ids`, `alb_dns_name`).
- Avoid renaming/removing outputs lightly; if you must:
  - deprecate old outputs gradually,
  - keep old outputs as aliases for some time where feasible.

---

## 5. Prefer Simple, Predictable Data Structures

For outputs consumed by other modules or tools, aim for simple shapes:

- Strings for single values (`vpc_id`, `alb_dns_name`).
- Lists/sets of strings for collections (`public_subnet_ids`).
- Maps/objects where structure is intentional and documented.

Example:

```hcl
output "subnet_ids" {
  description = "IDs of the private subnets"
  value       = aws_subnet.private[*].id
}

output "endpoints" {
  description = "Endpoints of key services"
  value = {
    api_url  = aws_apigatewayv2_api.main.api_endpoint
    web_url  = aws_cloudfront_distribution.web.domain_name
  }
}
```

Avoid overly nested, "raw" outputs that leak provider internals unless your consumer really needs them.

---

## 6. Use Outputs to Bridge Between Stacks Safely

When you have separate Terraform stacks (e.g., network, data, application), outputs are often consumed through `terraform_remote_state` or by CI tooling:

```hcl
data "terraform_remote_state" "network" {
  backend = "s3"

  config = {
    bucket = "my-terraform-states"
    key    = "network/terraform.tfstate"
    region = "us-east-1"
  }
}

resource "aws_instance" "app" {
  subnet_id = data.terraform_remote_state.network.outputs.private_subnet_id
}
```

To make this robust:

- Keep "shared" outputs minimal and well‑named (`vpc_id`, `private_subnet_ids`, `security_group_ids`).
- Avoid exposing implementation details you may want to change (e.g., specific resource names).

---

## 7. Use `terraform output -json` for Automation

When scripts or CI/CD pipelines consume outputs, they should use the JSON form:

```bash
terraform output -json > outputs.json
```

Best practices:

- Design outputs with machine‑readable shapes (maps, lists, basic types).
- Avoid unnecessary formatting (e.g., embedding JSON as strings).
- Keep names and structures stable over time.

---

## 8. Don't Output Huge or Unnecessary Blobs

Avoid:

- giant user data scripts,
- large policies or templates,
- big binary blobs.

Reasons:

- `terraform output` becomes unreadable,
- state files become heavier,
- consumers rarely need all that data.

Instead, if you must share large artifacts, store them in a bucket/repo and output only:
- a URL,
- a key/path,
- or an ID.

---

## 9. Align Outputs with Environments and Teams

Think about who uses which outputs:

- Platform/network team:
  - cares about `vpc_id`, `subnet_ids`, `route_table_ids`, `shared_services_endpoint`.
- App team:
  - cares about `app_url`, `api_url`, `db_endpoint`, `queue_url`.

Consider organizing outputs and descriptions so each audience can quickly find what they need. In larger modules, grouping through naming conventions helps (`network_*`, `app_*`).

---

## 10. Use Outputs as a Debugging Aid

In addition to "public API" outputs, you can temporarily output values to debug:

```hcl
output "debug_asg_capacity" {
  value = aws_autoscaling_group.app.desired_capacity
}
```

Just remember to:

- remove or comment these once debugging is done,
- avoid exposing anything sensitive, or mark it `sensitive = true`.

---

## 11. Keep Outputs Close to the Resources They Expose (in Modules)

In bigger modules:

- It's often clearer to declare outputs in the same `.tf` file or near the resources they expose, or
- Keep all outputs in a dedicated `outputs.tf` file for consistency, but use clear, sectioned comments.

Pick one convention per repo and stick to it for readability.