#!/usr/bin/env bash
set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WORKFLOW_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
LOADER="${SCRIPT_DIR}/ai_core_loader.sh"
PROJECT_ROOT=""
ADAPTER_ID="${AI_ADAPTER_ID:-}"
ROLE_ID="${AI_ROLE_ID:-}"
failures=0

usage() {
  printf '%s\n' "Usage: ./tool/ai_core_compat_check.sh --project-root <path> [--adapter <id>] [--role <id>]"
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --project-root)
      if [ "$#" -lt 2 ]; then
        printf '%s\n' "ERROR --project-root value is required"
        exit 2
      fi
      PROJECT_ROOT="${2:-}"
      shift 2
      ;;
    --adapter)
      ADAPTER_ID="${2:-}"
      shift 2
      ;;
    --role)
      ROLE_ID="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      printf 'ERROR unknown argument: %s\n' "$1"
      usage
      exit 2
      ;;
  esac
done

source "${SCRIPT_DIR}/ai_profile_select.sh"

pass() {
  printf 'PASS %s\n' "$1"
}

fail() {
  printf 'ERROR %s\n' "$1"
  failures=$((failures + 1))
}

check_file() {
  if [ -f "$1" ]; then
    pass "$2"
  else
    fail "$2 missing: $1"
  fi
}

check_dir() {
  if [ -d "$1" ]; then
    pass "$2"
  else
    fail "$2 missing: $1"
  fi
}

check_link() {
  local path="$1"
  local expected="$2"
  local label="$3"
  local actual=""
  if [ -L "$path" ]; then
    actual="$(readlink "$path")"
  fi
  if [ "$actual" = "$expected" ]; then
    pass "$label"
  else
    fail "$label expected=${expected} actual=${actual:-not-a-symlink}"
  fi
}

check_resolve() {
  local key="$1"
  local expected="$2"
  local actual=""
  actual="$("$LOADER" --project-root "$PROJECT_ROOT" --adapter "$ADAPTER_ID" --role "$ROLE_ID" resolve "$key" 2>/dev/null)" || true
  if [ "$actual" = "$expected" ]; then
    pass "loader resolves ${key}"
  else
    fail "loader resolve ${key} expected=${expected} actual=${actual:-empty}"
  fi
}

if [ -z "$PROJECT_ROOT" ]; then
  printf '%s\n' "ERROR --project-root is required"
  exit 2
elif [ ! -d "$PROJECT_ROOT" ]; then
  printf 'ERROR project root not found: %s\n' "$PROJECT_ROOT"
  exit 1
fi

PROJECT_ROOT="$(cd "$PROJECT_ROOT" && pwd)"
ADAPTER_ID="$(ai_select_project_adapter_id "${WORKFLOW_ROOT}/adapters" "$ADAPTER_ID" "$PROJECT_ROOT")" || exit $?
ROLE_ID="$(ai_select_profile_id "${WORKFLOW_ROOT}/roles" "$ROLE_ID" "Role Adapter")" || exit $?
ADAPTER_ROOT="${WORKFLOW_ROOT}/adapters/${ADAPTER_ID}"
RUNTIME_ROOT="$("$LOADER" --project-root "$PROJECT_ROOT" --adapter "$ADAPTER_ID" --role "$ROLE_ID" resolve runtime.root)"
RUNTIME_TASKS="$("$LOADER" --project-root "$PROJECT_ROOT" --adapter "$ADAPTER_ID" --role "$ROLE_ID" resolve runtime.tasks)"

printf '%s\n' "# AI Core Phase 4 Compatibility Check"
pass "project root"

check_dir "$RUNTIME_TASKS" "canonical runtime tasks"
if [ -f "${RUNTIME_TASKS}/index.md" ]; then
  pass "canonical runtime task index"
else
  pass "fresh runtime has no task index yet"
fi

if [ "$RUNTIME_ROOT" = "${WORKFLOW_ROOT}/runtime" ]; then
  check_link "${WORKFLOW_ROOT}/tasks" "runtime/tasks" "legacy tasks link"
