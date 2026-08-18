#!/usr/bin/env bash
set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WORKFLOW_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
source "${WORKFLOW_ROOT}/cli/lib/host_adapter.sh"
PROJECT_ROOT="$(pwd)"
HOST_ID=""
ROLE_ID="developer"
RUN_DOCTOR=true

usage() {
  cat <<'EOF'
Usage: ai-workflow init [--project-root <path>] [--host <id>] [--role developer] [--no-doctor]

On first initialization, --host is required. Re-initialization may read Host
selection from the target project's .ai/ai.lock.
EOF
}

append_local_exclude() {
  local entry="$1"
  local exclude_file="${PROJECT_ROOT}/.git/info/exclude"
  [ -d "${PROJECT_ROOT}/.git/info" ] || return 0
  if ! grep -Fqx "$entry" "$exclude_file" 2>/dev/null; then
    printf '%s\n' "$entry" >> "$exclude_file"
  fi
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
    --role)
      [ "$#" -ge 2 ] || { usage >&2; exit 2; }
      ROLE_ID="$2"
      shift 2
      ;;
    --no-doctor)
      RUN_DOCTOR=false
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
[ -f "${WORKFLOW_ROOT}/roles/${ROLE_ID}/role-profile.yaml" ] || {
  printf 'ERROR unsupported role: %s\n' "$ROLE_ID" >&2
  exit 1
}
HOST_ID="$(host_resolve_id "$WORKFLOW_ROOT" "$PROJECT_ROOT" "$HOST_ID")"
HOST_ROOT="${WORKFLOW_ROOT}/hosts/${HOST_ID}"
HOST_MANIFEST="${HOST_ROOT}/host.yaml"

ENTRY_FILENAME="$(host_required_scalar "$HOST_MANIFEST" instruction_entry filename)"
ENTRY_TEMPLATE_REL="$(host_required_scalar "$HOST_MANIFEST" instruction_entry template)"
INSTRUCTIONS_TEMPLATE_REL="$(host_required_scalar "$HOST_MANIFEST" instruction_entry instructions_template)"
ENTRY_INSTALL_MODE="$(host_required_scalar "$HOST_MANIFEST" instruction_entry install_mode)"
ENTRY_MARKER="$(host_required_scalar "$HOST_MANIFEST" instruction_entry verification_marker)"
SKILL_REPOSITORY="$(host_required_scalar "$HOST_MANIFEST" skill_locations repository)"
SKILL_SOURCE_OWNER="$(host_required_scalar "$HOST_MANIFEST" skill_locations source_owner)"
SKILL_METADATA_OWNER="$(host_manifest_scalar "$HOST_MANIFEST" skill_locations metadata_owner)"
SKILL_METADATA_TARGET="$(host_manifest_scalar "$HOST_MANIFEST" skill_locations metadata_target)"

for host_relative_path in \
  "$ENTRY_FILENAME" "$ENTRY_TEMPLATE_REL" "$INSTRUCTIONS_TEMPLATE_REL" \
  "$SKILL_REPOSITORY" "$SKILL_SOURCE_OWNER"; do
  host_validate_relative_path "$host_relative_path" || {
    printf 'ERROR Host manifest contains an unsafe relative path: %s\n' \
      "$host_relative_path" >&2
    exit 1
  }
done
if [ -n "$SKILL_METADATA_OWNER" ]; then
  host_validate_relative_path "$SKILL_METADATA_OWNER" || {
    printf '%s\n' "ERROR Host manifest contains an unsafe metadata owner path" >&2
    exit 1
  }
  host_validate_relative_path "$SKILL_METADATA_TARGET" || {
    printf '%s\n' "ERROR Host manifest contains an unsafe metadata target path" >&2
    exit 1
  }
fi

[ "$SKILL_SOURCE_OWNER" = "skills" ] || {
  printf '%s\n' "ERROR Host Skill source_owner must be canonical skills" >&2
  exit 1
}
[ -f "${HOST_ROOT}/${ENTRY_TEMPLATE_REL}" ] || {
  printf '%s\n' "ERROR Host entry template missing" >&2
  exit 1
}
[ -f "${HOST_ROOT}/${INSTRUCTIONS_TEMPLATE_REL}" ] || {
  printf '%s\n' "ERROR Host instructions template missing" >&2
  exit 1
}

