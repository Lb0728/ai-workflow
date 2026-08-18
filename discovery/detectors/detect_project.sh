#!/usr/bin/env bash
set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT=""

usage() {
  printf '%s\n' "Usage: detect_project.sh --project-root <path>"
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --project-root)
      [ "$#" -ge 2 ] || { usage >&2; exit 2; }
      PROJECT_ROOT="$2"
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

[ -n "$PROJECT_ROOT" ] || { usage >&2; exit 2; }
[ -d "$PROJECT_ROOT" ] || { printf '%s\n' "ERROR project root not found" >&2; exit 1; }
PROJECT_ROOT="$(cd "$PROJECT_ROOT" && pwd)"

project_kind="unknown"
if [ -f "${PROJECT_ROOT}/pubspec.yaml" ]; then
  if grep -Eq '^[[:space:]]+flutter:[[:space:]]*$|^[[:space:]]*sdk:[[:space:]]*flutter' \
    "${PROJECT_ROOT}/pubspec.yaml"; then
    project_kind="flutter"
  else
    project_kind="dart"
  fi
elif [ -f "${PROJECT_ROOT}/go.mod" ]; then
  project_kind="go"
elif "${SCRIPT_DIR}/detect_zephyr.sh" --project-root "$PROJECT_ROOT"; then
  project_kind="zephyr"
fi

printf '%s\n' "$project_kind"