else
  pass "project Runtime does not use the package legacy tasks link"
fi
check_link "${WORKFLOW_ROOT}/agents.yaml" "core/agents.yaml" "legacy Agent registry link"

if [ -f "${ADAPTER_ROOT}/workflows/device_capability_loop.md" ]; then
  check_file "${ADAPTER_ROOT}/workflows/device_capability_loop.md" "canonical project workflow"
  check_dir "${ADAPTER_ROOT}/self-test" "canonical self-test assets"
  check_dir "${ADAPTER_ROOT}/cases" "canonical project cases"
  check_link \
    "${WORKFLOW_ROOT}/workflows/device_capability_loop.md" \
    "../adapters/${ADAPTER_ID}/workflows/device_capability_loop.md" \
    "legacy device workflow link"
  check_link "${WORKFLOW_ROOT}/self_test" "adapters/${ADAPTER_ID}/self-test" "legacy self-test link"
  check_link "${WORKFLOW_ROOT}/cases" "adapters/${ADAPTER_ID}/cases" "legacy cases link"
else
  pass "project-specific legacy entries not declared"
fi

for agent_file in 00_router_agent.md 01_requirement_breakdown_agent.md 02_bugfix_agent.md 03_architecture_boundary_agent.md 04_coding_agent.md 05_self_test_agent.md 06_pr_review_agent.md 07_i18n_text_ui_risk_agent.md 08_commit_agent.md; do
  check_link \
    "${WORKFLOW_ROOT}/agents/${agent_file}" \
    "../core/agents/${agent_file}" \
    "legacy Agent link ${agent_file}"
done

for workflow_file in architecture_health_check.md bugfix_workflow.md feature_workflow.md prototype_workflow.md tech_debt_workflow.md; do
  check_link \
    "${WORKFLOW_ROOT}/workflows/${workflow_file}" \
    "../core/workflows/${workflow_file}" \
    "legacy Workflow link ${workflow_file}"
done

for template_file in execute_request_template.md fast_brief_template.md high_risk_alignment_template.md issue_intake_template.md micro_change_template.md self_test_manual_feedback_template.md self_test_report_template.md task_card_template.md technical_design_template.md test_handoff_template.md; do
  check_link \
    "${WORKFLOW_ROOT}/templates/${template_file}" \
    "../core/templates/${template_file}" \
    "legacy Template link ${template_file}"
done

if [ -f "${WORKFLOW_ROOT}/tasks/index.md" ]; then
  pass "legacy task entry resolves"
else
  pass "legacy task entry is empty for fresh runtime"
fi
if [ -f "${ADAPTER_ROOT}/workflows/device_capability_loop.md" ]; then
  check_file "${WORKFLOW_ROOT}/workflows/device_capability_loop.md" "legacy device workflow resolves"
  check_file "${WORKFLOW_ROOT}/self_test/maestro_smoke_runbook.md" "legacy self-test entry resolves"
  check_file "${WORKFLOW_ROOT}/cases/bugfix_cases.md" "legacy cases entry resolves"
fi

if [ -n "$PROJECT_ROOT" ]; then
  check_resolve "runtime.root" "$RUNTIME_ROOT"
  check_resolve "runtime.tasks" "$RUNTIME_TASKS"
  check_resolve "legacy.tasks" "${WORKFLOW_ROOT}/tasks"
  if [ -f "${ADAPTER_ROOT}/workflows/device_capability_loop.md" ]; then
    check_resolve \
      "adapter.device_workflow" \
      "${WORKFLOW_ROOT}/adapters/${ADAPTER_ID}/workflows/device_capability_loop.md"
    check_resolve \
      "legacy.device_workflow" \
      "${WORKFLOW_ROOT}/workflows/device_capability_loop.md"
  fi
fi

if [ "$failures" -gt 0 ]; then
  printf 'RESULT FAIL errors=%d\n' "$failures"
  exit 1
fi

printf '%s\n' "RESULT PASS errors=0"
