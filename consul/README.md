# Consul Skills & Workflows

This directory contains AI agent instructions for service mesh configuration, service discovery, and distributed systems patterns using HashiCorp Consul.

## 📁 Directory Structure

```
consul/
├── README.md (this file)
└── skills/
    └── configure-service-mesh/  # Service mesh setup (foundational/preview)
```

---

### For Claude Desktop (Native SKILL.md Support)
```bash
# No setup needed! Claude auto-discovers SKILL.md files
# Just use natural language:

"Using the configure-service-mesh skill, set up service mesh for my microservices"
```

**Why this works**: Claude Desktop natively supports Anthropic's SKILL.md format with progressive disclosure. It automatically finds and loads relevant skills.

## 🚧 Current Status: Foundational / Preview

This directory is in **early development** with foundational examples provided. Consul integration is expanding with more skills, workflows, and prompts coming soon.

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

## 🎯 Roadmap

The following skills and workflows are planned for future releases:

### Planned Skills

#### 🔒 **generate-intentions** (Coming Soon)
Create service-to-service authorization policies

**Will include**:
- L4/L7 traffic authorization
- HTTP method/path filtering
- JWT-based authorization
- Service identity verification

---

#### 🏥 **configure-health-checks** (Coming Soon)
Implement comprehensive health monitoring

**Will include**:
- HTTP/TCP/gRPC health checks
- Custom script checks
- TTL-based health reporting
- Failure threshold configuration

---

#### 🔍 **setup-service-discovery** (Coming Soon)
Configure DNS and HTTP service discovery

**Will include**:
- DNS integration patterns
- Prepared queries
- Load balancing strategies
- Failover configuration

---

#### 🛡️ **implement-secure-communication** (Coming Soon)
Enable mTLS and encryption

**Will include**:
- Certificate authority setup
- Automatic certificate rotation
- mTLS enforcement
- Encryption verification

---

### Planned Workflows

#### 🚀 **zero-downtime-deployment** (Coming Soon)
Rolling deployments with traffic shifting

**Will include**:
- Canary deployments
- Blue/green traffic routing
- Gradual rollout strategies
- Rollback procedures

---

#### 🌍 **multi-datacenter-federation** (Coming Soon)
Connect Consul clusters across regions

**Will include**:
- WAN federation setup
- Cross-DC service discovery
- Failover to remote datacenters
- Network topology considerations

---

#### 📊 **observability-integration** (Coming Soon)
Integrate with monitoring and tracing

**Will include**:
- Prometheus metrics export
- Distributed tracing (Jaeger, Zipkin)
- Logging integration
- Dashboard creation

---

### Planned Prompts

#### 🤖 **system-prompt-consul** (Coming Soon)
AI agent behavior for Consul service mesh work

#### 📋 **design-service-topology** (Coming Soon)
Generate service mesh architecture diagrams

#### 🔧 **troubleshoot-connectivity** (Coming Soon)
Debug service-to-service communication issues

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

### For AGENTS.md Compatible Tools

**Add to AGENTS.md**:
```markdown
## Consul Service Mesh (Preview)

### Basic Configuration
Use: agent-instructions-library-man/consul/skills/configure-service-mesh/

Note: Foundational examples only. Full skills library under development.
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

---

## 🎓 Learning Path (Preview)

Since Consul skills are in early development, we recommend:

### Beginners
1. Review foundational examples in `configure-service-mesh/`
2. Study official Consul documentation (see Resources below)
3. Try basic service registration locally
4. Experiment with simple intentions

### Intermediate
1. Set up Consul in development environment
2. Practice service discovery patterns
3. Implement health checks
4. Test service-to-service communication

### Advanced
1. Explore Consul's Terraform provider
2. Study enterprise features (namespaces, partitions)
3. Plan for multi-datacenter scenarios
4. Research observability integration

---

## 🔗 Current Integration Examples

### Terraform with Consul Provider

```hcl
terraform {
  required_providers {
    consul = {
      source  = "hashicorp/consul"
      version = "~> 2.18"
    }
  }
}

provider "consul" {
  address    = "localhost:8500"
  datacenter = "dc1"
}

