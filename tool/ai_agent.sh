#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
AI_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
source "${SCRIPT_DIR}/ai_profile_select.sh"
LOADER="${SCRIPT_DIR}/ai_core_loader.sh"
PROJECT_ROOT="${AI_PROJECT_ROOT:-}"
ADAPTER_ID="${AI_ADAPTER_ID:-}"
ROLE_ID="${AI_ROLE_ID:-}"
CONTEXT_MODE="${AI_CONTEXT_MODE:-minimal}"
POSITIONAL=()

usage() {
  cat <<EOF
Usage: ./tool/ai_agent.sh [--project-root <path>] [--adapter <id>] [--role <id>] [--context-mode <minimal|full>] <agent> <task-file>

Examples:
  ./tool/ai_agent.sh router tasks/demo-1234-example.md
  ./tool/ai_agent.sh --project-root /path/to/project --adapter <project-adapter> --role <role-adapter> router tasks/example.md
  ./tool/ai_agent.sh --project-root /path/to/project --adapter <project-adapter> --role <role-adapter> --context-mode full router tasks/example.md
  ./tool/ai_agent.sh coding /abs/path/to/task.md
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --project-root)
      if [ "$#" -lt 2 ]; then
        echo "ERROR --project-root value is required" >&2
        exit 2
      fi
      PROJECT_ROOT="$2"
      shift 2
      ;;
    --adapter)
      if [ "$#" -lt 2 ]; then
        echo "ERROR --adapter value is required" >&2
        exit 2
      fi
      ADAPTER_ID="$2"
      shift 2
      ;;
    --role)
      if [ "$#" -lt 2 ]; then
        echo "ERROR --role value is required" >&2
        exit 2
      fi
      ROLE_ID="$2"
      shift 2
      ;;
    --context-mode)
      if [ "$#" -lt 2 ]; then
        echo "ERROR --context-mode value is required" >&2
        exit 2
      fi
      CONTEXT_MODE="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      POSITIONAL+=("$1")
      shift
      ;;
  esac
done

AGENT_KEY="${POSITIONAL[0]:-}"
TASK_INPUT="${POSITIONAL[1]:-}"

if [ -z "$AGENT_KEY" ] || [ -z "$TASK_INPUT" ]; then
  usage
  exit 1
fi

case "$CONTEXT_MODE" in
  minimal|full)
    ;;
  *)
    echo "ERROR context mode must be minimal or full: ${CONTEXT_MODE}" >&2
    exit 2
    ;;
esac

if [ -z "$PROJECT_ROOT" ]; then
  if [ -f "$(pwd)/AGENTS.md" ]; then
    PROJECT_ROOT="$(pwd)"
  elif [ -f "${AI_ROOT}/../AGENTS.md" ]; then
    PROJECT_ROOT="$(cd "${AI_ROOT}/.." && pwd)"
  else
    PROJECT_ROOT="$AI_ROOT"
  fi
fi

PROJECT_ROOT="$(cd "$PROJECT_ROOT" && pwd)"
ADAPTER_ID="$(ai_select_project_adapter_id "${AI_ROOT}/adapters" "$ADAPTER_ID" "$PROJECT_ROOT")" || exit $?
ROLE_ID="$(ai_select_profile_id "${AI_ROOT}/roles" "$ROLE_ID" "Role Adapter")" || exit $?

if [ ! -x "$LOADER" ]; then
  echo "Core Loader not found or not executable: ${LOADER}"
  exit 1
fi

TASKS_DIR="$(
  "$LOADER" \
    --project-root "$PROJECT_ROOT" \
    --adapter "$ADAPTER_ID" \
    --role "$ROLE_ID" \
    resolve runtime.tasks
)"

minimal_inline_keys=(role.profile)
case "$AGENT_KEY" in
  router)
    CORE_AGENT_KEY="router"
    minimal_inline_keys+=(adapter.context.router)
    ;;
  requirement|requirement_breakdown)
    CORE_AGENT_KEY="requirement_breakdown"
    minimal_inline_keys+=(
      adapter.context.architecture_sources
      adapter.context.current_project_reality
      adapter.context.source_of_truth
      adapter.context.regression_surfaces
    )
    ;;
  bugfix)
    CORE_AGENT_KEY="bugfix"
    minimal_inline_keys+=(
      adapter.risk_rules
      adapter.context.current_project_reality
      adapter.context.source_of_truth
      adapter.context.regression_surfaces
    )
    ;;
  architecture|architecture_boundary)
    CORE_AGENT_KEY="architecture_boundary"
    minimal_inline_keys+=(
      adapter.risk_rules
      adapter.context.architecture_sources
      adapter.context.current_project_reality
      adapter.context.source_of_truth
      adapter.context.regression_surfaces
    )
    ;;
  coding)
    CORE_AGENT_KEY="coding"
    minimal_inline_keys+=(
      adapter.commands
      adapter.context.architecture_sources
      adapter.context.current_project_reality
      adapter.context.source_of_truth
      adapter.context.regression_surfaces
    )
    ;;
  selftest|self_test)
    CORE_AGENT_KEY="self_test"
    minimal_inline_keys+=(
      adapter.commands
      adapter.gates
      adapter.risk_rules
      adapter.context.current_project_reality
      adapter.context.source_of_truth
      adapter.context.regression_surfaces
    )
    ;;
  review|pr_review)
    CORE_AGENT_KEY="pr_review"
    minimal_inline_keys+=(
      adapter.commands
      adapter.gates
      adapter.risk_rules
      adapter.context.architecture_sources
      adapter.context.current_project_reality
      adapter.context.source_of_truth
      adapter.context.regression_surfaces
    )
    ;;
  i18n|i18n_text_ui_risk)
    CORE_AGENT_KEY="i18n_text_ui_risk"
    minimal_inline_keys+=(
      adapter.commands
      adapter.i18n
      adapter.context.regression_surfaces
    )
    ;;
  commit)
    CORE_AGENT_KEY="commit"
    minimal_inline_keys+=(
      adapter.commands
      adapter.commit
    )
    ;;
  *)
    echo "Unknown agent: ${AGENT_KEY}"
    usage
    exit 1
    ;;
