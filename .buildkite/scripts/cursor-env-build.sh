#!/usr/bin/env bash
# Launch a one-shot Cloud Agent that requests a draft environment Build of BUILDKITE_COMMIT.
set -euo pipefail

readonly API_BASE="https://api.cursor.com/v1"
readonly REPO_URL="https://github.com/connorfuhrman/nixconfig"
readonly PROMPT_FILE=".buildkite/prompts/cursor-env-build.md"
readonly POLL_INTERVAL_SEC=30
readonly TIMEOUT_SEC=$((90 * 60))
# Exit 2 = environment Build failed (do not retry). Exit 1 = infra/API (retryable).
readonly EXIT_BUILD_FAILED=2
readonly EXIT_INFRA=1

cursor_token="${CURSOR_AUTOMATION_WEBHOOK_TOKEN:-${CURSOR_API_KEY:-}}"
if [[ -z "$cursor_token" ]]; then
  echo "cursor-env-build: CURSOR_AUTOMATION_WEBHOOK_TOKEN (or CURSOR_API_KEY) is not set (Buildkite cluster secret)" >&2
  exit "$EXIT_INFRA"
fi

if [[ -z "${BUILDKITE_COMMIT:-}" ]]; then
  echo "cursor-env-build: BUILDKITE_COMMIT is not set" >&2
  exit "$EXIT_INFRA"
fi

if [[ ! -f "$PROMPT_FILE" ]]; then
  echo "cursor-env-build: missing prompt file ${PROMPT_FILE}" >&2
  exit "$EXIT_INFRA"
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "cursor-env-build: jq is required" >&2
  exit "$EXIT_INFRA"
fi

prompt_text="$(sed "s/{{COMMIT_SHA}}/${BUILDKITE_COMMIT}/g" "$PROMPT_FILE")"

# Always pin the agent to BUILDKITE_COMMIT. prUrl resolution fails for some
# PR/build combinations (e.g. after rebase); the SHA is the authoritative ref.
repo_entry="$(jq -n \
  --arg url "$REPO_URL" \
  --arg ref "$BUILDKITE_COMMIT" \
  '{url: $url, startingRef: $ref}')"

payload="$(jq -n \
  --arg text "$prompt_text" \
  --argjson repo "$repo_entry" \
  '{
    prompt: {text: $text},
    repos: [$repo],
    workOnCurrentBranch: true,
    autoCreatePR: false,
    name: "CI: cursor environment Build"
  }')"

create_response="$(mktemp)"
trap 'rm -f "$create_response"' EXIT

http_code="$(curl -sS -w "%{http_code}" -o "$create_response" \
  -u "${cursor_token}:" \
  -H "Content-Type: application/json" \
  -X POST "${API_BASE}/agents" \
  -d "$payload")"

if [[ "$http_code" -lt 200 || "$http_code" -ge 300 ]]; then
  echo "cursor-env-build: POST /v1/agents failed (HTTP ${http_code})" >&2
  cat "$create_response" >&2 || true
  exit "$EXIT_INFRA"
fi

agent_id="$(jq -r '.agent.id // empty' "$create_response")"
run_id="$(jq -r '.run.id // empty' "$create_response")"
agent_url="$(jq -r '.agent.url // empty' "$create_response")"

if [[ -z "$agent_id" || -z "$run_id" ]]; then
  echo "cursor-env-build: create-agent response missing agent.id or run.id" >&2
  cat "$create_response" >&2
  exit "$EXIT_INFRA"
fi

echo "cursor-env-build: agent ${agent_id} run ${run_id}"
echo "cursor-env-build: ${agent_url}"

annotate() {
  local style="$1"
  local body="$2"
  if command -v buildkite-agent >/dev/null 2>&1; then
    buildkite-agent annotate --style "$style" --context cursor-env-build "$body" || true
  fi
}

deadline=$((SECONDS + TIMEOUT_SEC))
terminal_status=""
result_text=""

while (( SECONDS < deadline )); do
  run_response="$(curl -sS -u "${cursor_token}:" \
    "${API_BASE}/agents/${agent_id}/runs/${run_id}")"

  terminal_status="$(jq -r '.status // empty' <<<"$run_response")"
  result_text="$(jq -r '.result // empty' <<<"$run_response")"

  case "$terminal_status" in
    FINISHED|ERROR|CANCELLED|EXPIRED)
      break
      ;;
    *)
      sleep "$POLL_INTERVAL_SEC"
      ;;
  esac
done

if [[ "$terminal_status" != "FINISHED" && "$terminal_status" != "ERROR" &&
      "$terminal_status" != "CANCELLED" && "$terminal_status" != "EXPIRED" ]]; then
  annotate error "### Cursor environment Build — timeout

Agent: ${agent_url}
Run: \`${run_id}\`
Poll timed out after ${TIMEOUT_SEC}s."
  echo "cursor-env-build: poll timeout waiting for run ${run_id}" >&2
  exit "$EXIT_INFRA"
fi

if [[ "$terminal_status" != "FINISHED" ]]; then
  annotate error "### Cursor environment Build — agent run ${terminal_status}

Agent: ${agent_url}
Run: \`${run_id}\`"
  echo "cursor-env-build: run ended with status ${terminal_status}" >&2
  echo "$result_text" >&2
  exit "$EXIT_INFRA"
fi

if grep -q 'CURSOR_ENV_BUILD=SUCCEEDED' <<<"$result_text"; then
  annotate success "### Cursor environment Build — SUCCEEDED

Agent: ${agent_url}
Commit: \`${BUILDKITE_COMMIT}\`

${result_text}"
  echo "cursor-env-build: CURSOR_ENV_BUILD=SUCCEEDED"
  exit 0
fi

annotate error "### Cursor environment Build — FAILED

Agent: ${agent_url}
Commit: \`${BUILDKITE_COMMIT}\`

${result_text}"
echo "cursor-env-build: missing CURSOR_ENV_BUILD=SUCCEEDED in agent result" >&2
echo "$result_text" >&2
exit "$EXIT_BUILD_FAILED"
