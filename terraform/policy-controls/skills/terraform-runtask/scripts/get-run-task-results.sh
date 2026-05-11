#!/usr/bin/env bash
# Fetch run task stages, results, and outcomes from TFC/TFE API.
#
# Usage:
#   get-run-task-results.sh <run-id-or-url>
#
# Environment:
#   TFE_TOKEN        - Required. API token with read access to the workspace.
#   TFE_HOSTNAME     - Optional. TFE/TFC hostname. Defaults to app.terraform.io
#   TFE_SKIP_VERIFY  - Optional. Set to "true" to skip TLS certificate verification.
#
# Output: JSON object with run task stages, results, outcomes, and outcome bodies.
#
# Example:
#   get-run-task-results.sh run-iURWDL3wVxzefsjo
#   get-run-task-results.sh https://app.terraform.io/app/org/workspaces/ws/runs/run-abc123

set -euo pipefail

CURL_CONNECT_TIMEOUT=10
CURL_MAX_TIME=30

# Build curl TLS options from TFE_SKIP_VERIFY
CURL_TLS_OPTS=()
if [[ "${TFE_SKIP_VERIFY:-false}" == "true" ]]; then
  CURL_TLS_OPTS+=("--insecure")
fi

# --- Validate prerequisites ---

if [[ -z "${TFE_TOKEN:-}" ]]; then
  echo "Error: TFE_TOKEN environment variable is not set." >&2
  exit 1
fi

if ! command -v curl &>/dev/null; then
  echo "Error: curl is required but not found." >&2
  exit 1
fi

if ! command -v jq &>/dev/null; then
  echo "Error: jq is required but not found." >&2
  exit 1
fi

# --- Parse input ---

INPUT="${1:-}"
if [[ -z "$INPUT" ]]; then
  echo "Usage: get-run-task-results.sh <run-id-or-url>" >&2
  exit 1
fi

