# Security model for the Terraform configuration upload Skill

The Skill keeps the upload boundary in a client-local Bash helper. The caller
selectively stages and reviews a private configuration directory, the helper
validates and reports its included relative file list, and upload mode performs the HCP
Terraform API interaction without exposing credentials or signed URLs.

## Boundaries

| Concern | Owner |
| --- | --- |
| Selectively create the private staging directory and review included files | Caller / agent workflow |
| Approve the file list, target, and upload operation | Caller / agent workflow |
| Reject unsafe file types and known sensitive leftovers | Bash helper |
| Revalidate files and verify archive members | Bash helper |
| Create the private temporary archive | Bash helper |
| HCP Terraform workspace lookup and configuration-version upload | Bash helper; explicit upload mode only |
| Credential handling | Protected `TFE_TOKEN` environment; never a positional argument |
| Configuration-version handoff | Sanitized ID only after upload reaches `uploaded` |
| Run, Plan, Apply, logs, and state behavior | Out of scope |

The helper returns bounded JSON facts only. It does not print file contents,
the full manifest, credentials, raw API responses, or upload URLs. It creates a
speculative configuration version with automatic Run queueing disabled and
never creates a Run or reads a Plan.
