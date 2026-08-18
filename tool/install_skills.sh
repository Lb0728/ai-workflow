#!/usr/bin/env bash
set -euo pipefail

PRIVATE_REPO="$(cd "$(dirname "$0")/.." && pwd)"
GLOBAL_SKILLS_DIR="${HOME}/.agents/skills"
PROJECT_REPO="${1:-}"

SKILLS=(
  "grill-me"
  "grill-with-docs"
  "to-prd"
  "to-task-cards"
  "handoff"
)

usage() {
  cat <<USAGE
Usage:
  bash tool/install_skills.sh [project_repo_path]

Examples:
  bash tool/install_skills.sh
  bash tool/install_skills.sh /path/to/project

This script links Codex runtime skills from:
  ${PRIVATE_REPO}/skills

Into:
  ${GLOBAL_SKILLS_DIR}

If project_repo_path is provided, it also links:
  <project_repo_path>/ai -> ${PRIVATE_REPO}
USAGE
}

link_path() {
  local source="$1"
  local target="$2"

  if [[ -e "${target}" && ! -L "${target}" ]]; then
    echo "ERROR: target exists and is not a symlink: ${target}" >&2
    echo "Move or remove it manually, then rerun this script." >&2
    exit 1
  fi

  ln -sfn "${source}" "${target}"
  echo "OK ${target} -> ${source}"
}

if [[ "${PROJECT_REPO}" == "-h" || "${PROJECT_REPO}" == "--help" ]]; then
  usage
  exit 0
fi

if [[ ! -d "${PRIVATE_REPO}/skills" ]]; then
  echo "ERROR: skills directory not found: ${PRIVATE_REPO}/skills" >&2
  exit 1
fi

for skill in "${SKILLS[@]}"; do
  if [[ ! -f "${PRIVATE_REPO}/skills/${skill}/SKILL.md" ]]; then
    echo "ERROR: missing skill source: ${PRIVATE_REPO}/skills/${skill}/SKILL.md" >&2
    exit 1
  fi
done

mkdir -p "${GLOBAL_SKILLS_DIR}"

echo "# Install Codex skills"
echo
echo "Private repo: ${PRIVATE_REPO}"
echo "Runtime skills: ${GLOBAL_SKILLS_DIR}"
echo

for skill in "${SKILLS[@]}"; do
  source="${PRIVATE_REPO}/skills/${skill}"
  target="${GLOBAL_SKILLS_DIR}/${skill}"
  link_path "${source}" "${target}"
done

if [[ -n "${PROJECT_REPO}" ]]; then
  if [[ ! -d "${PROJECT_REPO}" ]]; then
    echo "ERROR: project_repo_path not found: ${PROJECT_REPO}" >&2
    exit 1
  fi

  link_path "${PRIVATE_REPO}" "${PROJECT_REPO}/ai"

  if [[ -x "${PROJECT_REPO}/ai/tool/ai_setup_check.sh" ]]; then
    echo
    bash "${PROJECT_REPO}/ai/tool/ai_setup_check.sh" --project-root "${PROJECT_REPO}"
  fi
else
  echo
  echo "Skipped project ai link. Pass project_repo_path to create it."
fi
