#!/usr/bin/env bash
set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WORKFLOW_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
LEGACY_ROOT="${AI_WORKFLOW_V1_ROOT:-$WORKFLOW_ROOT}"
PROJECT_ROOT=""
USE_V2="${AI_WORKFLOW_V2:-}"

args=("$@")
index=0
while [ "$index" -lt "${#args[@]}" ]; do
  if [ "${args[$index]}" = "--project-root" ] && [ $((index + 1)) -lt "${#args[@]}" ]; then
    PROJECT_ROOT="${args[$((index + 1))]}"
    break
  fi
  index=$((index + 1))
done

if [ "$USE_V2" = "1" ]; then
  exec "${WORKFLOW_ROOT}/core/loader/ai_workflow_loader_v2.sh" "$@"
fi

if [ -n "$PROJECT_ROOT" ] &&
  [ -f "${PROJECT_ROOT}/.ai/project.yaml" ] &&
  [ -f "${PROJECT_ROOT}/.ai/ai.lock" ]; then
  exec "${WORKFLOW_ROOT}/core/loader/ai_workflow_loader_v2.sh" "$@"
fi

if [ ! -x "${LEGACY_ROOT}/tool/ai_core_loader.sh" ]; then
  printf '%s\n' \
    "ERROR V1 source is not bundled; set AI_WORKFLOW_V1_ROOT to the existing V1 installation" >&2
  exit 1
fi

exec "${LEGACY_ROOT}/tool/ai_core_loader.sh" "$@"
