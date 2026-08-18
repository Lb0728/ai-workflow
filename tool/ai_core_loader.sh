#!/usr/bin/env bash
set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WORKFLOW_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
source "${SCRIPT_DIR}/ai_profile_select.sh"
PROJECT_ROOT=""
ADAPTER_ID="${AI_ADAPTER_ID:-}"
ROLE_ID="${AI_ROLE_ID:-}"
COMMAND="describe"
RESOLVE_KEY=""

usage() {
  cat <<'EOF'
Usage:
  ./tool/ai_core_loader.sh --project-root <path> [--adapter <id>] [--role <id>] describe
  ./tool/ai_core_loader.sh --project-root <path> [--adapter <id>] [--role <id>] resolve <key>

Resolve keys:
  core.defaults
  core.extension_slots
  core.task_types
  core.registry
  core.router
  core.agent.router
  core.agent.requirement_breakdown
  core.agent.bugfix
  core.agent.architecture_boundary
  core.agent.coding
  core.agent.self_test
  core.agent.pr_review
  core.agent.i18n_text_ui_risk
  core.agent.commit
  core.workflow.bugfix
  core.workflow.feature
  core.workflow.tech_debt
  core.template.task_card
  core.template.fast_brief
  core.template.micro_change
  core.template.high_risk_alignment
  adapter.profile
  adapter.paths
  adapter.risk_rules
  adapter.gates
  adapter.commands
  adapter.i18n
  adapter.commit
  adapter.extensions
  adapter.task_types
  adapter.context.router
  adapter.context.architecture_sources
  adapter.context.current_project_reality
  adapter.context.source_of_truth
  adapter.context.regression_surfaces
  role.profile
  runtime.root
  runtime.tasks
  runtime.states
  runtime.handoffs
  runtime.closeouts
  runtime.defects
  legacy.tasks
  adapter.device_workflow
  legacy.device_workflow
  adapter.self_test
  legacy.self_test
  adapter.cases
  legacy.cases
  project.rules
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --project-root)
      if [ "$#" -lt 2 ]; then
        printf '%s\n' "ERROR --project-root value is required" >&2
        exit 2
      fi
      PROJECT_ROOT="${2:-}"
      shift 2
      ;;
    --adapter)
      if [ "$#" -lt 2 ]; then
        printf '%s\n' "ERROR --adapter value is required" >&2
        exit 2
      fi
      ADAPTER_ID="${2:-}"
      shift 2
      ;;
    --role)
      if [ "$#" -lt 2 ]; then
        printf '%s\n' "ERROR --role value is required" >&2
        exit 2
      fi
      ROLE_ID="${2:-}"
      shift 2
      ;;
    describe)
      COMMAND="describe"
      shift
      ;;
    resolve)
      if [ "$#" -lt 2 ]; then
        printf '%s\n' "ERROR resolve key is required" >&2
        exit 2
      fi
      COMMAND="resolve"
      RESOLVE_KEY="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      printf 'ERROR unknown argument: %s\n' "$1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [ -z "$PROJECT_ROOT" ]; then
  printf '%s\n' "ERROR --project-root is required" >&2
  exit 2
fi

if [ ! -d "$PROJECT_ROOT" ]; then
  printf 'ERROR project root not found: %s\n' "$PROJECT_ROOT" >&2
  exit 1
fi

PROJECT_ROOT="$(cd "$PROJECT_ROOT" && pwd)"
ADAPTER_ID="$(ai_select_project_adapter_id "${WORKFLOW_ROOT}/adapters" "$ADAPTER_ID" "$PROJECT_ROOT")" || exit $?
ROLE_ID="$(ai_select_profile_id "${WORKFLOW_ROOT}/roles" "$ROLE_ID" "Role Adapter")" || exit $?
ADAPTER_ROOT="${WORKFLOW_ROOT}/adapters/${ADAPTER_ID}"
ROLE_ROOT="${WORKFLOW_ROOT}/roles/${ROLE_ID}"
RUNTIME_ROOT="${AI_RUNTIME_ROOT:-}"

if [ -z "$RUNTIME_ROOT" ]; then
  if [ -d "${PROJECT_ROOT}/.ai-runtime" ]; then
    RUNTIME_ROOT="${PROJECT_ROOT}/.ai-runtime"
  else
    RUNTIME_ROOT="${WORKFLOW_ROOT}/runtime"
  fi
