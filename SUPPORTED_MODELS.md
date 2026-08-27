# Supported Models

Effective date: 2026-08-25.

Approving authority: `@hashicorp/team-agent-skills-ecosystem`.

| Model Provider | Model family | Support status | Model name | Effective date | Approving authority |
| --- | --- | --- | --- | --- | --- |
| OpenAI | GPT | Latest | OpenAI GPT-5.6 Sol | 2026-08-25 | `@hashicorp/team-agent-skills-ecosystem` |

The normal support operating model includes `Latest` and `N-1`. A temporary
Inference Availability Exception is active because AWS Bedrock does not expose
GPT-5.5, so the current matrix intentionally has no `N-1` row. GPT-5.6 Terra is
a sibling variant, not an `N-1` release, and no additional-current-variant
support category is defined. When a newer approved OpenAI GPT release and
GPT-5.6 Sol are both available through Bedrock, the newer release becomes
`Latest` and GPT-5.6 Sol becomes `N-1`.

Supported means maintainers intentionally design, evaluate, and maintain Skills
against the listed baseline. It does not promise identical behavior across
models or harnesses. A model outside this matrix is unsupported or unevaluated,
not necessarily incompatible. Training-data cutoff metadata is not required for
supported status.

OpenAI is the Model Provider. Private Evaluation inference uses AWS Bedrock as
the Inference Provider; that execution path does not change model-provider
identity or add other Bedrock-hosted models to the support contract.
