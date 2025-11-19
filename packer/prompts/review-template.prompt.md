# prompt:packer-review-template

Goal: Review a Packer template for correctness, security, and maintainability.

Checklist:
- Variables typed and documented
- No secrets hardcoded; use env or Vault
- Provisioners idempotent; minimal mutable state
- Post-processors defined as needed
- `packer fmt` and `packer validate` pass