elif [ "${RUNTIME_ROOT#/}" = "$RUNTIME_ROOT" ]; then
  RUNTIME_ROOT="${PROJECT_ROOT}/${RUNTIME_ROOT}"
fi

if [ -d "$RUNTIME_ROOT" ]; then
  RUNTIME_ROOT="$(cd "$RUNTIME_ROOT" && pwd)"
fi

for required_file in \
  "${WORKFLOW_ROOT}/core/config/core-defaults.yaml" \
  "${ADAPTER_ROOT}/project-profile.yaml" \
  "${ROLE_ROOT}/role-profile.yaml"; do
  if [ ! -f "$required_file" ]; then
    printf 'ERROR required loader input missing: %s\n' "$required_file" >&2
    exit 1
  fi
done

resolve_key() {
  case "$1" in
    core.defaults)
      printf '%s\n' "${WORKFLOW_ROOT}/core/config/core-defaults.yaml"
      ;;
    core.extension_slots)
      printf '%s\n' "${WORKFLOW_ROOT}/core/config/extension-slots.yaml"
      ;;
    core.task_types)
      printf '%s\n' "${WORKFLOW_ROOT}/core/config/task-types.yaml"
      ;;
    core.registry)
      printf '%s\n' "${WORKFLOW_ROOT}/core/agents.yaml"
      ;;
    core.router|core.agent.router)
      printf '%s\n' "${WORKFLOW_ROOT}/core/agents/00_router_agent.md"
      ;;
    core.agent.requirement_breakdown)
      printf '%s\n' "${WORKFLOW_ROOT}/core/agents/01_requirement_breakdown_agent.md"
      ;;
    core.agent.bugfix)
      printf '%s\n' "${WORKFLOW_ROOT}/core/agents/02_bugfix_agent.md"
      ;;
    core.agent.architecture_boundary)
      printf '%s\n' "${WORKFLOW_ROOT}/core/agents/03_architecture_boundary_agent.md"
      ;;
    core.agent.coding)
      printf '%s\n' "${WORKFLOW_ROOT}/core/agents/04_coding_agent.md"
      ;;
    core.agent.self_test)
      printf '%s\n' "${WORKFLOW_ROOT}/core/agents/05_self_test_agent.md"
      ;;
    core.agent.pr_review)
      printf '%s\n' "${WORKFLOW_ROOT}/core/agents/06_pr_review_agent.md"
      ;;
    core.agent.i18n_text_ui_risk)
      printf '%s\n' "${WORKFLOW_ROOT}/core/agents/07_i18n_text_ui_risk_agent.md"
      ;;
    core.agent.commit)
      printf '%s\n' "${WORKFLOW_ROOT}/core/agents/08_commit_agent.md"
      ;;
    core.workflow.bugfix)
      printf '%s\n' "${WORKFLOW_ROOT}/core/workflows/bugfix_workflow.md"
      ;;
    core.workflow.feature)
      printf '%s\n' "${WORKFLOW_ROOT}/core/workflows/feature_workflow.md"
      ;;
    core.workflow.tech_debt)
      printf '%s\n' "${WORKFLOW_ROOT}/core/workflows/tech_debt_workflow.md"
      ;;
    core.template.task_card)
      printf '%s\n' "${WORKFLOW_ROOT}/core/templates/task_card_template.md"
      ;;
    core.template.fast_brief)
      printf '%s\n' "${WORKFLOW_ROOT}/core/templates/fast_brief_template.md"
      ;;
    core.template.micro_change)
      printf '%s\n' "${WORKFLOW_ROOT}/core/templates/micro_change_template.md"
      ;;
    core.template.high_risk_alignment)
      printf '%s\n' "${WORKFLOW_ROOT}/core/templates/high_risk_alignment_template.md"
      ;;
    adapter.profile)
      printf '%s\n' "${ADAPTER_ROOT}/project-profile.yaml"
      ;;
    adapter.paths)
      printf '%s\n' "${ADAPTER_ROOT}/config/paths.yaml"
      ;;
    adapter.risk_rules)
      printf '%s\n' "${ADAPTER_ROOT}/config/risk-rules.yaml"
      ;;
    adapter.gates)
      printf '%s\n' "${ADAPTER_ROOT}/config/gates.yaml"
      ;;
    adapter.commands)
      printf '%s\n' "${ADAPTER_ROOT}/config/commands.yaml"
      ;;
    adapter.i18n)
      printf '%s\n' "${ADAPTER_ROOT}/config/i18n.yaml"
      ;;
    adapter.commit)
      printf '%s\n' "${ADAPTER_ROOT}/config/commit.yaml"
      ;;
    adapter.extensions)
      printf '%s\n' "${ADAPTER_ROOT}/config/extensions.yaml"
      ;;
    adapter.task_types)
      printf '%s\n' "${ADAPTER_ROOT}/config/task-types.yaml"
      ;;
    adapter.context.router)
      printf '%s\n' "${ADAPTER_ROOT}/context/router-context.md"
      ;;
    adapter.context.architecture_sources)
      printf '%s\n' "${ADAPTER_ROOT}/context/architecture-sources.md"
      ;;
    adapter.context.current_project_reality)
      printf '%s\n' "${ADAPTER_ROOT}/context/current-project-reality.md"
      ;;
    adapter.context.source_of_truth)
      printf '%s\n' "${ADAPTER_ROOT}/context/source-of-truth.md"
      ;;
    adapter.context.regression_surfaces)
      printf '%s\n' "${ADAPTER_ROOT}/context/regression-surfaces.md"
      ;;
    role.profile)
      printf '%s\n' "${ROLE_ROOT}/role-profile.yaml"
      ;;
    runtime.root)
      printf '%s\n' "$RUNTIME_ROOT"
      ;;
    runtime.tasks)
      printf '%s\n' "${RUNTIME_ROOT}/tasks"
      ;;
    runtime.states)
      printf '%s\n' "${RUNTIME_ROOT}/states"
      ;;
    runtime.handoffs)
      printf '%s\n' "${RUNTIME_ROOT}/handoffs"
      ;;
    runtime.closeouts)
      printf '%s\n' "${RUNTIME_ROOT}/closeouts"
      ;;
    runtime.defects)
      printf '%s\n' "${RUNTIME_ROOT}/defects"
      ;;
    legacy.tasks)
      printf '%s\n' "${WORKFLOW_ROOT}/tasks"
      ;;
    adapter.device_workflow)
      printf '%s\n' "${ADAPTER_ROOT}/workflows/device_capability_loop.md"
      ;;
    legacy.device_workflow)
      printf '%s\n' "${WORKFLOW_ROOT}/workflows/device_capability_loop.md"
      ;;
    adapter.self_test)
      printf '%s\n' "${ADAPTER_ROOT}/self-test"
      ;;
    legacy.self_test)
      printf '%s\n' "${WORKFLOW_ROOT}/self_test"
      ;;
    adapter.cases)
      printf '%s\n' "${ADAPTER_ROOT}/cases"
      ;;
    legacy.cases)
      printf '%s\n' "${WORKFLOW_ROOT}/cases"
      ;;
    project.rules)
      printf '%s\n' "${PROJECT_ROOT}/AGENTS.md"
      ;;
    *)
      printf 'ERROR unknown resolve key: %s\n' "$1" >&2
      return 2
      ;;
  esac
}

case "$COMMAND" in
  describe)
    printf 'workflow_root=%s\n' "$WORKFLOW_ROOT"
    printf 'project_root=%s\n' "$PROJECT_ROOT"
    printf 'adapter=%s\n' "$ADAPTER_ID"
    printf 'role=%s\n' "$ROLE_ID"
    printf 'runtime_root=%s\n' "$RUNTIME_ROOT"
    printf '%s\n' "migration_phase=phase4-agent-activation"
    printf '%s\n' "protocol_routing=core-with-project-adapter"
    printf '%s\n' "agent_owner=core-with-project-adapter"
    printf '%s\n' "runtime_owner=runtime"
    printf '%s\n' "legacy_entry_mode=symlink"
    ;;
  resolve)
    if [ -z "$RESOLVE_KEY" ]; then
      printf '%s\n' "ERROR resolve key is required" >&2
      exit 2
    fi
    resolve_key "$RESOLVE_KEY"
    ;;
esac
