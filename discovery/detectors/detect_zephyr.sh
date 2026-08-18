#!/usr/bin/env bash
set -eu

PROJECT_ROOT=""

usage() {
  printf '%s\n' "Usage: detect_zephyr.sh --project-root <path>"
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
[ -d "$PROJECT_ROOT" ] || exit 1
PROJECT_ROOT="$(cd "$PROJECT_ROOT" && pwd)"

while IFS= read -r cache_file; do
  build_dir="$(dirname "$cache_file")"
  if [ -d "${build_dir}/zephyr" ] &&
    grep -Eq '^(ZEPHYR_BASE|Zephyr_DIR|APPLICATION_SOURCE_DIR)(:|=)' \
      "$cache_file"; then
    exit 0
  fi
done < <(
  find "$PROJECT_ROOT" -mindepth 2 -maxdepth 4 -type f \
    -name CMakeCache.txt ! -path '*/.git/*' -print 2>/dev/null |
    LC_ALL=C sort
)

while IFS= read -r cmake_file; do
  application_dir="$(dirname "$cmake_file")"
  if [ -f "${application_dir}/prj.conf" ] &&
    grep -Eq 'find_package[[:space:]]*\([[:space:]]*Zephyr([[:space:])]|$)' \
      "$cmake_file"; then
    exit 0
  fi
done < <(
  find "$PROJECT_ROOT" -maxdepth 4 -type f -name CMakeLists.txt \
    ! -path '*/build/*' ! -path '*/.git/*' -print 2>/dev/null |
    LC_ALL=C sort
)

exit 1
