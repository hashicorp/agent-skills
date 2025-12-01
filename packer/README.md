# Packer Instructions Library

This directory contains curated instruction sets, skills, and workflows for AI agents working with HashiCorp Packer. The structure is organized by product, then by use case, then by AI assistant/config folders.

## Directory Structure

```
packer/
├── creating-images/                # Use case: building and publishing images
└── README.md                       # This file
```

---

## Example Use Case: Creating and Publishing Images

**Scenario:** Build a secure, validated machine image and publish it to HCP Packer Registry.

**Requirements:**
- Automated build and validation
- Security scanning before publish
- Multi-cloud support (AWS, Azure, GCP)
- Registry integration

**Prompt:**
```
@workspace Using packer/creating-images/, create and publish a hardened Ubuntu image to HCP Registry.
```

---

## Additional Resources

- [Packer Documentation](https://www.packer.io/docs)
- [HCP Packer Registry](https://developer.hashicorp.com/packer/docs/hcp)
- [Security Scanning Tools](https://www.packer.io/guides/security)

---

## Tips for AI Agents

- Always validate images before publishing
- Run security scans on all builds
- Document build parameters and outputs
- Use versioned sources and registry integration