PROJECT_AI_ROOT="${PROJECT_ROOT}/.ai"
profile_snapshot="$(mktemp "${TMPDIR:-/tmp}/ai-workflow-project-profile.XXXXXX")"
cleanup_profile_snapshot() {
  [ -z "$profile_snapshot" ] || rm -f "$profile_snapshot"
}
trap cleanup_profile_snapshot EXIT

"${WORKFLOW_ROOT}/discovery/generators/generate_project_profile.sh" \
  --project-root "$PROJECT_ROOT" \
  --output "$profile_snapshot"

mkdir -p \
  "${PROJECT_AI_ROOT}/architecture" \
  "${PROJECT_AI_ROOT}/risks" \
  "${PROJECT_AI_ROOT}/defects" \
  "${PROJECT_AI_ROOT}/policies" \
  "${PROJECT_AI_ROOT}/hosts/${HOST_ID}" \
  "${PROJECT_AI_ROOT}/runtime/tasks" \
  "${PROJECT_AI_ROOT}/runtime/states" \
  "${PROJECT_AI_ROOT}/runtime/handoffs" \
  "${PROJECT_AI_ROOT}/runtime/closeouts" \
  "${PROJECT_AI_ROOT}/runtime/defects" \
  "${PROJECT_ROOT}/${SKILL_REPOSITORY}" \
  "$(dirname "${PROJECT_ROOT}/${ENTRY_FILENAME}")"

for keep_dir in \
  architecture risks defects policies \
  runtime/tasks runtime/states runtime/handoffs runtime/closeouts runtime/defects; do
  if [ ! -e "${PROJECT_AI_ROOT}/${keep_dir}/.gitkeep" ]; then
    : > "${PROJECT_AI_ROOT}/${keep_dir}/.gitkeep"
  fi
done

if [ -e "${PROJECT_AI_ROOT}/workflow" ] || [ -L "${PROJECT_AI_ROOT}/workflow" ]; then
  if [ ! -L "${PROJECT_AI_ROOT}/workflow" ]; then
    printf '%s\n' "ERROR .ai/workflow exists and is not a symlink" >&2
    exit 1
  fi
  current_workflow="$(readlink "${PROJECT_AI_ROOT}/workflow")"
  if [ "$current_workflow" != "$WORKFLOW_ROOT" ]; then
    rm "${PROJECT_AI_ROOT}/workflow"
    ln -s "$WORKFLOW_ROOT" "${PROJECT_AI_ROOT}/workflow"
  fi
else
  ln -s "$WORKFLOW_ROOT" "${PROJECT_AI_ROOT}/workflow"
fi

mv "$profile_snapshot" "${PROJECT_AI_ROOT}/project.yaml"
profile_snapshot=""

workflow_version="$(tr -d '\r\n' < "${WORKFLOW_ROOT}/VERSION")"
workflow_commit="package"
if git -C "$WORKFLOW_ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  workflow_commit="$(git -C "$WORKFLOW_ROOT" rev-parse HEAD 2>/dev/null || printf '%s' unknown)"
  if ! git -C "$WORKFLOW_ROOT" diff --quiet --ignore-submodules -- 2>/dev/null ||
    ! git -C "$WORKFLOW_ROOT" diff --cached --quiet --ignore-submodules -- 2>/dev/null ||
    [ -n "$(git -C "$WORKFLOW_ROOT" ls-files --others --exclude-standard 2>/dev/null)" ]; then
    workflow_commit="${workflow_commit}-dirty"
  fi
fi

lock_temp="${PROJECT_AI_ROOT}/ai.lock.tmp.$$"
{
  printf '%s\n' "schema_version: 1"
  printf '%s\n' "workflow:"
  printf "  version: '%s'\n" "$workflow_version"
  printf "  source_commit: '%s'\n" "$workflow_commit"
  printf '%s\n' "host:"
  printf "  id: '%s'\n" "$HOST_ID"
  printf '%s\n' "role:"
  printf "  id: '%s'\n" "$ROLE_ID"
  printf '%s\n' "project_profile:"
  printf '%s\n' "  version: 1"
} > "$lock_temp"
mv "$lock_temp" "${PROJECT_AI_ROOT}/ai.lock"

cp "${HOST_ROOT}/${INSTRUCTIONS_TEMPLATE_REL}" \
  "${PROJECT_AI_ROOT}/hosts/${HOST_ID}/instructions.md"

