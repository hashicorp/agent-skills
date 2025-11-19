# Skill: HCP Packer Registry Operations

## Overview
Publish, version, and promote images using HCP Packer.

## Capability Statement
- Add `hcp_packer_registry { bucket_name = "<org>/<bucket>" }`
- Publish build results
- Create channels (`dev`, `staging`, `prod`) and promote versions

## Prerequisites
HCP org/project access; client credentials

## Execution Steps
1. Configure `hcp_packer_registry` in template.
2. Build and verify version appears in HCP.
3. Promote version to channel via API/CLI (no hardcoded secrets).
4. Emit changelog and provenance.

## Examples
- Initial publish + promotion with approval gate
