# Skill: Build Image

## Overview
Run `packer build` reliably with reproducible provisioning and clear artifacts.

## Capability Statement
- Produce build commands with `-var-file` and env overrides
- Avoid `-force` unless documented; prefer clean builds
- Capture logs and emit manifest to `build_artifacts/`

## Prerequisites
Validated template; credentials via env; network to package repos

## Execution Steps
1. Create `vars/production.pkrvars.hcl` (document inputs).
2. Run: `packer build -var-file=vars/production.pkrvars.hcl -color=false .`
3. Save logs + manifest in `build_artifacts/`.
4. For multi‑region, use distinct sources and parallel builds.

## Examples
- Single‑region AWS build
- Multi‑cloud build matrix