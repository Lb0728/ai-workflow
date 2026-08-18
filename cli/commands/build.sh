#!/usr/bin/env bash
set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WORKFLOW_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
PROJECT_ROOT="$(pwd)"

usage() {
  printf '%s\n' "Usage: ai-workflow build [--project-root <path>]"
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
      printf 'ERROR arbitrary build arguments are not accepted: %s\n' "$1" >&2
      exit 2
      ;;
  esac
done

[ -d "$PROJECT_ROOT" ] || { printf '%s\n' "ERROR project root not found" >&2; exit 1; }
PROJECT_ROOT="$(cd "$PROJECT_ROOT" && pwd)"
project_kind="$(
  "${WORKFLOW_ROOT}/discovery/detectors/detect_project.sh" \
    --project-root "$PROJECT_ROOT"
)"
[ "$project_kind" = "zephyr" ] || {
  printf 'ERROR managed build is currently available only for detected_kind=zephyr; actual=%s\n' \
    "$project_kind" >&2
  exit 1
}

status=""
build_dir=""
board=""
application=""
while IFS= read -r discovery_line; do
  case "$discovery_line" in
    status=*) status="${discovery_line#status=}" ;;
    build_dir=*) build_dir="${discovery_line#build_dir=}" ;;
    board=*) board="${discovery_line#board=}" ;;
    application=*) application="${discovery_line#application=}" ;;
  esac
done < <(
  "${WORKFLOW_ROOT}/discovery/generators/discover_zephyr_build.sh" \
    --project-root "$PROJECT_ROOT"
)

printf '%s\n' "Project Kind: zephyr"
printf '%s\n' "Flash: NOT_RUN"
printf '%s\n' "Device Validation: NOT_RUN"

if [ "$status" != "confirmed" ]; then
  printf '%s\n' "Build: NOT_RUN"
  printf '%s\n' "Action: STOP"
  printf '%s\n' "Required input: target board and application directory"
  exit 2
fi

west_path="${AI_WORKFLOW_WEST:-$(type -P west || true)}"
if [ -z "$west_path" ] || [ ! -x "$west_path" ]; then
  printf '%s\n' "Build: NOT_RUN"
  printf '%s\n' "Action: STOP"
  printf '%s\n' "Required environment: west executable supplied by the developer"
  exit 2
fi

if [ -n "$build_dir" ]; then
  build_command=("$west_path" build -d "$build_dir")
else
  build_command=("$west_path" build -b "$board" "$application")
fi

"${WORKFLOW_ROOT}/cli/lib/project_command_guard.sh" \
  --kind zephyr -- "${build_command[@]}"

printf 'Build Command:'
printf ' %q' "${build_command[@]}"
printf '\n'

set +e
(
  cd "$PROJECT_ROOT"
  "${build_command[@]}"
)
build_exit=$?
set -e

if [ "$build_exit" -eq 0 ]; then
  printf '%s\n' "Build: PASS"
  printf '%s\n' "Build PASS proves compilation only; it is not device validation."
  exit 0
fi

printf '%s\n' "Build: FAIL"
printf 'Build Exit Code: %s\n' "$build_exit"
exit "$build_exit"
