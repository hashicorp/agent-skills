# Changelog

All notable changes to the Agent Instructions Library.

## 2025-12-01

### Changed
- Folder structure refinement across all products:
  - **Terraform**: Removed `workflows/` folder. Directory now contains `provider-development/`, `provider-feature-development/`, and `terraform-code-generation/`
  - **Vault**: Simplified to single use-case folder `generate-policy/` with SKILL.md and resources
  - **Packer**: Simplified to single use-case folder `creating-images/`
  - **Consul**: Simplified to single use-case folder `service-mesh/`
  - **Vault Radar**: Renamed `secrets-detection/` to `secret-scanning/` for consistency
- Updated all product README files to reflect actual folder structure and remove references to non-existent nested config folders (`.vscode/`, `.kiro/`, `.aws/` in use-cases)
- Corrected all path references in documentation, examples, and prompts throughout each product README
- Updated root README with correct paths for all Quick Start examples
- Removed example references to non-existent skills and workflows (e.g., `read-secret-securely`, `new-kv-engine-setup`)

## 2025-11-30

### Changed
- Major repository restructuring:
  - All product folders (terraform, vault, packer, consul, vault-radar) now use the pattern:
    `product/` → `use-case/` → `.vscode/`, `.kiro/`, `.aws/`, `skills/`, `README.md`
  - Workflows have been moved from `workflows/` folders into use-case-named folders under each product
  - Removed all prompts folders and references from documentation and READMEs
  - Updated all product and root README files to reflect new structure and usage
  - Added Packer README and clarified use-case-first approach for all products

## 2025-11-11

### Fixed
- **Platform Compatibility Matrix**: Corrected platform listings with accurate, currently available tools
  - Removed: OpenAI Codex (deprecated March 2023), Google Jules (internal only), duplicate VS Code Copilot
  - Added: Aider, Continue (open-source alternatives with actual custom instruction support)
  - Clarified: JetBrains AI is GitHub Copilot integration, not separate platform
- **Critical Correction**: SKILL.md format is **Claude Desktop exclusive**
  - Only Claude natively supports Anthropic's SKILL.md format with progressive disclosure
  - Other platforms (GitHub Copilot, Cursor, Aider, etc.) can reference SKILL.md content manually but don't auto-load it
  - Updated documentation to clarify this distinction and prevent user confusion
- Updated platform decision tree to reflect real-world AI coding assistant landscape
- Removed references to discontinued/unavailable platforms (Codex, Jules, Gemini CLI)
- Added comprehensive notes explaining platform capabilities and SKILL.md compatibility

## 2025-11-10

### Added
- **Amazon Kiro support**: Added `.kiro/` directory structure with hooks, specs, and steering files
- **Amazon Q CLI support**: Added `.aws/amazonq/` agent configuration for Terraform
- Comprehensive platform integration guide in README.md
- Visual diagrams for GitHub Copilot, Claude, Cursor, Kiro, Q CLI, and universal setup
- USAGE_GUIDE.md with detailed platform-specific instructions for all 6 platforms
- VISUAL_GUIDE.md with extensive flowcharts and diagrams
- Platform decision tree and comparison matrix including new Amazon tools

### Changed
- Updated platform comparison matrix to include Amazon Kiro and Amazon Q CLI
- Expanded README.md to document hook-based (Kiro) and agent-based (Q CLI) workflows
- Streamlined README.md from ~600 to ~360 lines (40% reduction)
- Reorganized content to focus on platform-specific usage
- Enhanced visual diagrams throughout documentation
- Removed "production-ready" marketing claims across all documentation

## 2025-11-07

### Added
- Initial repository structure
- GitHub Copilot instructions (`.github/copilot-instructions.md`)
- Terraform skills: generate-hcl, refactor-module
- Terraform workflows: plan-and-apply-with-approval, security-scan
- Vault skills: generate-policy, read-secret-securely
- Vault Radar skills: scan-for-secrets, integrate-mcp-server
- Consul skills: configure-service-mesh
- System prompts for Terraform and Vault
- Product-specific README files

### Documentation
- Established SKILL.md format following Anthropic's Agent Skills pattern
- Created workflow templates with ASCII diagrams
- Added prompt templates for common tasks
