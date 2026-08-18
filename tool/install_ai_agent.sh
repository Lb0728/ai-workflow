#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WORKFLOW_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
source "${SCRIPT_DIR}/ai_profile_select.sh"

CLIENT_ID=""
PROJECT_ROOT=""
ADAPTER_ID="${AI_ADAPTER_ID:-}"
ROLE_ID="${AI_ROLE_ID:-developer}"

SKILLS=(
  "grill-me"
  "grill-with-docs"
  "to-prd"
  "to-task-cards"
  "handoff"
)

usage() {
  cat <<'EOF'
Usage:
  bash tool/install_ai_agent.sh \
    --client <codex|cursor|claude-code> \
    [--project-root <path>] \
    [--adapter <id>] \
    [--role <id>]

When --project-root is omitted, the current directory is used. The installer
links this workflow package into <project-root>/ai, auto-detects the Project
Adapter, installs the shared Skills for the selected client, installs the
client's minimal persistent rule when required, creates an isolated project
Runtime, then runs the setup check.
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --client)
      CLIENT_ID="${2:-}"
      shift 2
      ;;
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

if [ -z "$CLIENT_ID" ]; then
  printf '%s\n' "ERROR --client is required" >&2
  usage >&2
  exit 2
fi

if [ -z "$PROJECT_ROOT" ]; then
  PROJECT_ROOT="$(pwd)"
fi
if [ ! -d "$PROJECT_ROOT" ]; then
  printf 'ERROR project root not found: %s\n' "$PROJECT_ROOT" >&2
  exit 1
fi
PROJECT_ROOT="$(cd "$PROJECT_ROOT" && pwd)"

if [ ! -f "${WORKFLOW_ROOT}/integrations/${CLIENT_ID}/integration-profile.yaml" ]; then
  printf 'ERROR unsupported client integration: %s\n' "$CLIENT_ID" >&2
  exit 2
fi

ADAPTER_ID="$(ai_select_project_adapter_id "${WORKFLOW_ROOT}/adapters" "$ADAPTER_ID" "$PROJECT_ROOT")" || exit $?
ROLE_ID="$(ai_select_profile_id "${WORKFLOW_ROOT}/roles" "$ROLE_ID" "Role Adapter")" || exit $?

case "$CLIENT_ID" in
  codex)
    CLIENT_SKILLS_DIR="${HOME}/.agents/skills"
    RULE_SOURCE=""
    RULE_TARGET=""
    ;;
  cursor)
    CLIENT_SKILLS_DIR="${HOME}/.cursor/skills"
    RULE_SOURCE="${WORKFLOW_ROOT}/integrations/cursor/rules/ai-workflow.mdc"
    RULE_TARGET="${PROJECT_ROOT}/.cursor/rules/ai-workflow.mdc"
    ;;
  claude-code)
    CLIENT_SKILLS_DIR="${HOME}/.claude/skills"
    RULE_SOURCE="${WORKFLOW_ROOT}/integrations/claude-code/rules/ai-workflow.md"
    RULE_TARGET="${PROJECT_ROOT}/.claude/rules/ai-workflow.md"
    ;;
  *)
    printf 'ERROR unsupported client integration: %s\n' "$CLIENT_ID" >&2
    exit 2
    ;;
esac

link_path() {
  local source="$1"
  local target="$2"

  if [ -e "$target" ] && [ ! -L "$target" ]; then
    printf 'ERROR target exists and is not a symlink: %s\n' "$target" >&2
    printf '%s\n' "Move it manually or select another installation target." >&2
    exit 1
  fi

  mkdir -p "$(dirname "$target")"
  ln -sfn "$source" "$target"
  printf 'OK %s -> %s\n' "$target" "$source"
}

