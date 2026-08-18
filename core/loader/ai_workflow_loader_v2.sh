#!/usr/bin/env bash
set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WORKFLOW_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
PROJECT_ROOT=""
HOST_ID=""
ROLE_ID="developer"
COMMAND="describe"
RESOLVE_KEY=""

usage() {
  cat <<'EOF'
Usage:
  ai_workflow_loader_v2.sh --project-root <path> [--host <id>] [--role <id>] describe
  ai_workflow_loader_v2.sh --project-root <path> [--host <id>] [--role <id>] validate
  ai_workflow_loader_v2.sh --project-root <path> [--host <id>] [--role <id>] resolve <key>

Resolve keys:
  workflow.version
  core.defaults
  core.task_types
  core.registry
  core.agent.<router|requirement_breakdown|bugfix|architecture_boundary|coding|self_test|pr_review|i18n_text_ui_risk|commit>
  core.workflow.<bugfix|feature|tech_debt>
  core.template.<task_card|fast_brief|micro_change|high_risk_alignment>
  company.manifest
  company.<commit|review|security|delivery>
  host.profile
  host.instructions
  role.profile
  project.profile
  project.lock
  project.<architecture|risks|defects|policies>
  runtime.<root|tasks|states|handoffs|closeouts|defects>
EOF
}

diagnostic_path() {
  local candidate="$1"
  case "$candidate" in
    "${WORKFLOW_ROOT}"/*) printf 'workflow/%s\n' "${candidate#"${WORKFLOW_ROOT}/"}" ;;
    "${PROJECT_ROOT}"/*) printf 'project/%s\n' "${candidate#"${PROJECT_ROOT}/"}" ;;
    *) printf '%s\n' "$(basename "$candidate")" ;;
  esac
}

fail_missing() {
  printf 'ERROR required V2 input missing: %s\n' "$(diagnostic_path "$1")" >&2
  exit 1
}

read_lock_id() {
  local section="$1"
  local lock_file="$2"
  awk -v section="$section" '
    $0 == section ":" { in_section = 1; next }
    in_section && /^[^[:space:]]/ { in_section = 0 }
    in_section && /^[[:space:]]+id:[[:space:]]*/ {
      value = $0
      sub(/^[^:]+:[[:space:]]*/, "", value)
      gsub(/^['\''"]|['\''"]$/, "", value)
      print value
      exit
    }
  ' "$lock_file"
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --project-root)
      [ "$#" -ge 2 ] || { printf '%s\n' "ERROR --project-root value is required" >&2; exit 2; }
      PROJECT_ROOT="$2"
      shift 2
      ;;
    --host)
      [ "$#" -ge 2 ] || { printf '%s\n' "ERROR --host value is required" >&2; exit 2; }
      HOST_ID="$2"
      shift 2
      ;;
    --role)
      [ "$#" -ge 2 ] || { printf '%s\n' "ERROR --role value is required" >&2; exit 2; }
      ROLE_ID="$2"
      shift 2
      ;;
    describe|validate)
      COMMAND="$1"
      shift
      ;;
    resolve)
      [ "$#" -ge 2 ] || { printf '%s\n' "ERROR resolve key is required" >&2; exit 2; }
      COMMAND="resolve"
      RESOLVE_KEY="$2"
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

[ -n "$PROJECT_ROOT" ] || { printf '%s\n' "ERROR --project-root is required" >&2; exit 2; }
[ -d "$PROJECT_ROOT" ] || { printf '%s\n' "ERROR project root not found" >&2; exit 1; }
PROJECT_ROOT="$(cd "$PROJECT_ROOT" && pwd)"

if [ -z "$HOST_ID" ]; then
  PROJECT_LOCK="${PROJECT_ROOT}/.ai/ai.lock"
  [ -f "$PROJECT_LOCK" ] || {
    printf '%s\n' "ERROR Host is required: pass --host <id> or initialize .ai/ai.lock" >&2
    exit 1
  }
  HOST_ID="$(read_lock_id host "$PROJECT_LOCK")"
  [ -n "$HOST_ID" ] || {
    printf '%s\n' "ERROR Host id missing from .ai/ai.lock" >&2
    exit 1
  }
fi

case "$HOST_ID" in
  *[!A-Za-z0-9._-]*)
    printf 'ERROR invalid Host id: %s\n' "$HOST_ID" >&2
    exit 1
    ;;
