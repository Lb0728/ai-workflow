#!/usr/bin/env bash
set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WORKFLOW_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
RUNNER="${SCRIPT_DIR}/ai_agent.sh"
PROJECT_ROOT="${1:-}"
TASK_INPUT="${2:-}"
failures=0

if [ -z "$PROJECT_ROOT" ]; then
  printf '%s\n' "Usage: ./tool/test_ai_router_loader.sh <project-root> [task-file]"
  exit 2
fi

assert_contains() {
  local name="$1"
  local output="$2"
  local expected="$3"
  if printf '%s\n' "$output" | grep -F -- "$expected" >/dev/null; then
    printf 'PASS %s\n' "$name"
  else
    printf 'FAIL %s: missing %s\n' "$name" "$expected"
    failures=$((failures + 1))
  fi
}

router_output="$(
  "$RUNNER" \
    --project-root "$PROJECT_ROOT" \
    --adapter demo-project \
    --role developer \
    router \
    "$TASK_INPUT"
)"

assert_contains "Core Router assembled" "$router_output" "你是通用研发工作流的 Router Agent。"
assert_contains "Core defaults resolved" "$router_output" "core.defaults="
assert_contains "project profile resolved" "$router_output" "adapter.profile="
assert_contains "project risk rules resolved" "$router_output" "adapter.risk_rules="
assert_contains "minimal Router context assembled" "$router_output" "===== adapter.context.router ====="
assert_contains "minimal project owner facts assembled" "$router_output" "Demo Project Router Context"
assert_contains "minimal project regression index assembled" "$router_output" "adapter.context.regression_surfaces"
assert_contains "role profile resolved" "$router_output" "role.profile="
assert_contains "runtime task assembled" "$router_output" "===== TASK ====="

legacy_output="$(
  cd "$PROJECT_ROOT"
  "$RUNNER" router "$TASK_INPUT"
)"
assert_contains "legacy positional invocation" "$legacy_output" "adapter.profile="

full_output="$(
  "$RUNNER" \
    --project-root "$PROJECT_ROOT" \
    --adapter demo-project \
    --role developer \
    --context-mode full \
    router \
    "$TASK_INPUT"
)"
assert_contains "full Core defaults assembled" "$full_output" "===== core.defaults ====="
assert_contains "full project profile assembled" "$full_output" "===== adapter.profile ====="
assert_contains "full project risk rules assembled" "$full_output" "===== adapter.risk_rules ====="
assert_contains "full role profile assembled" "$full_output" "===== role.profile ====="
assert_contains "full commit conventions assembled" "$full_output" "===== adapter.commit ====="
assert_contains "full extension slots assembled" "$full_output" "===== core.extension_slots ====="

requirement_output="$("$RUNNER" --project-root "$PROJECT_ROOT" requirement "$TASK_INPUT")"
assert_contains "Requirement Core Agent assembled" "$requirement_output" "你是当前项目的 Requirement Breakdown Agent。"
assert_contains "Requirement project reality assembled" "$requirement_output" "===== adapter.context.current_project_reality ====="

bugfix_output="$("$RUNNER" --project-root "$PROJECT_ROOT" bugfix "$TASK_INPUT")"
assert_contains "Bugfix Core Agent assembled" "$bugfix_output" "你是当前项目的 Bugfix Agent。"
assert_contains "Bugfix risk rules assembled" "$bugfix_output" "===== adapter.risk_rules ====="

architecture_output="$("$RUNNER" --project-root "$PROJECT_ROOT" architecture "$TASK_INPUT")"
assert_contains "Architecture Core Agent assembled" "$architecture_output" "你是当前项目的 Architecture Boundary Agent。"
assert_contains "Architecture sources assembled" "$architecture_output" "===== adapter.context.architecture_sources ====="

coding_output="$("$RUNNER" --project-root "$PROJECT_ROOT" coding "$TASK_INPUT")"
assert_contains "Coding Core Agent assembled" "$coding_output" "你是当前项目的 Coding Agent。"
assert_contains "Coding commands assembled" "$coding_output" "===== adapter.commands ====="

selftest_output="$("$RUNNER" --project-root "$PROJECT_ROOT" selftest "$TASK_INPUT")"
assert_contains "Self Test Core Agent assembled" "$selftest_output" "你是当前项目的 Self Test Agent。"
assert_contains "Self Test Gates assembled" "$selftest_output" "===== adapter.gates ====="

review_output="$("$RUNNER" --project-root "$PROJECT_ROOT" review "$TASK_INPUT")"
assert_contains "PR Review Core Agent assembled" "$review_output" "你是当前项目的 PR Review Agent。"
assert_contains "PR Review regression surfaces assembled" "$review_output" "===== adapter.context.regression_surfaces ====="

i18n_output="$("$RUNNER" --project-root "$PROJECT_ROOT" i18n "$TASK_INPUT")"
assert_contains "i18n Core Agent assembled" "$i18n_output" "你是当前项目的 i18n & Text UI Risk Agent。"
assert_contains "i18n config assembled" "$i18n_output" "===== adapter.i18n ====="

commit_output="$("$RUNNER" --project-root "$PROJECT_ROOT" commit "$TASK_INPUT")"
assert_contains "Commit Core Agent assembled" "$commit_output" "你是当前项目的 Commit Agent。"
assert_contains "Commit conventions assembled" "$commit_output" "===== adapter.commit ====="

if grep -R -n -E '/Users/[A-Za-z0-9._-]+|/Volumes/[A-Za-z0-9._-]+' "${WORKFLOW_ROOT}/core" >/dev/null; then
  printf '%s\n' "FAIL Core contains project-bound terms"
  failures=$((failures + 1))
else
  printf '%s\n' "PASS Core project-term scan"
fi

for agent_file in 00_router_agent.md 01_requirement_breakdown_agent.md 02_bugfix_agent.md 03_architecture_boundary_agent.md 04_coding_agent.md 05_self_test_agent.md 06_pr_review_agent.md 07_i18n_text_ui_risk_agent.md 08_commit_agent.md; do
  if [ "$(readlink "${WORKFLOW_ROOT}/agents/${agent_file}" 2>/dev/null)" = "../core/agents/${agent_file}" ]; then
    printf 'PASS legacy Agent entry %s\n' "$agent_file"
  else
    printf 'FAIL legacy Agent entry %s\n' "$agent_file"
    failures=$((failures + 1))
  fi
done

set +e
missing_adapter_output="$(
  "$RUNNER" \
    --project-root "$PROJECT_ROOT" \
    --adapter __missing_adapter__ \
    --role developer \
    router \
    "$TASK_INPUT" 2>&1
)"
missing_adapter_status=$?
set -e
if [ "$missing_adapter_status" -ne 0 ]; then
  printf '%s\n' "PASS missing Adapter is rejected"
else
  printf '%s\n' "FAIL missing Adapter should be rejected"
  failures=$((failures + 1))
fi
assert_contains "missing Adapter error is explicit" "$missing_adapter_output" "required loader input missing"

if [ "$failures" -gt 0 ]; then
  printf 'FAILED: %d assertion(s)\n' "$failures"
  exit 1
fi

printf '%s\n' "ALL PASS: config-driven Agent assembly"