add_local_git_exclude() {
  local relative_path="$1"
  local git_path=""
  local exclude_file=""

  if ! git -C "$PROJECT_ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    return 0
  fi

  git_path="$(git -C "$PROJECT_ROOT" rev-parse --git-path info/exclude)"
  case "$git_path" in
    /*)
      exclude_file="$git_path"
      ;;
    *)
      exclude_file="${PROJECT_ROOT}/${git_path}"
      ;;
  esac

  mkdir -p "$(dirname "$exclude_file")"
  if [ ! -f "$exclude_file" ] || ! grep -F -x -q "$relative_path" "$exclude_file"; then
    printf '%s\n' "$relative_path" >> "$exclude_file"
  fi
}

for skill in "${SKILLS[@]}"; do
  if [ ! -f "${WORKFLOW_ROOT}/skills/${skill}/SKILL.md" ]; then
    printf 'ERROR missing Skill source: %s\n' "${WORKFLOW_ROOT}/skills/${skill}/SKILL.md" >&2
    exit 1
  fi
done

printf '%s\n' "# Install AI Agent"
printf 'workflow_root=%s\n' "$WORKFLOW_ROOT"
printf 'project_root=%s\n' "$PROJECT_ROOT"
printf 'adapter=%s\n' "$ADAPTER_ID"
printf 'role=%s\n' "$ROLE_ID"
printf 'client=%s\n' "$CLIENT_ID"

link_path "$WORKFLOW_ROOT" "${PROJECT_ROOT}/ai"
add_local_git_exclude "/ai"

PROJECT_RUNTIME_ROOT="${PROJECT_ROOT}/.ai-runtime"
if [ -e "$PROJECT_RUNTIME_ROOT" ] && [ ! -d "$PROJECT_RUNTIME_ROOT" ]; then
  printf 'ERROR project Runtime target exists and is not a directory: %s\n' \
    "$PROJECT_RUNTIME_ROOT" >&2
  exit 1
fi
mkdir -p \
  "${PROJECT_RUNTIME_ROOT}/tasks" \
  "${PROJECT_RUNTIME_ROOT}/states" \
  "${PROJECT_RUNTIME_ROOT}/handoffs" \
  "${PROJECT_RUNTIME_ROOT}/closeouts" \
  "${PROJECT_RUNTIME_ROOT}/defects"
add_local_git_exclude "/.ai-runtime/"
printf 'OK project_runtime=%s\n' "$PROJECT_RUNTIME_ROOT"

DEFAULT_PROJECT_RULES="${WORKFLOW_ROOT}/adapters/${ADAPTER_ID}/project-rules/AGENTS.md"
if [ ! -e "${PROJECT_ROOT}/AGENTS.md" ] &&
    [ ! -L "${PROJECT_ROOT}/AGENTS.md" ] &&
    [ -f "$DEFAULT_PROJECT_RULES" ]; then
  link_path "$DEFAULT_PROJECT_RULES" "${PROJECT_ROOT}/AGENTS.md"
  add_local_git_exclude "/AGENTS.md"
  printf '%s\n' "INFO installed Adapter default AGENTS.md because the project did not provide one"
else
  printf '%s\n' "INFO preserved existing project AGENTS.md"
fi

for skill in "${SKILLS[@]}"; do
  link_path "${WORKFLOW_ROOT}/skills/${skill}" "${CLIENT_SKILLS_DIR}/${skill}"
done

if [ -n "$RULE_SOURCE" ]; then
  link_path "$RULE_SOURCE" "$RULE_TARGET"
  case "$RULE_TARGET" in
    "${PROJECT_ROOT}"/*)
      add_local_git_exclude "/${RULE_TARGET#${PROJECT_ROOT}/}"
      ;;
  esac
fi

LC_ALL="${LC_ALL:-en_US.UTF-8}" LANG="${LANG:-en_US.UTF-8}" \
  "${WORKFLOW_ROOT}/tool/ai_setup_check.sh" \
    --project-root "$PROJECT_ROOT" \
    --adapter "$ADAPTER_ID" \
    --role "$ROLE_ID"

printf '%s\n' "RESULT PASS errors=0"
