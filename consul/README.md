# Consul Skills & Workflows

This directory contains AI agent instructions for service mesh configuration, service discovery, and distributed systems patterns using HashiCorp Consul.

## Directory Structure

```
consul/
├── README.md (this file)
└── skills/
    └── configure-service-mesh/  # Service mesh setup (foundational/preview)
```

---

## Current Status: Foundational / Preview

This directory is in **early development** with foundational examples provided. Consul integration is expanding with more skills, workflows, and prompts coming soon.

### For Claude Desktop (Native SKILL.md Support)
```bash
# No setup needed! Claude auto-discovers SKILL.md files
# Just use natural language:

"Using the configure-service-mesh skill, set up service mesh for my microservices"
```

**Why this works**: Claude Desktop natively supports Anthropic's SKILL.md format with progressive disclosure. It automatically finds and loads relevant skills.

### What's Available Now

#### 🌐 [configure-service-mesh](skills/configure-service-mesh/)
**Purpose**: Basic service mesh configuration patterns for Consul

**Current Scope** (Preview):
- Service registration examples
- Basic intentions (service-to-service access)
- Health check configurations
- Service discovery patterns

**Use when**:
- Learning Consul service mesh basics
- Setting up simple service-to-service communication
- Implementing basic health checks
- Testing service discovery

**Example**:
```
@workspace Using consul/skills/configure-service-mesh/:

Setup basic service mesh for:
  - web-frontend (port 8080)
  - api-backend (port 8081)
  - database (port 5432)

Requirements:
  - web → api (allow)
  - api → database (allow)
  - web ↛ database (deny)
```

---

## 🚀 Quick Start (Current Preview)

### For GitHub Copilot Users

**Method 1: Direct reference**
```
@workspace Using consul/skills/configure-service-mesh/, create basic service registration
```

**Method 2: Repository Instructions**
Add to `.github/copilot-instructions.md`:
```markdown
## Consul Standards (Preview)
Reference consul/skills/configure-service-mesh/ for service mesh basics.
Note: This is preview content - full skills coming soon.
```

---

### For Claude Users

**Preview Usage**:
```bash
# Skills directory not yet available for full installation
# Use direct file reference for now

Using consul/skills/configure-service-mesh/, show me service registration example
```

---

## 📚 Example Usage (Current Preview)

### Example 1: Basic Service Registration

```hcl
# Service definition for web-frontend
service {
  name = "web-frontend"
  id   = "web-frontend-1"
  port = 8080

  tags = ["web", "frontend", "production"]

  check {
    id       = "web-health"
    name     = "HTTP Health Check"
    http     = "http://localhost:8080/health"
    interval = "10s"
    timeout  = "1s"
  }

  connect {
    sidecar_service {
      proxy {
        upstreams = [
          {
            destination_name = "api-backend"
            local_bind_port  = 8081
          }
        ]
      }
    }
  }
}
```

---

### Example 2: Basic Service Intentions

```hcl
# Allow web-frontend to communicate with api-backend
resource "consul_intention" "web_to_api" {
  source_name      = "web-frontend"
  destination_name = "api-backend"
  action           = "allow"
}

# Deny direct access from web-frontend to database
resource "consul_intention" "web_to_db" {
  source_name      = "web-frontend"
  destination_name = "database"
  action           = "deny"
}

# Allow api-backend to access database
resource "consul_intention" "api_to_db" {
  source_name      = "api-backend"
  destination_name = "database"
  action           = "allow"
}
```

---

### Example 3: Health Check Configuration

```hcl
# Comprehensive health checks
service {
  name = "api-backend"
  port = 8081

  # HTTP health check
  check {
    id       = "api-http"
    name     = "API HTTP Health"
    http     = "http://localhost:8081/health"
    method   = "GET"
    interval = "10s"
    timeout  = "2s"
  }

  # TCP health check
  check {
    id       = "api-tcp"
    name     = "API TCP Connectivity"
    tcp      = "localhost:8081"
    interval = "30s"
    timeout  = "5s"
  }

  # TTL health check
  check {
    id   = "api-ttl"
    name = "API TTL"
    ttl  = "30s"
  }
}
```

## Additional Resources

### Official Documentation
- [Consul Documentation](https://www.consul.io/docs)
- [Consul Service Mesh](https://www.consul.io/docs/connect)
- [HCP Consul](https://developer.hashicorp.com/consul/docs/hcp)
- [Consul Terraform Provider](https://registry.terraform.io/providers/hashicorp/consul/latest/docs)

### Tutorials
- [Get Started - Consul](https://learn.hashicorp.com/collections/consul/get-started)
- [Service Mesh Tutorial](https://learn.hashicorp.com/collections/consul/service-mesh)
- [Kubernetes Integration](https://learn.hashicorp.com/collections/consul/kubernetes)

### Community Resources
- [Consul GitHub](https://github.com/hashicorp/consul)
- [Consul Community Forum](https://discuss.hashicorp.com/c/consul)