esac

HOST_ROOT="${WORKFLOW_ROOT}/hosts/${HOST_ID}"
ROLE_ROOT="${WORKFLOW_ROOT}/roles/${ROLE_ID}"
PROJECT_AI_ROOT="${PROJECT_ROOT}/.ai"
RUNTIME_ROOT="${PROJECT_AI_ROOT}/runtime"

[ -f "${HOST_ROOT}/host.yaml" ] || {
  printf 'ERROR Host Adapter not found: %s\n' "$HOST_ID" >&2
  exit 1
}

required_inputs=(
  "${WORKFLOW_ROOT}/VERSION"
  "${WORKFLOW_ROOT}/core/config/core-defaults.yaml"
  "${WORKFLOW_ROOT}/core/agents.yaml"
  "${WORKFLOW_ROOT}/policies/company/policy.yaml"
  "${WORKFLOW_ROOT}/policies/company/commit-convention.yaml"
  "${WORKFLOW_ROOT}/policies/company/review-policy.md"
  "${WORKFLOW_ROOT}/policies/company/security-policy.md"
  "${WORKFLOW_ROOT}/policies/company/delivery-policy.md"
  "${HOST_ROOT}/host.yaml"
  "${HOST_ROOT}/entry-template/instructions.md"
  "${ROLE_ROOT}/role-profile.yaml"
  "${PROJECT_AI_ROOT}/project.yaml"
  "${PROJECT_AI_ROOT}/ai.lock"
  "${PROJECT_AI_ROOT}/architecture"
  "${PROJECT_AI_ROOT}/risks"
  "${PROJECT_AI_ROOT}/defects"
  "${PROJECT_AI_ROOT}/policies"
  "${RUNTIME_ROOT}"
)

validate_inputs() {
  local required_input
  for required_input in "${required_inputs[@]}"; do
    if [ ! -e "$required_input" ]; then
      fail_missing "$required_input"
    fi
  done
}

validate_immutable_conflicts() {
  local scan_root protected_key
  for scan_root in \
    "${PROJECT_AI_ROOT}/project.yaml" \
    "${PROJECT_AI_ROOT}/architecture" \
    "${PROJECT_AI_ROOT}/risks" \
    "${PROJECT_AI_ROOT}/defects" \
    "${PROJECT_AI_ROOT}/policies" \
    "${RUNTIME_ROOT}"; do
    [ -e "$scan_root" ] || continue
    for protected_key in \
      risk_levels decision_actions gate_results automatic_commit automatic_push hard_gates stop_conditions; do
      if grep -R -E -l \
        "(^|[^[:alnum:]_])${protected_key}[[:space:]]*:" \
        "$scan_root" 2>/dev/null | head -n 1 | grep -q .; then
        printf 'STOP immutable conflict: company policy key "%s" is redefined under %s\n' \
          "$protected_key" "$(diagnostic_path "$scan_root")" >&2
        return 1
      fi
    done
  done
}

