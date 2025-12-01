# Packer Instructions Library

This directory contains curated instruction sets, skills, and workflows for AI agents working with HashiCorp Packer. The structure is organized by product, then by use case, then by AI assistant/config folders.

## Directory Structure

```
packer/
├── creating-images/                # Use case: building and publishing images
│   ├── .vscode/                    # Editor/workspace settings for this use case
│   ├── .kiro/                      # Kiro agent configs (if present)
│   ├── .aws/                       # AWS integration configs (if present)
│   ├── skills/                     # Discrete, reusable Packer capabilities
│   ├── workflows/                  # Multi-step Packer processes
│   └── README.md                   # Use-case specific documentation
├── another-use-case/               # (Add more use cases as needed)
│   └── ...                         # Same structure as above
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
@workspace Using packer/creating-images/skills/build-validate/, create and publish a hardened Ubuntu image to HCP Registry.
```

---

## Skills

- `build-validate/`: Automated image build and validation
- `publish-to-registry/`: Publish images to HCP Packer Registry
- `scan-image-security/`: Security scan for built images

---

## Workflows

- `build-validate-scan-publish.md`: End-to-end workflow for image creation, validation, scanning, and publishing
- `promote-image-with-approval.md`: Promotion workflow with human approval gates

---

## Integration & Config Folders

- `.vscode/`: Editor/workspace settings for Packer projects
- `.kiro/`: Kiro agent configuration (if present)
- `.aws/`: AWS integration configs (if present)

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
