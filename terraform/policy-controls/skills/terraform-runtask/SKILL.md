---
name: terraform-runtask
description: Retrieve and display HCP Terraform Enterprise run task results for a given run. Use this skill whenever the user asks about run task results, run task checks, task stage statuses, or wants to inspect what run tasks reported for a Terraform Cloud/Enterprise run. Triggers on phrases like "check the run tasks", "what did the run tasks say", "show run task results", "get task results for run-xxx", or any reference to run task outcomes on a specific run.
---

# HCP Terraform Run Task Reader

The MCP terraform tools can fetch run details but lack endpoints for task stages, task results, and task result outcomes. This skill bridges that gap with a script that calls the HCP Terraform/TFE REST API directly, returning structured JSON with three layers of detail: **stages → task results → outcomes**.

## Workflow

### Step 1: Identify the run

The user may provide either:

- A **run ID** like `run-iURWDL3wVxzefsjo`
- A **URL** like `https://app.terraform.io/app/org/workspaces/ws-name/runs/run-abc123`

Pass either form directly to the script — it handles both.

### Step 2: Fetch run task data

Run the script from its skill directory:

```bash
scripts/get-run-task-results.sh <run-id-or-url>
```

The script requires:

- `$TFE_TOKEN` — API token with read access to the workspace
- `$TFE_HOSTNAME` — (optional) hostname, defaults to `app.terraform.io`; auto-detected from URL input
- `$TFE_SKIP_VERIFY` — (optional) set to `true` to skip TLS verification (self-signed certs on TFE)
- `curl` and `jq` on PATH

The script uses `include=task_results` sideloading for efficiency (one API call for stages + results), then fetches outcomes and their HTML bodies per task result. It returns a single JSON object.

Parse the JSON output directly — do not save it to disk. Present the results inline.

### Step 3: Present structured results

Parse the JSON and present a markdown summary. The presentation has three tiers that mirror the data hierarchy:

**Tier 1 — Summary line** with aggregate counts from `summary`. Always include these counts in the user-facing response (not just in the raw JSON), even when all counts are zero:

```
**Total tasks**: 1 | Passed: 0 | Failed: 1 | Errored: 0
```

**Tier 2 — Stage sections** grouped by execution phase, each showing its task results table:

```
### Post-Plan Tasks (stage status: passed)

| Task Name | Status | Enforcement | Message | Link |
|-----------|--------|-------------|---------|------|
| Apptio-Cloudability | failed | advisory | Total Cost before: 31.54, after: 31.64, diff: +0.10 | [Results](url) |
```

**Tier 3 — Outcome sub-tables** under each task result that has outcomes:

```
#### Apptio-Cloudability — Outcomes

| Outcome | Description | Status | Severity |
|---------|-------------|--------|----------|
| Estimation | Cost Estimation Result | Passed | — |
| Policy | Policy Evaluation Result | Failed | Gated |
| Recommendation | Recommendation Result | Passed | — |
```

If an outcome has `body_html` content, render it in a collapsible block:

```
<details>
<summary>Policy Evaluation Detail</summary>

[HTML body content — failing resources, tag violations, etc.]

</details>
```

**Tier 4 — Actionable insights** after presenting the tables, synthesize the most important findings from the outcome bodies. The `body_html` content often contains the richest detail — specific failing resources, tag violations, cost savings recommendations, or compliance issues. Summarize these findings in plain language so the user doesn't have to parse raw HTML. For example:

> **Key findings:**
>
> - **Policy**: 23 resources failing — 22 missing `cost-center` tag (advisory), 1 EC2 instance using `t3.small` instead of required `t2.small` (gated)
> - **Cost**: Monthly impact +$0.10 USD, driven by a new CloudWatch metric alarm
> - **Recommendation**: Switch EC2 from `t3.small` to `t4g.small` for ~20% cost savings

This synthesis is what makes the skill output more valuable than just showing raw tables — it highlights what the user needs to act on.

