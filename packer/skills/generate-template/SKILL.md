# Skill: Generate Packer Template

## Overview
Generate secure, maintainable Packer templates (HCL2) for AWS, Azure, GCP, and VMware, following HashiCorp best practices.

## Capability Statement
The agent will author a complete template with:
- Sources (e.g., `amazon-ebs`, `googlecompute`, `azure-arm`, `vmware-iso`)
- Typed variables and sensible defaults
- Build blocks with idempotent, non‑interactive provisioners (no secrets inline)
- Optional post‑processors (manifest, HCP publish)
- Validation via `packer fmt` and `packer validate`

## Prerequisites
- Packer ≥ 1.10 installed
- Cloud credentials via environment or profiles (never hardcode)
- For HCP: credentials stored securely (env), never in code

## Execution Steps
1. Confirm platform(s), base image, region(s), and hardening needs.
2. Create `variables.pkr.hcl` for inputs (e.g., `region`, `source_image`).
3. Write `main.pkr.hcl`:
   - `source` blocks per platform
   - `build` block with idempotent provisioners
   - Optional `post‑processors` (manifest, HCP registry)
4. Add `README.md` with usage examples.
5. Run `packer fmt` and `packer validate`.
6. Output: ready‑to‑run template plus build commands.

## Examples
- AWS with `amazon-ebs`, Ubuntu base, CIS hardening provisioning
- GCP with `googlecompute`, SBOM generation via Trivy during build
