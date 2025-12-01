

# Consul Instructions Library

This directory contains curated instruction sets, skills, and workflows for AI agents working with HashiCorp Consul. The structure is organized by product, then by use case, then by AI assistant/config folders.

## Directory Structure

```
consul/
├── service-mesh/                 # Use case: service mesh configuration
│   ├── .vscode/                  # Editor/workspace settings for this use case
│   ├── .kiro/                    # Kiro agent configs (if present)
│   ├── .aws/                     # AWS integration configs (if present)
│   ├── skills/                   # Discrete, reusable Consul capabilities
│   ├── workflows/                # Multi-step Consul processes
│   └── README.md                 # Use-case specific documentation
├── another-use-case/             # (Add more use cases as needed)
│   └── ...                       # Same structure as above
└── README.md                     # This file
```

---


## Example Use Case: Service Mesh Setup

**Scenario:** Deploy a secure service mesh for a microservices application.

**Requirements:**
- Register three services: web-frontend, api-backend, database
- Allow web → api, api → database; deny web → database
- Health checks for all services

**Prompt:**
```
@workspace Using consul/service-mesh/skills/configure-service-mesh/, setup service mesh for web-frontend, api-backend, and database with proper intentions and health checks.
```

---


## Skills

**Skills** are reusable capabilities for Consul tasks.

- `configure-service-mesh/`: Service mesh setup, registration, intentions, health checks

---


## Integration & Config Folders

- `.vscode/`: Editor/workspace settings for Consul projects
- `.kiro/`: Kiro agent configuration (if present)
- `.aws/`: AWS integration configs (if present)

---


## Quick Start

**Direct reference:**
```
@workspace Using consul/service-mesh/skills/configure-service-mesh/, create basic service registration
```

**Repository instructions:**
Add to `.github/copilot-instructions.md`:
```
## Consul Standards
Reference consul/service-mesh/skills/configure-service-mesh/ for service mesh basics.
```

---

## Additional Resources

- [Consul Documentation](https://www.consul.io/docs)
- [Consul Service Mesh](https://www.consul.io/docs/connect)
- [HCP Consul](https://developer.hashicorp.com/consul/docs/hcp)
- [Consul Terraform Provider](https://registry.terraform.io/providers/hashicorp/consul/latest/docs)
- [Get Started - Consul](https://learn.hashicorp.com/collections/consul/get-started)
- [Service Mesh Tutorial](https://learn.hashicorp.com/collections/consul/service-mesh)
- [Kubernetes Integration](https://learn.hashicorp.com/collections/consul/kubernetes)
- [Consul GitHub](https://github.com/hashicorp/consul)
- [Consul Community Forum](https://discuss.hashicorp.com/c/consul)