# Extract run ID from URL or use directly
if [[ "$INPUT" =~ ^https?:// ]]; then
  RUN_ID=$(echo "$INPUT" | grep -oE 'run-[a-zA-Z0-9]+')
  if [[ -z "$RUN_ID" ]]; then
    echo "Error: Could not extract run ID from URL: $INPUT" >&2
    exit 1
  fi
  # Extract hostname from URL if TFE_HOSTNAME not already set
  PARSED_HOST=$(echo "$INPUT" | grep -oE '^https?://[^/]+' | sed 's|^https\?://||')
  TFE_HOSTNAME="${TFE_HOSTNAME:-$PARSED_HOST}"
else
  # Validate run ID format for direct input
  if [[ ! "$INPUT" =~ ^run-[a-zA-Z0-9]+$ ]]; then
    echo "Error: Invalid run ID format: $INPUT (expected run-<alphanumeric>)" >&2
    exit 1
  fi
  RUN_ID="$INPUT"
  TFE_HOSTNAME="${TFE_HOSTNAME:-app.terraform.io}"
fi

API_BASE="https://${TFE_HOSTNAME}/api/v2"

# --- Helper: authenticated GET returning JSON ---

api_get() {
  local endpoint="$1"
  local tmpfile
  tmpfile=$(mktemp)
  trap "rm -f '$tmpfile'" RETURN

  local http_code
  http_code=$(curl -s -o "$tmpfile" -w "%{http_code}" \
    "${CURL_TLS_OPTS[@]}" \
    --connect-timeout "$CURL_CONNECT_TIMEOUT" \
    --max-time "$CURL_MAX_TIME" \
    -H "Authorization: Bearer ${TFE_TOKEN}" \
    -H "Content-Type: application/vnd.api+json" \
    "${API_BASE}${endpoint}")

  if [[ "$http_code" -eq 401 ]]; then
    echo "Error: API returned HTTP 401 for ${endpoint} — TFE_TOKEN may be expired or invalid (run: ${RUN_ID})" >&2
    cat "$tmpfile" >&2
    return 1
  elif [[ "$http_code" -ge 400 ]]; then
    echo "Error: API returned HTTP ${http_code} for ${endpoint} (run: ${RUN_ID})" >&2
    cat "$tmpfile" >&2
    return 1
  fi

  cat "$tmpfile"
}

# Helper: fetch HTML body from outcome (follows redirects safely)
# Uses a two-step approach to avoid leaking the auth header to redirect targets.
api_get_body() {
  local endpoint="$1"
  local tmpfile
  tmpfile=$(mktemp)
  trap "rm -f '$tmpfile'" RETURN

  # Step 1: Get the redirect URL without following it
  local http_code redirect_url
  http_code=$(curl -s -o "$tmpfile" -w "%{http_code}" \
    "${CURL_TLS_OPTS[@]}" \
    --connect-timeout "$CURL_CONNECT_TIMEOUT" \
    --max-time "$CURL_MAX_TIME" \
    -H "Authorization: Bearer ${TFE_TOKEN}" \
    -H "Content-Type: application/vnd.api+json" \
    "${API_BASE}${endpoint}")

  if [[ "$http_code" -eq 302 || "$http_code" -eq 301 ]]; then
    # Step 2: Follow the redirect WITHOUT the auth header
    redirect_url=$(curl -s -o /dev/null -w "%{redirect_url}" \
      "${CURL_TLS_OPTS[@]}" \
      --connect-timeout "$CURL_CONNECT_TIMEOUT" \
      --max-time "$CURL_MAX_TIME" \
      -H "Authorization: Bearer ${TFE_TOKEN}" \
      -H "Content-Type: application/vnd.api+json" \
      "${API_BASE}${endpoint}")

    if [[ -n "$redirect_url" ]]; then
      curl -s \
        "${CURL_TLS_OPTS[@]}" \
        --connect-timeout "$CURL_CONNECT_TIMEOUT" \
        --max-time "$CURL_MAX_TIME" \
        "$redirect_url"
      return $?
    fi
  fi

  if [[ "$http_code" -ge 400 ]]; then
    echo "Warning: Body endpoint returned HTTP ${http_code} for ${endpoint}" >&2
    return 1
  fi

  cat "$tmpfile"
}

# --- Step 1: Fetch task stages with sideloaded task results ---
# Fetch all pages to handle runs with many task stages.

all_stages='{"data":[],"included":[]}'
page=1

while true; do
  page_response=$(api_get "/runs/${RUN_ID}/task-stages?include=task_results&page%5Bnumber%5D=${page}&page%5Bsize%5D=100")

  # Validate response is JSON
  if ! echo "$page_response" | jq empty 2>/dev/null; then
    echo "Error: Invalid JSON response from task-stages endpoint (run: ${RUN_ID})" >&2
    exit 1
  fi

  # Merge page data
  all_stages=$(jq -n \
    --argjson acc "$all_stages" \
    --argjson page "$page_response" \
    '{
      data: ($acc.data + ($page.data // [])),
      included: ($acc.included + ($page.included // []))
    }')

  # Check for next page
  next_page=$(echo "$page_response" | jq -r '.meta.pagination["next-page"] // empty')
  if [[ -z "$next_page" || "$next_page" == "null" ]]; then
    break
  fi
  page=$((page + 1))
done

stages_response="$all_stages"
stage_count=$(echo "$stages_response" | jq '.data | length')

if [[ "$stage_count" -eq 0 ]]; then
  jq -n \
    --arg run_id "$RUN_ID" \
    --arg hostname "$TFE_HOSTNAME" \
    '{
      run_id: $run_id,
      tfe_hostname: $hostname,
      task_stages: [],
      summary: { total_tasks: 0, passed: 0, failed: 0, errored: 0, pending: 0, unreachable: 0 }
    }'
  exit 0
fi

# --- Step 2: Extract task result IDs and fetch outcomes for each ---

task_result_ids=$(echo "$stages_response" | jq -r '
  .included[]? | select(.type == "task-results") | .id // empty
')

outcomes_json="[]"

while IFS= read -r result_id; do
  [[ -z "$result_id" ]] && continue

  # Skip if this task result has 0 outcomes
  outcomes_count=$(echo "$stages_response" | jq -r \
    --arg rid "$result_id" \
    '.included[]? | select(.type == "task-results" and .id == $rid) | .attributes["task-result-outcomes-count"] // 0')

  if [[ "$outcomes_count" -eq 0 ]]; then
    outcomes_json=$(echo "$outcomes_json" | jq \
      --arg rid "$result_id" \
      '. + [{ task_result_id: $rid, outcomes: [] }]')
    continue
  fi

  # Fetch outcomes list for this task result
  if ! outcomes_response=$(api_get "/task-results/${result_id}/outcomes" 2>&1); then
    echo "Warning: Failed to fetch outcomes for task result ${result_id}" >&2
    outcomes_response='{"data":[]}'
  fi

  # For each outcome, fetch the HTML body
  outcome_ids=$(echo "$outcomes_response" | jq -r '.data[]?.id // empty')

  while IFS= read -r outcome_id; do
    [[ -z "$outcome_id" ]] && continue

    # Write body to temp file to avoid ARG_MAX issues with large HTML
    body_tmpfile=$(mktemp)
    if api_get_body "/task-result-outcomes/${outcome_id}/body" > "$body_tmpfile" 2>/dev/null; then
      # Use --rawfile to safely handle large/special content
      outcomes_response=$(echo "$outcomes_response" | jq \
        --arg oid "$outcome_id" \
        --rawfile html "$body_tmpfile" \
        '(.data[] | select(.id == $oid)) += {"body_html": $html}')
    else
      echo "Warning: Failed to fetch body for outcome ${outcome_id}" >&2
    fi
    rm -f "$body_tmpfile"
  done <<< "$outcome_ids"

  # Add outcomes keyed by task result ID
  outcomes_json=$(echo "$outcomes_json" | jq \
    --arg rid "$result_id" \
    --argjson outcomes "$outcomes_response" \
    '. + [{ task_result_id: $rid, outcomes: $outcomes.data }]')
done <<< "$task_result_ids"

# --- Step 3: Assemble structured output ---

output=$(jq -n \
  --arg run_id "$RUN_ID" \
  --arg hostname "$TFE_HOSTNAME" \
  --argjson stages "$stages_response" \
  --argjson outcomes "$outcomes_json" \
  '
  # Index sideloaded task results by ID
  ([$stages.included[]? | select(.type == "task-results")] | INDEX(.id)) as $results_by_id |

  # Index outcomes by task result ID
  ($outcomes | INDEX(.task_result_id)) as $outcomes_by_result |

  # Stage ordering (unknown stages sort to end)
  ["pre_plan", "post_plan", "pre_apply", "post_apply"] as $stage_order |

  {
    run_id: $run_id,
    tfe_hostname: $hostname,
    task_stages: [
      $stages.data[]
      | {
          id: .id,
          stage: .attributes.stage,
          status: .attributes.status,
          is_overridable: (.attributes.actions["is-overridable"] // false),
          permissions: {
            can_override_policy: (.attributes.permissions["can-override-policy"] // false),
            can_override_tasks: (.attributes.permissions["can-override-tasks"] // false),
            can_override: (.attributes.permissions["can-override"] // false)
          },
          status_timestamps: .attributes["status-timestamps"],
          created_at: .attributes["created-at"],
          updated_at: .attributes["updated-at"],
          task_results: [
            .relationships["task-results"].data[]?
            | .id as $rid
            | $results_by_id[$rid]
            | select(. != null)
            | {
                id: .id,
                task_name: .attributes["task-name"],
                status: .attributes.status,
                message: .attributes.message,
                url: .attributes.url,
                task_url: .attributes["task-url"],
                enforcement_level: .attributes["workspace-task-enforcement-level"],
                stage: .attributes.stage,
                is_speculative: .attributes["is-speculative"],
                task_id: .attributes["task-id"],
                workspace_task_id: .attributes["workspace-task-id"],
                outcomes_count: (.attributes["task-result-outcomes-count"] // 0),
                status_timestamps: .attributes["status-timestamps"],
                created_at: .attributes["created-at"],
                updated_at: .attributes["updated-at"],
                outcomes: (
                  ($outcomes_by_result[$rid].outcomes // [])
                  | map({
                      id: .id,
                      outcome_id: .attributes["outcome-id"],
                      description: .attributes.description,
                      tags: .attributes.tags,
                      url: .attributes.url,
                      body_html: (.body_html // null),
                      created_at: .attributes["created-at"]
                    })
                )
              }
          ]
        }
    ]
    | sort_by(
        .stage as $s |
        ($stage_order | to_entries | map(select(.value == $s)) | .[0].key) // 999
      ),
    summary: {
      total_tasks: ([$stages.included[]? | select(.type == "task-results")] | length),
      passed: ([$stages.included[]? | select(.type == "task-results") | select(.attributes.status == "passed")] | length),
      failed: ([$stages.included[]? | select(.type == "task-results") | select(.attributes.status == "failed")] | length),
      errored: ([$stages.included[]? | select(.type == "task-results") | select(.attributes.status == "errored")] | length),
      pending: ([$stages.included[]? | select(.type == "task-results") | select(.attributes.status == "pending")] | length),
      unreachable: ([$stages.included[]? | select(.type == "task-results") | select(.attributes.status == "unreachable")] | length)
    }
  }
')

echo "$output"
