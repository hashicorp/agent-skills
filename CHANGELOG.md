# Changelog

All notable changes to the Agent Instructions Library.

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
