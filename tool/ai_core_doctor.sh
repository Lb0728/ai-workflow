#!/usr/bin/env bash
set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WORKFLOW_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
source "${SCRIPT_DIR}/ai_profile_select.sh"
PROJECT_ROOT=""
ADAPTER_ID="${AI_ADAPTER_ID:-}"
ROLE_ID="${AI_ROLE_ID:-}"
failures=0
warnings=0

usage() {
  printf '%s\n' "Usage: ./tool/ai_core_doctor.sh --project-root <path> [--adapter <id>] [--role <id>]"
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --project-root)
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

pass() {
  printf 'PASS %s\n' "$1"
}

warn() {
  printf 'WARN %s\n' "$1"
  warnings=$((warnings + 1))
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

check_writable_dir() {
  if [ -w "$1" ]; then
    pass "$2"
  else
    warn "$2 is not writable in the current execution environment: $1"
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

require_pattern() {
  local file="$1"
  local pattern="$2"
  local label="$3"
  if grep -Eq "$pattern" "$file"; then
    pass "$label"
  else
    fail "$label missing in $file"
  fi
}

check_relative_project_path() {
  local key="$1"
  local value="$2"
  if [ -z "$value" ]; then
    fail "project path key missing: $key"
  elif [ -e "${PROJECT_ROOT}/${value}" ] || [ -L "${PROJECT_ROOT}/${value}" ]; then
    pass "project path ${key}"
  else
    fail "project path ${key} not found: ${PROJECT_ROOT}/${value}"
  fi
}

check_declared_project_paths() {
  local config="$1"
  local entries=""
  local key=""
  local value=""

  entries="$(
    awk '
      /^  project:$/ { in_project = 1; next }
      in_project && /^    [A-Za-z0-9_]+:/ {
        line = $0
        sub(/^    /, "", line)
        key = line
        sub(/:.*/, "", key)
        value = line
        sub(/^[^:]+:[[:space:]]*/, "", value)
        gsub(/^"|"$/, "", value)
        if (key != "base") {
          print key "|" value
        }
        next
      }
      in_project && !/^    / { exit }
    ' "$config"
  )"

  while IFS='|' read -r key value; do
    if [ -n "$key" ]; then
      check_relative_project_path "$key" "$value"
    fi
  done <<EOF
$entries
EOF
}

check_distribution_manifest() {
  local legacy_manifest="${WORKFLOW_ROOT}/distribution/${ADAPTER_ID}-colleague.yaml"
  local shared_manifest="${WORKFLOW_ROOT}/distribution/example.yaml"

  if [ -f "$legacy_manifest" ]; then
    pass "distribution manifest"
  elif [ -f "$shared_manifest" ] &&
      grep -F -q -- "- adapters/${ADAPTER_ID}/" "$shared_manifest"; then
    pass "shared distribution manifest"
  else
    fail "distribution manifest missing for adapter: ${ADAPTER_ID}"
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

printf '%s\n' "# AI Core Migration Doctor"
printf 'workflow_root=%s\n' "$WORKFLOW_ROOT"
printf 'adapter=%s\n' "$ADAPTER_ID"
printf 'role=%s\n' "$ROLE_ID"
pass "project root"

CORE_DEFAULTS="${WORKFLOW_ROOT}/core/config/core-defaults.yaml"
SHADOW_SCHEMA="${WORKFLOW_ROOT}/core/schemas/shadow-layout.schema.yaml"
COMPAT_SCHEMA="${WORKFLOW_ROOT}/core/schemas/compatibility-layout.schema.yaml"
ROUTER_SCHEMA="${WORKFLOW_ROOT}/core/schemas/router-slice.schema.yaml"
ADAPTER_ROOT="${WORKFLOW_ROOT}/adapters/${ADAPTER_ID}"
PROJECT_PROFILE="${ADAPTER_ROOT}/project-profile.yaml"
PATHS_CONFIG="${ADAPTER_ROOT}/config/paths.yaml"
COMMANDS_CONFIG="${ADAPTER_ROOT}/config/commands.yaml"
RISK_CONFIG="${ADAPTER_ROOT}/config/risk-rules.yaml"
GATES_CONFIG="${ADAPTER_ROOT}/config/gates.yaml"
I18N_CONFIG="${ADAPTER_ROOT}/config/i18n.yaml"
COMMIT_CONFIG="${ADAPTER_ROOT}/config/commit.yaml"
EXTENSIONS_CONFIG="${ADAPTER_ROOT}/config/extensions.yaml"
TASK_TYPES_CONFIG="${ADAPTER_ROOT}/config/task-types.yaml"
ROLE_PROFILE="${WORKFLOW_ROOT}/roles/${ROLE_ID}/role-profile.yaml"
RUNTIME_ROOT="$(
  "${SCRIPT_DIR}/ai_core_loader.sh" \
    --project-root "$PROJECT_ROOT" \
    --adapter "$ADAPTER_ID" \
    --role "$ROLE_ID" \
    resolve runtime.root 2>/dev/null
)" || RUNTIME_ROOT="${WORKFLOW_ROOT}/runtime"

check_file "${WORKFLOW_ROOT}/core/LOADER_CONTRACT.md" "loader contract"
check_file "$CORE_DEFAULTS" "core defaults"
check_file "$SHADOW_SCHEMA" "Phase 1 shadow schema"
check_file "$COMPAT_SCHEMA" "Phase 2 compatibility schema"
check_file "$ROUTER_SCHEMA" "Phase 3 Router schema"
check_file "$PROJECT_PROFILE" "project profile"
check_file "$ROLE_PROFILE" "role profile"
check_file "${WORKFLOW_ROOT}/core/LOADER_CONTRACT_V2.md" "loader contract v2"
check_file "${WORKFLOW_ROOT}/core/config/state-machine.yaml" "state machine definition"
check_file "${WORKFLOW_ROOT}/core/lib/state_machine.sh" "state machine accessor"
check_file "${WORKFLOW_ROOT}/core/lib/task_card.sh" "task card validator"
check_file "${WORKFLOW_ROOT}/core/schemas/task-card.schema.yaml" "task card schema"
check_distribution_manifest
check_file "${WORKFLOW_ROOT}/tool/ai_distribution_check.sh" "distribution checker"
check_file "${WORKFLOW_ROOT}/tool/ai_distribution_package.sh" "distribution packager"
check_file "${WORKFLOW_ROOT}/tool/ai_developer_pilot_check.sh" "developer pilot checker"
check_file "${WORKFLOW_ROOT}/core/agents.yaml" "Core Agent registry"

for config in paths.yaml commands.yaml risk-rules.yaml gates.yaml i18n.yaml commit.yaml extensions.yaml task-types.yaml; do
  check_file "${ADAPTER_ROOT}/config/${config}" "adapter config ${config}"
done

for context in router-context.md architecture-sources.md current-project-reality.md source-of-truth.md regression-surfaces.md; do
  check_file "${ADAPTER_ROOT}/context/${context}" "adapter context ${context}"
done

check_link "${WORKFLOW_ROOT}/agents.yaml" "core/agents.yaml" "legacy Agent registry link"

for agent_file in \
  00_router_agent.md \
  01_requirement_breakdown_agent.md \
  02_bugfix_agent.md \
  03_architecture_boundary_agent.md \
  04_coding_agent.md \
  05_self_test_agent.md \
  06_pr_review_agent.md \
  07_i18n_text_ui_risk_agent.md \
  08_commit_agent.md; do
  check_file "${WORKFLOW_ROOT}/core/agents/${agent_file}" "Core Agent ${agent_file}"
  check_link \
    "${WORKFLOW_ROOT}/agents/${agent_file}" \
    "../core/agents/${agent_file}" \
    "legacy Agent link ${agent_file}"
done

for workflow_file in architecture_health_check.md bugfix_workflow.md feature_workflow.md prototype_workflow.md tech_debt_workflow.md; do
  check_file "${WORKFLOW_ROOT}/core/workflows/${workflow_file}" "Core Workflow ${workflow_file}"
  check_link \
    "${WORKFLOW_ROOT}/workflows/${workflow_file}" \
    "../core/workflows/${workflow_file}" \
    "legacy Workflow link ${workflow_file}"
done

if [ -f "${ADAPTER_ROOT}/workflows/device_capability_loop.md" ]; then
  check_link \
    "${WORKFLOW_ROOT}/workflows/device_capability_loop.md" \
    "../adapters/${ADAPTER_ID}/workflows/device_capability_loop.md" \
    "project Workflow compatibility link"
else
  pass "project Workflow compatibility link not declared"
fi

for template_file in execute_request_template.md fast_brief_template.md high_risk_alignment_template.md issue_intake_template.md micro_change_template.md self_test_manual_feedback_template.md self_test_report_template.md task_card_template.md technical_design_template.md test_handoff_template.md; do
  check_file "${WORKFLOW_ROOT}/core/templates/${template_file}" "Core Template ${template_file}"
  check_link \
    "${WORKFLOW_ROOT}/templates/${template_file}" \
    "../core/templates/${template_file}" \
    "legacy Template link ${template_file}"
done

for legacy_dir in agents skills workflows templates tool tasks; do
  check_dir "${WORKFLOW_ROOT}/${legacy_dir}" "legacy ${legacy_dir}"
done

for runtime_dir in tasks states handoffs closeouts defects; do
  check_dir "${RUNTIME_ROOT}/${runtime_dir}" "runtime ${runtime_dir}"
done
check_writable_dir "$RUNTIME_ROOT" "runtime root writable"

if [ -f "$CORE_DEFAULTS" ]; then
  require_pattern "$CORE_DEFAULTS" 'migration_phase:[[:space:]]+phase4-agent-activation' "Core Agent migration phase"
  require_pattern "$CORE_DEFAULTS" 'active:[[:space:]]+true' "core active"
  require_pattern "$CORE_DEFAULTS" 'active_from_core:[[:space:]]+true' "Core Router active"
  require_pattern "$CORE_DEFAULTS" 'runtime_owner:[[:space:]]+runtime-layout' "runtime canonical owner"
  require_pattern "$CORE_DEFAULTS" 'protocol_routing_owner:[[:space:]]+core-with-project-profile' "config-driven protocol owner"
  require_pattern "$CORE_DEFAULTS" 'agent_owner:[[:space:]]+core-with-project-local-knowledge' "config-driven Agent owner"
  require_pattern "$CORE_DEFAULTS" 'full_config_routing_active:[[:space:]]+true' "full Core routing active"
  require_pattern "$CORE_DEFAULTS" 'legacy_entry_mode:[[:space:]]+symlink' "legacy compatibility mode"
fi

if [ -f "$PROJECT_PROFILE" ]; then
  require_pattern "$PROJECT_PROFILE" 'config_dir:[[:space:]]+config' "adapter config directory"
  require_pattern "$PROJECT_PROFILE" 'context_dir:[[:space:]]+context' "adapter context directory"
  require_pattern "$PROJECT_PROFILE" '^detection:' "adapter detection declared"
  require_pattern "$PROJECT_PROFILE" 'required_paths:' "adapter detection paths declared"
  require_pattern "$PROJECT_PROFILE" 'active:[[:space:]]+true' "adapter active"
  require_pattern "$PROJECT_PROFILE" 'canonical_assets_active:[[:space:]]+true' "adapter canonical assets active"
  require_pattern "$PROJECT_PROFILE" 'router_context_active:[[:space:]]+true' "adapter Router context active"
  require_pattern "$PROJECT_PROFILE" 'full_adapter_routing_active:[[:space:]]+true' "full Adapter routing active"
  require_pattern "$PROJECT_PROFILE" 'protocol_routing_owner:[[:space:]]+core-with-project-adapter' "adapter protocol owner"
fi

if [ -f "$ROLE_PROFILE" ]; then
  require_pattern "$ROLE_PROFILE" 'stages:' "role stages"
  require_pattern "$ROLE_PROFILE" 'active:[[:space:]]+true' "role active"
  require_pattern "$ROLE_PROFILE" 'router_selection_active:[[:space:]]+true' "Role Router selection active"
  require_pattern "$ROLE_PROFILE" 'agent_selection_active:[[:space:]]+true' "Role Agent selection active"
  require_pattern "$ROLE_PROFILE" 'shadow_profile_may_route:[[:space:]]+false' "role cannot route"
fi

if [ -f "$COMMANDS_CONFIG" ]; then
  require_pattern "$COMMANDS_CONFIG" 'allow_eval:[[:space:]]+false' "commands forbid eval"
  require_pattern "$COMMANDS_CONFIG" 'doctor_executes_commands:[[:space:]]+false' "Doctor does not execute commands"
  require_pattern "$COMMANDS_CONFIG" 'routing_regression:' "routing regression command declared"
fi

if [ -f "$RISK_CONFIG" ]; then
  require_pattern "$RISK_CONFIG" 'core_user_flows:' "project core flows declared"
  require_pattern "$RISK_CONFIG" 'project_high_risk_domains:' "project high-risk domains declared"
fi

if [ -f "$GATES_CONFIG" ]; then
  require_pattern "$GATES_CONFIG" 'project_gates:' "project Gates declared"
  require_pattern "$GATES_CONFIG" 'manual_verification:' "manual verification policy declared"
fi

if [ -f "$I18N_CONFIG" ]; then
  require_pattern "$I18N_CONFIG" 'generated_output:' "i18n generated output declared"
  require_pattern "$I18N_CONFIG" 'source:' "i18n source state declared"
  require_pattern "$I18N_CONFIG" 'never_infer_project_has_no_i18n:[[:space:]]+true' "i18n anti-drift rule declared"
fi

if [ -f "$COMMIT_CONFIG" ]; then
  require_pattern "$COMMIT_CONFIG" 'title_pattern:' "commit title pattern declared"
  require_pattern "$COMMIT_CONFIG" 'never_fabricate_task_reference:[[:space:]]+true' "commit anti-fabrication rule declared"
fi

if [ -f "$EXTENSIONS_CONFIG" ]; then
  require_pattern "$EXTENSIONS_CONFIG" 'project_specific:' "project Workflow extension declared"
  require_pattern "$EXTENSIONS_CONFIG" 'validation_placeholders:' "Template validation extension declared"
fi

if [ -f "$TASK_TYPES_CONFIG" ]; then
  require_pattern "$TASK_TYPES_CONFIG" 'task_types:' "project task type extensions declared"
  require_pattern "$TASK_TYPES_CONFIG" 'workflow_key:' "project task type Workflow declared"
fi

if [ -n "$PROJECT_ROOT" ] && [ -f "$PATHS_CONFIG" ]; then
  check_declared_project_paths "$PATHS_CONFIG"
fi

case "${LC_ALL:-${LC_CTYPE:-${LANG:-}}}" in
  *UTF-8*|*utf8*|*UTF8*)
    pass "UTF-8 locale"
    ;;
  *)
    fail "UTF-8 locale required; current locale breaks Chinese routing fields"
    ;;
esac

if grep -R -n -E '/Users/[A-Za-z0-9._-]+|/Volumes/[A-Za-z0-9._-]+' "${WORKFLOW_ROOT}/core" >/dev/null; then
  fail "Core contains project-bound terms"
else
  pass "Core project-term scan"
fi

if [ "$failures" -gt 0 ]; then
  printf 'RESULT FAIL errors=%d warnings=%d\n' "$failures" "$warnings"
  exit 1
fi

printf 'RESULT PASS errors=0 warnings=%d\n' "$warnings"
