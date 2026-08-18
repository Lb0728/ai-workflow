#!/usr/bin/env bash
set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WORKFLOW_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
source "${SCRIPT_DIR}/ai_profile_select.sh"

PROJECT_ROOT=""
ADAPTER_ID="${AI_ADAPTER_ID:-}"
MANIFEST_ARG=""
TASK_FILE=""
ROLE_ID="developer"
failures=0

usage() {
  cat <<'EOF'
Usage:
  ./ai/tool/ai_developer_pilot_check.sh --project-root <path> [--adapter <id>] [--manifest <id-or-path>] [--task <task-file>]

The check is read-only. When --task is provided, it also verifies Router
assembly for that task.
EOF
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
    --manifest)
      MANIFEST_ARG="${2:-}"
      shift 2
      ;;
    --task)
      TASK_FILE="${2:-}"
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

if [ -z "$PROJECT_ROOT" ] || [ ! -d "$PROJECT_ROOT" ]; then
  printf '%s\n' "ERROR --project-root must point to an existing project" >&2
  exit 2
fi

PROJECT_ROOT="$(cd "$PROJECT_ROOT" && pwd)"
ADAPTER_ID="$(ai_select_project_adapter_id "${WORKFLOW_ROOT}/adapters" "$ADAPTER_ID" "$PROJECT_ROOT")" || exit $?

printf '%s\n' "# Developer Pilot Check"
printf 'project_root=%s\n' "$PROJECT_ROOT"
printf 'adapter=%s\n' "$ADAPTER_ID"
printf 'role=%s\n' "$ROLE_ID"

if LC_ALL="${LC_ALL:-en_US.UTF-8}" LANG="${LANG:-en_US.UTF-8}" \
  "${SCRIPT_DIR}/ai_setup_check.sh" \
    --project-root "$PROJECT_ROOT" \
    --adapter "$ADAPTER_ID" \
    --role "$ROLE_ID"; then
  printf '%s\n' "PASS setup"
else
  printf '%s\n' "ERROR setup"
  failures=$((failures + 1))
fi

if [ -n "$MANIFEST_ARG" ]; then
  distribution_args=(--manifest "$MANIFEST_ARG" --adapter "$ADAPTER_ID" --role "$ROLE_ID")
else
  distribution_args=(--adapter "$ADAPTER_ID" --role "$ROLE_ID")
fi

if "${SCRIPT_DIR}/ai_distribution_check.sh" "${distribution_args[@]}"; then
  printf '%s\n' "PASS distribution boundary"
else
  printf '%s\n' "ERROR distribution boundary"
  failures=$((failures + 1))
fi

if [ -n "$TASK_FILE" ]; then
  if [ ! -f "$TASK_FILE" ]; then
    printf 'ERROR task file not found: %s\n' "$TASK_FILE"
    failures=$((failures + 1))
  elif router_output="$(
    "${SCRIPT_DIR}/ai_agent.sh" \
      --project-root "$PROJECT_ROOT" \
      --adapter "$ADAPTER_ID" \
      --role "$ROLE_ID" \
      router \
      "$TASK_FILE"
  )" && printf '%s\n' "$router_output" | grep -F -q -- "- adapter: ${ADAPTER_ID}"; then
    printf '%s\n' "PASS Router assembly"
  else
    printf '%s\n' "ERROR Router assembly"
    failures=$((failures + 1))
  fi
else
  printf '%s\n' "SKIP Router assembly; pass --task after creating a pilot task"
fi

if [ "$failures" -gt 0 ]; then
  printf 'RESULT FAIL errors=%d\n' "$failures"
  exit 1
fi

printf '%s\n' "RESULT PASS errors=0"