resolve_key() {
  case "$1" in
    workflow.version) printf '%s\n' "${WORKFLOW_ROOT}/VERSION" ;;
    core.defaults) printf '%s\n' "${WORKFLOW_ROOT}/core/config/core-defaults.yaml" ;;
    core.task_types) printf '%s\n' "${WORKFLOW_ROOT}/core/config/task-types.yaml" ;;
    core.registry) printf '%s\n' "${WORKFLOW_ROOT}/core/agents.yaml" ;;
    core.agent.router) printf '%s\n' "${WORKFLOW_ROOT}/core/agents/00_router_agent.md" ;;
    core.agent.requirement_breakdown) printf '%s\n' "${WORKFLOW_ROOT}/core/agents/01_requirement_breakdown_agent.md" ;;
    core.agent.bugfix) printf '%s\n' "${WORKFLOW_ROOT}/core/agents/02_bugfix_agent.md" ;;
    core.agent.architecture_boundary) printf '%s\n' "${WORKFLOW_ROOT}/core/agents/03_architecture_boundary_agent.md" ;;
    core.agent.coding) printf '%s\n' "${WORKFLOW_ROOT}/core/agents/04_coding_agent.md" ;;
    core.agent.self_test) printf '%s\n' "${WORKFLOW_ROOT}/core/agents/05_self_test_agent.md" ;;
    core.agent.pr_review) printf '%s\n' "${WORKFLOW_ROOT}/core/agents/06_pr_review_agent.md" ;;
    core.agent.i18n_text_ui_risk) printf '%s\n' "${WORKFLOW_ROOT}/core/agents/07_i18n_text_ui_risk_agent.md" ;;
    core.agent.commit) printf '%s\n' "${WORKFLOW_ROOT}/core/agents/08_commit_agent.md" ;;
    core.workflow.bugfix) printf '%s\n' "${WORKFLOW_ROOT}/core/workflows/bugfix_workflow.md" ;;
    core.workflow.feature) printf '%s\n' "${WORKFLOW_ROOT}/core/workflows/feature_workflow.md" ;;
    core.workflow.tech_debt) printf '%s\n' "${WORKFLOW_ROOT}/core/workflows/tech_debt_workflow.md" ;;
    core.template.task_card) printf '%s\n' "${WORKFLOW_ROOT}/core/templates/task_card_template.md" ;;
    core.template.fast_brief) printf '%s\n' "${WORKFLOW_ROOT}/core/templates/fast_brief_template.md" ;;
    core.template.micro_change) printf '%s\n' "${WORKFLOW_ROOT}/core/templates/micro_change_template.md" ;;
    core.template.high_risk_alignment) printf '%s\n' "${WORKFLOW_ROOT}/core/templates/high_risk_alignment_template.md" ;;
    company.manifest) printf '%s\n' "${WORKFLOW_ROOT}/policies/company/policy.yaml" ;;
    company.commit) printf '%s\n' "${WORKFLOW_ROOT}/policies/company/commit-convention.yaml" ;;
    company.review) printf '%s\n' "${WORKFLOW_ROOT}/policies/company/review-policy.md" ;;
    company.security) printf '%s\n' "${WORKFLOW_ROOT}/policies/company/security-policy.md" ;;
    company.delivery) printf '%s\n' "${WORKFLOW_ROOT}/policies/company/delivery-policy.md" ;;
    host.profile) printf '%s\n' "${HOST_ROOT}/host.yaml" ;;
    host.instructions) printf '%s\n' "${PROJECT_AI_ROOT}/hosts/${HOST_ID}/instructions.md" ;;
    role.profile) printf '%s\n' "${ROLE_ROOT}/role-profile.yaml" ;;
    project.profile) printf '%s\n' "${PROJECT_AI_ROOT}/project.yaml" ;;
    project.lock) printf '%s\n' "${PROJECT_AI_ROOT}/ai.lock" ;;
    project.architecture) printf '%s\n' "${PROJECT_AI_ROOT}/architecture" ;;
    project.risks) printf '%s\n' "${PROJECT_AI_ROOT}/risks" ;;
    project.defects) printf '%s\n' "${PROJECT_AI_ROOT}/defects" ;;
    project.policies) printf '%s\n' "${PROJECT_AI_ROOT}/policies" ;;
    runtime.root) printf '%s\n' "${RUNTIME_ROOT}" ;;
    runtime.tasks) printf '%s\n' "${RUNTIME_ROOT}/tasks" ;;
    runtime.states) printf '%s\n' "${RUNTIME_ROOT}/states" ;;
    runtime.handoffs) printf '%s\n' "${RUNTIME_ROOT}/handoffs" ;;
    runtime.closeouts) printf '%s\n' "${RUNTIME_ROOT}/closeouts" ;;
    runtime.defects) printf '%s\n' "${RUNTIME_ROOT}/defects" ;;
    *)
      printf 'ERROR unsupported resolve key: %s\n' "$1" >&2
      return 2
      ;;
  esac
}

validate_inputs
validate_immutable_conflicts

case "$COMMAND" in
  validate)
    printf 'V2 loader validation: PASS\n'
    ;;
  resolve)
    resolve_key "$RESOLVE_KEY"
    ;;
  describe)
    printf 'workflow_version=%s\n' "$(tr -d '\r\n' < "${WORKFLOW_ROOT}/VERSION")"
    printf 'host=%s\n' "$HOST_ID"
    printf 'role=%s\n' "$ROLE_ID"
    printf 'project_profile=.ai/project.yaml\n'
    printf 'runtime=.ai/runtime\n'
    printf 'company_policy=policies/company/policy.yaml\n'
    ;;
esac