# Register service via Terraform
resource "consul_service" "web_app" {
  name    = "web-app"
  node    = consul_node.app_server.name
  port    = 8080
  tags    = ["web", "production"]

  check {
    check_id = "web-app-health"
    name     = "Web App Health"
    http     = "http://localhost:8080/health"
    interval = "10s"
    timeout  = "1s"
  }
}

# Create intention
resource "consul_config_entry" "web_to_api_intention" {
  kind = "service-intentions"
  name = "api-backend"

  config_json = jsonencode({
    Sources = [
      {
        Name   = "web-frontend"
        Action = "allow"
      }
    ]
  })
}
```

---

### Kubernetes with Consul

```yaml
# ServiceDefaults for web-frontend
apiVersion: consul.hashicorp.com/v1alpha1
kind: ServiceDefaults
metadata:
  name: web-frontend
spec:
  protocol: http
---
# ServiceIntentions for web → api
apiVersion: consul.hashicorp.com/v1alpha1
kind: ServiceIntentions
metadata:
  name: api-backend
spec:
  destination:
    name: api-backend
  sources:
    - name: web-frontend
      action: allow
```

---

## 📚 Additional Resources

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

---

## 🤝 Contributing

This directory is actively being developed. Contributions are welcome!

**How to contribute**:
1. Add new skills following the structure in other product directories
2. Include examples with HCL, YAML, or relevant formats
3. Document use cases and prerequisites
4. Provide integration examples (Terraform, Kubernetes, Docker)
5. Update this README with your additions

**Priority areas**:
- Service mesh security patterns (mTLS, intentions)
- Health check strategies
- Service discovery examples
- Multi-datacenter patterns
- Observability integration

---

## 💡 Current Limitations

**What's NOT yet available**:
- ❌ Complete skills library (only foundational examples)
- ❌ Comprehensive workflows
- ❌ AI agent system prompts specific to Consul
- ❌ Advanced service mesh patterns
- ❌ Multi-datacenter federation guides
- ❌ Enterprise feature documentation

**What IS available**:
- ✅ Basic service registration examples
- ✅ Simple intention patterns
- ✅ Health check configurations
- ✅ Service discovery concepts
- ✅ Terraform provider examples

---

## 🔮 What to Expect

As this library matures, you can expect:

1. **Comprehensive Skills**: Similar depth to Terraform, Vault, and Vault Radar skills
2. **Production Workflows**: Multi-step deployment and management processes
3. **AI Agent Integration**: System prompts and specialized agents for Consul
4. **Best Practices**: Security hardening, performance optimization
5. **Real-World Examples**: Complete architectures and patterns
6. **Platform Integration**: GitHub Copilot, Claude, VS Code, JetBrains

---

## 📢 Feedback Welcome

This is preview content. If you need specific Consul skills or workflows:

1. Open an issue describing your use case
2. Provide examples of what you're trying to accomplish
3. Share any existing patterns you'd like to see documented
4. Suggest priority areas for development

---

## 🔄 Migration Note

If you're migrating from other service mesh solutions or service discovery tools:

**From Kubernetes Service Discovery**:
- Consul provides cross-platform service discovery (not just K8s)
- Native health checking without liveness/readiness probes
- Multi-datacenter federation built-in

**From Istio/Linkerd**:
- Consul works across VMs and containers
- Simpler operational model (no CRDs proliferation)
- Integrated KV store for configuration

**From DNS-based Discovery**:
- Dynamic health-aware updates
- More granular traffic management
- Built-in security (mTLS, intentions)

---

**Remember**: This is foundational content. Full Consul skills library coming soon!

**🌐 Service Mesh Simplified | 🔍 Discovery Made Easy | 🛡️ Security Built-In**

---

## Stay Updated

Watch this repository for:
- New skills releases
- Workflow documentation
- Integration examples
- Best practices guides

**Current Status**: Preview / Foundational Examples  
**Next Milestone**: Complete `generate-intentions` and `configure-health-checks` skills  
**Target**: Match feature parity with Terraform, Vault, and Vault Radar directories
