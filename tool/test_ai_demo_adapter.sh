#!/usr/bin/env bash
set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WORKFLOW_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
PROJECT_ROOT="${WORKFLOW_ROOT}/examples/demo-project"
TASKS_DIR="$(mktemp -d)"
trap 'rm -rf "$TASKS_DIR"' EXIT
failures=0

assert_contains() {
  local name="$1"
  local output="$2"
  local expected="$3"
  if printf '%s\n' "$output" | grep -F -q -- "$expected"; then
    printf 'PASS %s\n' "$name"
  else
    printf 'FAIL %s: missing %s\n' "$name" "$expected"
    failures=$((failures + 1))
  fi
}

assert_not_contains() {
  local name="$1"
  local output="$2"
  local unexpected="$3"
  if printf '%s\n' "$output" | grep -F -q -- "$unexpected"; then
    printf 'FAIL %s: found %s\n' "$name" "$unexpected"
    failures=$((failures + 1))
  else
    printf 'PASS %s\n' "$name"
  fi
}

static_output="$(bash "${PROJECT_ROOT}/scripts/static_check.sh")"
assert_contains "Demo static check" "$static_output" "RESULT PASS errors=0"

loader_output="$("${SCRIPT_DIR}/ai_core_loader.sh" --project-root "$PROJECT_ROOT" describe)"
assert_contains "Demo Adapter auto-detected" "$loader_output" "adapter=demo-project"
assert_contains "Developer Role selected" "$loader_output" "role=developer"

AI_PROJECT_ROOT="$PROJECT_ROOT" \
AI_RUNTIME_TASKS_DIR="$TASKS_DIR" \
  "${SCRIPT_DIR}/ai_loop_new.sh" docs DEMO-1 portability P2 light_feature </dev/null >/dev/null

TASK_FILE="$(find "$TASKS_DIR" -maxdepth 1 -type f -name '*.md' -print | head -n 1)"
if [ -f "$TASK_FILE" ]; then
  printf '%s\n' "PASS L1 task created"
else
  printf '%s\n' "FAIL L1 task was not created"
  failures=$((failures + 1))
fi

task_content="$(sed -n '1,80p' "$TASK_FILE")"
assert_contains "Demo task type" "$task_content" "type: docs"
assert_contains "L1 delivery level" "$task_content" "delivery_level: light_feature"

router_output="$(
  AI_PROJECT_ROOT="$PROJECT_ROOT" \
    "${SCRIPT_DIR}/ai_agent.sh" router "$TASK_FILE"
)"
assert_contains "Router uses Demo Adapter" "$router_output" "- adapter: demo-project"
assert_contains "Router receives Demo context" "$router_output" "Demo Project Router Context"

next_output="$(
  AI_PROJECT_ROOT="$PROJECT_ROOT" \
  AI_RUNTIME_TASKS_DIR="$TASKS_DIR" \
    "${SCRIPT_DIR}/ai_loop_next.sh" "$TASK_FILE"
)"
assert_contains "Router gives legal next list" "$next_output" "## 合法下一步"
assert_contains "L1 analyze is legal" "$next_output" "- analyze"
assert_contains "Demo task uses Core workflow" "$next_output" "core/workflows/tech_debt_workflow.md"

if grep -R -n -E 'Flutter|(^|[^A-Za-z])BLE([^A-Za-z]|$)|(^|[^A-Za-z])MQTT([^A-Za-z]|$)' \
  "${WORKFLOW_ROOT}/adapters/demo-project" \
  "$PROJECT_ROOT" >/dev/null; then
  printf '%s\n' "FAIL Demo assets contain selected-project technology terms"
  failures=$((failures + 1))
else
  printf '%s\n' "PASS Demo assets are independent of selected-project technology"
fi

if "${SCRIPT_DIR}/ai_distribution_check.sh" --adapter demo-project --role developer >/dev/null; then
  printf '%s\n' "PASS Demo distribution boundary"
else
  printf '%s\n' "FAIL Demo distribution boundary"
  failures=$((failures + 1))
fi

if [ "$failures" -gt 0 ]; then
  printf 'FAILED: %d assertion(s)\n' "$failures"
  exit 1
fi

printf '%s\n' "ALL PASS: Demo Project Adapter portability"
