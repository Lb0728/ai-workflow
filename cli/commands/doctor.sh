#!/usr/bin/env bash
set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WORKFLOW_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
source "${WORKFLOW_ROOT}/cli/lib/host_adapter.sh"
source "${WORKFLOW_ROOT}/core/lib/task_card.sh"
PROJECT_ROOT="$(pwd)"
HOST_ID=""
ROLE_ID="developer"
REPORT=false

usage() {
  printf '%s\n' "Usage: ai-workflow doctor [--project-root <path>] [--host <id>] [--report]"
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --project-root)
      [ "$#" -ge 2 ] || { usage >&2; exit 2; }
      PROJECT_ROOT="$2"
      shift 2
      ;;
    --host)
      [ "$#" -ge 2 ] || { usage >&2; exit 2; }
      HOST_ID="$2"
      shift 2
      ;;
    --report)
      REPORT=true
      shift
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

lock_file="${PROJECT_ROOT}/.ai/ai.lock"
if [ -f "$lock_file" ]; then
  locked_role="$(host_lock_id "$lock_file" role)"
  [ -n "$locked_role" ] && ROLE_ID="$locked_role"
fi
HOST_ID="$(host_resolve_id "$WORKFLOW_ROOT" "$PROJECT_ROOT" "$HOST_ID")"
HOST_ROOT="${WORKFLOW_ROOT}/hosts/${HOST_ID}"
HOST_MANIFEST="${HOST_ROOT}/host.yaml"

ENTRY_FILENAME="$(host_required_scalar "$HOST_MANIFEST" instruction_entry filename)"
ENTRY_MARKER="$(host_required_scalar "$HOST_MANIFEST" instruction_entry verification_marker)"
SKILL_REPOSITORY="$(host_required_scalar "$HOST_MANIFEST" skill_locations repository)"
SKILL_METADATA_OWNER="$(host_manifest_scalar "$HOST_MANIFEST" skill_locations metadata_owner)"
SKILL_METADATA_TARGET="$(host_manifest_scalar "$HOST_MANIFEST" skill_locations metadata_target)"

host_validate_relative_path "$ENTRY_FILENAME" ||
  { printf '%s\n' "ERROR Host entry path is unsafe" >&2; exit 1; }
host_validate_relative_path "$SKILL_REPOSITORY" ||
  { printf '%s\n' "ERROR Host Skill path is unsafe" >&2; exit 1; }
if [ -n "$SKILL_METADATA_OWNER" ]; then
  host_validate_relative_path "$SKILL_METADATA_OWNER" ||
    { printf '%s\n' "ERROR Host metadata owner path is unsafe" >&2; exit 1; }
  host_validate_relative_path "$SKILL_METADATA_TARGET" ||
    { printf '%s\n' "ERROR Host metadata target path is unsafe" >&2; exit 1; }
fi

"${WORKFLOW_ROOT}/core/loader/ai_workflow_loader_v2.sh" \
  --project-root "$PROJECT_ROOT" --host "$HOST_ID" --role "$ROLE_ID" validate >/dev/null

[ -L "${PROJECT_ROOT}/.ai/workflow" ] || {
  printf '%s\n' "ERROR .ai/workflow symlink missing" >&2
  exit 1
}
[ -f "${PROJECT_ROOT}/.ai/hosts/${HOST_ID}/instructions.md" ] || {
  printf 'ERROR Host instructions missing: %s\n' "$HOST_ID" >&2
  exit 1
}
entry_file="${PROJECT_ROOT}/${ENTRY_FILENAME}"
[ -f "$entry_file" ] && grep -Fq "$ENTRY_MARKER" "$entry_file" || {
  printf 'ERROR Host entry missing or invalid: %s\n' "$ENTRY_FILENAME" >&2
  exit 1
}

for skill_root in "${WORKFLOW_ROOT}"/skills/*; do
  [ -d "$skill_root" ] || continue
  skill_name="$(basename "$skill_root")"
  skill_destination="${PROJECT_ROOT}/${SKILL_REPOSITORY}/${skill_name}"
  [ -f "${skill_destination}/.ai-workflow-v2-skill" ] &&
    [ -L "${skill_destination}/SKILL.md" ] || {
    printf 'ERROR repository Skill installation incomplete: %s\n' "$skill_name" >&2
    exit 1
  }
  if [ -n "$SKILL_METADATA_OWNER" ] &&
    [ ! -L "${skill_destination}/${SKILL_METADATA_TARGET}" ]; then
    printf 'ERROR Host Skill metadata installation incomplete: %s\n' \
      "$skill_name" >&2
    exit 1
  fi
done

if grep -R -E -n '/Users/|/Volumes/|token[[:space:]]*:|secret[[:space:]]*:|password[[:space:]]*:' \
  "${PROJECT_ROOT}/.ai/project.yaml" "${PROJECT_ROOT}/.ai/ai.lock" 2>/dev/null | grep -q .; then
  printf '%s\n' "ERROR generated metadata contains a personal path or sensitive field" >&2
  exit 1
fi

# Task card schema scan: every runtime task must satisfy the schema.
TASKS_DIR="$("${WORKFLOW_ROOT}/core/loader/ai_workflow_loader_v2.sh" \
  --project-root "$PROJECT_ROOT" --host "$HOST_ID" --role "$ROLE_ID" \
  resolve runtime.tasks)"
task_errors=0
if [ -d "$TASKS_DIR" ]; then
  while IFS= read -r task_file; do
    task_violations="$(tc_validate "$task_file")" || {
      task_errors=$((task_errors + 1))
      printf 'ERROR task schema %s:\n' "$(basename "$task_file")" >&2
      printf '%s\n' "$task_violations" >&2
    }
  done < <(find "$TASKS_DIR" -maxdepth 1 -name '*.md' -type f | sort)
fi
if [ "$task_errors" -gt 0 ]; then
  printf 'ERROR %d task card(s) failed schema validation\n' "$task_errors" >&2
  exit 1
fi

printf '%s\n' "V2 doctor: PASS"
printf 'Host: %s\n' "$HOST_ID"
printf '%s\n' "Checks: loader, immutable policy, project profile, lock, Host entry, Skills, task card schema"
printf '%s\n' "Project build/test commands: NOT RUN"

if [ "$REPORT" = true ]; then
  "${SCRIPT_DIR}/feedback.sh" --project-root "$PROJECT_ROOT"
fi
