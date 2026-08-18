#!/usr/bin/env bash
set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WORKFLOW_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
PROJECT_ROOT="$(pwd)"
TASK_FILE=""

usage() {
  printf '%s\n' "Usage: ai-workflow feedback [--project-root <path>] [--task <task-file>]"
}

safe_value() {
  local value="$1"
  case "$value" in
    *[!A-Za-z0-9_.-]*|'') printf '%s\n' "unknown" ;;
    *) printf '%s\n' "$value" ;;
  esac
}

task_field() {
  local key="$1"
  local value
  [ -n "$TASK_FILE" ] && [ -f "$TASK_FILE" ] || { printf '%s\n' "unknown"; return; }
  value="$(awk -F: -v wanted="$key" '$1 == wanted {sub(/^[[:space:]]*/, "", $2); print $2; exit}' "$TASK_FILE")"
  safe_value "$value"
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --project-root)
      [ "$#" -ge 2 ] || { usage >&2; exit 2; }
      PROJECT_ROOT="$2"
      shift 2
      ;;
    --task)
      [ "$#" -ge 2 ] || { usage >&2; exit 2; }
      TASK_FILE="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      printf 'ERROR unknown argument: %s\n' "$1" >&2
      exit 2
      ;;
  esac
done

[ -d "$PROJECT_ROOT" ] || { printf '%s\n' "ERROR project root not found" >&2; exit 1; }
PROJECT_ROOT="$(cd "$PROJECT_ROOT" && pwd)"
profile_file="${PROJECT_ROOT}/.ai/project.yaml"
lock_file="${PROJECT_ROOT}/.ai/ai.lock"
[ -f "$profile_file" ] && [ -f "$lock_file" ] || {
  printf '%s\n' "ERROR V2 project profile or lock missing" >&2
  exit 1
}

project_kind="$(awk '/detected_kind:/{gsub(/['"'"'"]/, "", $2); print $2; exit}' "$profile_file")"
host_id="$(awk '/^host:/{active=1;next} active && /^[^ ]/{active=0} active && /id:/{gsub(/['"'"'"]/, "", $2); print $2; exit}' "$lock_file")"
role_id="$(awk '/^role:/{active=1;next} active && /^[^ ]/{active=0} active && /id:/{gsub(/['"'"'"]/, "", $2); print $2; exit}' "$lock_file")"
profile_version="$(awk '/^profile:/{active=1;next} active && /^[^ ]/{active=0} active && /version:/{print $2; exit}' "$profile_file")"
workflow_version="$(safe_value "$(tr -d '\r\n' < "${WORKFLOW_ROOT}/VERSION")")"
host_version="$(awk '/^schema_version:/{print $2; exit}' "${WORKFLOW_ROOT}/hosts/${host_id}/host.yaml")"

printf '%s\n' "schema_version: 1"
printf '%s\n' "workflow:"
printf "  version: '%s'\n" "$workflow_version"
printf "  core_version: '%s'\n" "$workflow_version"
printf '%s\n' "host:"
printf "  id: '%s'\n" "$(safe_value "$host_id")"
printf "  version: '%s'\n" "$(safe_value "$host_version")"
printf '%s\n' "role:"
printf "  id: '%s'\n" "$(safe_value "$role_id")"
printf '%s\n' "project:"
printf "  stack: ['%s']\n" "$(safe_value "$project_kind")"
printf "  profile_version: '%s'\n" "$(safe_value "$profile_version")"
printf '%s\n' "task:"
printf "  type: '%s'\n" "$(task_field task_type)"
printf "  risk: '%s'\n" "$(task_field risk_level)"
printf "  stage: '%s'\n" "$(task_field current_stage)"