relative_link_target() {
  local link_path="$1"
  local target_path="$2"
  local parent_path
  local prefix=""
  parent_path="$(dirname "$link_path")"
  while [ "$parent_path" != "." ]; do
    prefix="../${prefix}"
    parent_path="$(dirname "$parent_path")"
  done
  printf '%s%s\n' "$prefix" "$target_path"
}

for skill_root in "${WORKFLOW_ROOT}"/skills/*; do
  [ -d "$skill_root" ] || continue
  skill_name="$(basename "$skill_root")"
  skill_destination="${PROJECT_ROOT}/${SKILL_REPOSITORY}/${skill_name}"
  skill_marker="${skill_destination}/.ai-workflow-v2-skill"
  if [ -L "$skill_destination" ]; then
    rm "$skill_destination"
  elif [ -e "$skill_destination" ] && [ ! -f "$skill_marker" ]; then
    printf 'ERROR Skill destination exists and is not V2-managed: %s/%s\n' \
      "$SKILL_REPOSITORY" "$skill_name" >&2
    exit 1
  fi
  mkdir -p "$skill_destination"
  : > "$skill_marker"
  for skill_entry in "$skill_root"/*; do
    [ -e "$skill_entry" ] || continue
    entry_name="$(basename "$skill_entry")"
    [ "$entry_name" = "agents" ] && continue
    entry_link="${skill_destination}/${entry_name}"
    entry_relative="${SKILL_REPOSITORY}/${skill_name}/${entry_name}"
    entry_target=".ai/workflow/skills/${skill_name}/${entry_name}"
    [ -e "$entry_link" ] || [ -L "$entry_link" ] || \
      ln -s "$(relative_link_target "$entry_relative" "$entry_target")" "$entry_link"
  done
  if [ -n "$SKILL_METADATA_OWNER" ]; then
    metadata_source="${WORKFLOW_ROOT}/${SKILL_METADATA_OWNER}/${skill_name}/$(basename "$SKILL_METADATA_TARGET")"
    [ -f "$metadata_source" ] || {
      printf 'ERROR Host Skill metadata missing: %s\n' "$skill_name" >&2
      exit 1
    }
    metadata_link="${skill_destination}/${SKILL_METADATA_TARGET}"
    metadata_relative="${SKILL_REPOSITORY}/${skill_name}/${SKILL_METADATA_TARGET}"
    metadata_target=".ai/workflow/${SKILL_METADATA_OWNER}/${skill_name}/$(basename "$SKILL_METADATA_TARGET")"
    mkdir -p "$(dirname "$metadata_link")"
    if [ ! -e "$metadata_link" ] && [ ! -L "$metadata_link" ]; then
      ln -s "$(relative_link_target "$metadata_relative" "$metadata_target")" \
        "$metadata_link"
    fi
  fi
done

entry_file="${PROJECT_ROOT}/${ENTRY_FILENAME}"
entry_template="${HOST_ROOT}/${ENTRY_TEMPLATE_REL}"
case "$ENTRY_INSTALL_MODE" in
  managed_block)
    if [ ! -f "$entry_file" ]; then
      cp "$entry_template" "$entry_file"
    elif ! grep -Fq "$ENTRY_MARKER" "$entry_file"; then
      printf '\n' >> "$entry_file"
      sed -n '1,$p' "$entry_template" >> "$entry_file"
    fi
    ;;
  managed_file)
    if [ -e "$entry_file" ] && ! grep -Fq "$ENTRY_MARKER" "$entry_file"; then
      printf 'ERROR Host entry exists and is not V2-managed: %s\n' \
        "$ENTRY_FILENAME" >&2
      exit 1
    fi
    cp "$entry_template" "$entry_file"
    ;;
  *)
    printf 'ERROR unsupported Host entry install mode: %s\n' \
      "$ENTRY_INSTALL_MODE" >&2
    exit 1
    ;;
esac

append_local_exclude ".ai/workflow"
append_local_exclude ".ai/runtime/"
append_local_exclude "${SKILL_REPOSITORY}/"

printf '%s\n' "V2 initialization: COMPLETE"
printf '%s\n' "Project profile: .ai/project.yaml"
printf '%s\n' "Lock: .ai/ai.lock"
printf '%s\n' "Host: ${HOST_ID}"
printf '%s\n' "Role: ${ROLE_ID}"

if [ "$RUN_DOCTOR" = true ]; then
  "${SCRIPT_DIR}/doctor.sh" --project-root "$PROJECT_ROOT" --host "$HOST_ID"
fi