esac

AGENT_FILE="$(
  "$LOADER" \
    --project-root "$PROJECT_ROOT" \
    --adapter "$ADAPTER_ID" \
    --role "$ROLE_ID" \
    resolve "core.agent.${CORE_AGENT_KEY}"
)"

resolve_task_file() {
  local input="$1"

  if [ -f "$input" ]; then
    echo "$(cd "$(dirname "$input")" && pwd)/$(basename "$input")"
    return 0
  fi

  if [ -f "${AI_ROOT}/${input}" ]; then
    echo "${AI_ROOT}/${input}"
    return 0
  fi

  if [ -f "${TASKS_DIR}/${input}" ]; then
    echo "${TASKS_DIR}/${input}"
    return 0
  fi

  return 1
}

if [ ! -f "$AGENT_FILE" ]; then
  echo "Agent file not found: ${AGENT_FILE}"
  exit 1
fi

if ! TASK_FILE="$(resolve_task_file "$TASK_INPUT")"; then
  echo "Task file not found: ${TASK_INPUT}"
  echo "Checked:"
  echo "  - ${TASK_INPUT}"
  echo "  - ${AI_ROOT}/${TASK_INPUT}"
  echo "  - ${TASKS_DIR}/${TASK_INPUT}"
  exit 1
fi

cat <<EOF
# AI Agent Runner

## Agent
- key: ${AGENT_KEY}
- file: ${AGENT_FILE}
- project_root: ${PROJECT_ROOT}
- adapter: ${ADAPTER_ID}
- role: ${ROLE_ID}
- context_mode: ${CONTEXT_MODE}

## Task
- file: ${TASK_FILE}

## How To Use
将下面的 Core / Agent、Project Adapter、Role 和 Task 内容一起提供给 AI。
minimal 只内嵌当前 Agent 必需的 Adapter / Role 输入，并列出其余已解析输入；full 内嵌全部配置与上下文。
按 Loader 顺序阅读后，再按 Agent 要求开始工作。
EOF

cat <<EOF

===== AGENT =====
EOF
cat "$AGENT_FILE"

resolved_context_keys=(
  core.defaults
  core.extension_slots
  core.task_types
  core.registry
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
)

project_rules_file="$(
  "$LOADER" \
    --project-root "$PROJECT_ROOT" \
    --adapter "$ADAPTER_ID" \
    --role "$ROLE_ID" \
    resolve project.rules
)"
if [ -f "$project_rules_file" ]; then
  resolved_context_keys+=(project.rules)
fi

cat <<EOF

===== RESOLVED INPUTS =====
EOF
for context_key in "${resolved_context_keys[@]}"; do
  context_file="$(
    "$LOADER" \
      --project-root "$PROJECT_ROOT" \
      --adapter "$ADAPTER_ID" \
      --role "$ROLE_ID" \
      resolve "$context_key"
  )"
  if [ ! -f "$context_file" ]; then
    echo "Required Agent input not found: ${context_key} -> ${context_file}" >&2
    exit 1
  fi
  printf '%s=%s\n' "$context_key" "$context_file"
done

if [ "$CONTEXT_MODE" = "full" ]; then
  inline_keys=("${resolved_context_keys[@]}")
else
  inline_keys=("${minimal_inline_keys[@]}")
fi

for context_key in "${inline_keys[@]}"; do
  context_file="$(
    "$LOADER" \
      --project-root "$PROJECT_ROOT" \
      --adapter "$ADAPTER_ID" \
      --role "$ROLE_ID" \
      resolve "$context_key"
  )"
  cat <<EOF

===== ${context_key} =====
EOF
  cat "$context_file"
done

cat <<EOF

===== TASK =====
EOF

cat "$TASK_FILE"