### Handling edge cases

There are three distinct "empty" scenarios — distinguish between them clearly. In all cases, still show the Tier 1 summary line with explicit counts — this gives users a quick, scannable answer even when the counts are all zero:

1. **No task stages at all** (`task_stages` array is empty, `total_tasks` is 0): The workspace has no run tasks configured. Show: `**Total tasks**: 0 | Passed: 0 | Failed: 0 | Errored: 0` followed by "This run has no run tasks configured."

2. **Task stages exist but contain zero task results** (`task_stages` is non-empty but each stage's `task_results` array is empty, `total_tasks` is 0): The run task infrastructure exists but produced no individual results. Show: `**Total tasks**: 0 | Passed: 0 | Failed: 0 | Errored: 0` followed by "This run has task stages but no task results were produced. The stages are: [list stage names and statuses]."

3. **Task results exist but have zero outcomes** (`outcomes_count` is 0 for a task result): The task reported a status and message but no detailed breakdown. Show the task result row normally; skip the outcomes sub-table for that task.

This distinction matters because users asking "are there run tasks?" need to know whether tasks are configured (case 1 vs 2) and whether they produced detail (case 3).

### Reading the JSON output

**Task stage fields** (`task_stages[]`):

- `stage` — `pre_plan`, `post_plan`, `pre_apply`, `post_apply`
- `status` — stage-level status (can pass even when advisory tasks fail)
- `is_overridable`, `permissions` — override capability

**Task result fields** (`task_stages[].task_results[]`):

- `task_name` — Name of the run task
- `status` — `pending`, `running`, `passed`, `failed`, `errored`, `unreachable`
- `enforcement_level` — `advisory` (warning only) or `mandatory` (blocks run)
- `message` — Status message from the external service
- `url` — Link to external service results (if present). Include this in the Tier 2 table as a clickable link so users can jump to the full report in the external tool.
- `outcomes_count` — Number of outcome categories

**Outcome fields** (`task_stages[].task_results[].outcomes[]`):

- `outcome_id` — Category name. These vary by vendor — don't assume specific names like "Estimation" or "Policy". Present whatever categories the task returns.
- `description` — Human-readable description
- `tags` — Status/severity via `tags[].label == "Status"` → `tags[].value[0].label` and `tags[].label == "Severity"` → `tags[].value[0].label`
- `body_html` — Full HTML detail (may be null). When present, always extract and summarize key findings for the Tier 4 actionable insights.

The `summary` object has: `total_tasks`, `passed`, `failed`, `errored`, `pending`, `unreachable`.

Stage ordering (show in execution order): `pre_plan` → `post_plan` → `pre_apply` → `post_apply`. The script already sorts stages in this order.

### Highlighting problems

- If a task result has `status: errored` or `unreachable`, highlight it prominently — the external service failed to respond, not just a policy failure.
- If `enforcement_level` is `mandatory` and the task `failed`, note that this blocks the run from proceeding.
- If the stage `is_overridable`, mention that the stage can be manually overridden.

### Enriching with MCP run context

After fetching task results, also call `mcp__terraform__get_run_details` with the run ID to get complementary metadata: run status, trigger source, Terraform version, timestamps, and plan/apply state. This context helps the user understand where the run is in its lifecycle and why task results look the way they do. For example, knowing a run was triggered via CLI with auto-apply explains why it proceeded despite advisory failures.

Include relevant run metadata in your response — especially run status, trigger source, and whether the run has been applied.

## Error handling

- **Missing `$TFE_TOKEN`**: Script exits with a clear error. Suggest the user set the token.
- **HTTP 401/403**: Token lacks permissions or is expired. The error message includes the run ID.
- **HTTP 404**: Invalid run ID. The error message includes the run ID for debugging.
- **Script exits non-zero**: Surface the stderr output to the user — do not silently swallow errors or fabricate results.
