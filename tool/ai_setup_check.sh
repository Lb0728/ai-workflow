#!/usr/bin/env bash
set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WORKFLOW_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
source "${SCRIPT_DIR}/ai_profile_select.sh"

PROJECT_ROOT="${AI_PROJECT_ROOT:-}"
ADAPTER_ID="${AI_ADAPTER_ID:-}"
ROLE_ID="${AI_ROLE_ID:-}"
failures=0

usage() {
  printf '%s\n' "Usage: ./tool/ai_setup_check.sh [--project-root <path>] [--adapter <id>] [--role <id>]"
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
      printf 'ERROR unknown argument: %s\n' "$1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [ -z "$PROJECT_ROOT" ]; then
  PROJECT_ROOT="$(pwd)"
fi

PROJECT_ROOT="$(cd "$PROJECT_ROOT" && pwd)"
ADAPTER_ID="$(ai_select_project_adapter_id "${WORKFLOW_ROOT}/adapters" "$ADAPTER_ID" "$PROJECT_ROOT")" || exit $?
ROLE_ID="$(ai_select_profile_id "${WORKFLOW_ROOT}/roles" "$ROLE_ID" "Role Adapter")" || exit $?

printf '%s\n' "# AI Workflow Setup Check"

if LC_ALL="${LC_ALL:-en_US.UTF-8}" LANG="${LANG:-en_US.UTF-8}" \
  "${SCRIPT_DIR}/ai_core_doctor.sh" \
    --project-root "$PROJECT_ROOT" \
    --adapter "$ADAPTER_ID" \
    --role "$ROLE_ID"; then
  printf '%s\n' "PASS Core / Adapter / Role / Runtime setup"
else
  printf '%s\n' "ERROR Core / Adapter / Role / Runtime setup"
  failures=$((failures + 1))
fi

for skill_dir in "${WORKFLOW_ROOT}"/skills/*; do
  if [ ! -d "$skill_dir" ]; then
    continue
  fi
  if [ -f "${skill_dir}/SKILL.md" ]; then
    printf 'PASS Skill source %s\n' "$(basename "$skill_dir")"
  else
    printf 'ERROR Skill source missing SKILL.md: %s\n' "$skill_dir"
    failures=$((failures + 1))
  fi
done

for tool_file in \
  ai_agent.sh \
  ai_loop_new.sh \
  ai_loop_next.sh \
  ai_loop_status.sh \
  ai_distribution_check.sh \
  ai_distribution_package.sh \
  install_ai_agent.sh \
  ai_developer_pilot_check.sh; do
  if [ -x "${SCRIPT_DIR}/${tool_file}" ]; then
    printf 'PASS executable tool %s\n' "$tool_file"
  else
    printf 'ERROR executable tool missing: %s\n' "$tool_file"
    failures=$((failures + 1))
  fi
done

if [ "$failures" -gt 0 ]; then
  printf 'RESULT FAIL errors=%d\n' "$failures"
  exit 1
fi

printf '%s\n' "RESULT PASS errors=0"
