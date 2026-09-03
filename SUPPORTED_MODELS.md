# Supported Models

Effective date: 2026-08-31.

Approving authority: `@hashicorp/team-agent-skills-ecosystem`.

| Model Provider | Model family | Support status | Model ID | Effective date | Approving authority |
| --- | --- | --- | --- | --- | --- |
| Anthropic | Claude Opus | Latest | `anthropic.claude-opus-5` | 2026-08-31 | `@hashicorp/team-agent-skills-ecosystem` |
| Anthropic | Claude Opus | N-1 | `anthropic.claude-opus-4-8` | 2026-08-31 | `@hashicorp/team-agent-skills-ecosystem` |
| Anthropic | Claude Sonnet | Latest | `anthropic.claude-sonnet-5` | 2026-08-31 | `@hashicorp/team-agent-skills-ecosystem` |
| OpenAI | GPT | Latest | `openai.gpt-5.6-sol` | 2026-08-31 | `@hashicorp/team-agent-skills-ecosystem` |
| OpenAI | GPT | N-1 | `openai.gpt-5.5` | 2026-08-31 | `@hashicorp/team-agent-skills-ecosystem` |

The normal support operating model includes `Latest` and `N-1` for each
model family. A temporary Claude Sonnet Inference Availability Exception is
active for the Claude Sonnet N-1 model version.

Supported means maintainers intentionally design, evaluate, and maintain Skills
against the listed baseline. It does not promise identical behavior across
models or harnesses. A model outside this matrix is unsupported or unevaluated,
not necessarily incompatible. Training-data cutoff metadata is not required for
supported status.
