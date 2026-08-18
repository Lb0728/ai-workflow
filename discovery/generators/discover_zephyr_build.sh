#!/usr/bin/env bash
set -eu

PROJECT_ROOT=""

usage() {
  printf '%s\n' "Usage: discover_zephyr_build.sh --project-root <path>"
}

relative_path() {
  local absolute_path="$1"
  case "$absolute_path" in
    "$PROJECT_ROOT") printf '%s\n' "." ;;
    "$PROJECT_ROOT"/*) printf '%s\n' "${absolute_path#"${PROJECT_ROOT}/"}" ;;
    *) return 1 ;;
  esac
}

cache_value() {
  local cache_file="$1"
  local key="$2"
  awk -F= -v key="$key" '
    $1 ~ "^" key "(:[^=]+)?$" {
      print substr($0, index($0, "=") + 1)
      exit
    }
  ' "$cache_file"
}

west_config_board() {
  local config_file="$1"
  awk -F= '
    /^[[:space:]]*\[build\][[:space:]]*$/ { in_build = 1; next }
    /^[[:space:]]*\[/ { in_build = 0 }
    in_build && $1 ~ /^[[:space:]]*board[[:space:]]*$/ {
      value = $2
      sub(/^[[:space:]]*/, "", value)
      sub(/[[:space:]]*$/, "", value)
      print value
      exit
    }
  ' "$config_file"
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

while IFS= read -r cache_file; do
  build_dir="$(dirname "$cache_file")"
  [ -d "${build_dir}/zephyr" ] || continue
  grep -Eq '^(ZEPHYR_BASE|Zephyr_DIR|APPLICATION_SOURCE_DIR)(:|=)' \
    "$cache_file" || continue

  build_relative="$(relative_path "$build_dir")"
  board="$(cache_value "$cache_file" BOARD)"
  application_absolute="$(cache_value "$cache_file" APPLICATION_SOURCE_DIR)"
  application=""
  if [ -n "$application_absolute" ]; then
    application="$(relative_path "$application_absolute" 2>/dev/null || true)"
  fi

  printf '%s\n' "status=confirmed"
  printf 'build_dir=%s\n' "$build_relative"
  printf 'board=%s\n' "$board"
  printf 'application=%s\n' "$application"
  printf 'evidence=%s\n' "${build_relative}/CMakeCache.txt"
  printf 'evidence=%s\n' "${build_relative}/zephyr"
  exit 0
done < <(
  find "$PROJECT_ROOT" -mindepth 2 -maxdepth 4 -type f \
    -name CMakeCache.txt ! -path '*/.git/*' -print 2>/dev/null |
    LC_ALL=C sort
)

applications=()
while IFS= read -r cmake_file; do
  application_dir="$(dirname "$cmake_file")"
  if [ -f "${application_dir}/prj.conf" ] &&
    grep -Eq 'find_package[[:space:]]*\([[:space:]]*Zephyr([[:space:])]|$)' \
      "$cmake_file"; then
    applications+=("$(relative_path "$application_dir")")
  fi
done < <(
  find "$PROJECT_ROOT" -maxdepth 4 -type f -name CMakeLists.txt \
    ! -path '*/build/*' ! -path '*/.git/*' -print 2>/dev/null |
    LC_ALL=C sort
)

application=""
if [ "${#applications[@]}" -eq 1 ]; then
  application="${applications[0]}"
fi

board=""
if [ -f "${PROJECT_ROOT}/.west/config" ]; then
  board="$(west_config_board "${PROJECT_ROOT}/.west/config")"
fi

if [ -n "$application" ] && [ -n "$board" ]; then
  printf '%s\n' "status=confirmed"
else
  printf '%s\n' "status=needs_input"
fi
printf '%s\n' "build_dir="
printf 'board=%s\n' "$board"
printf 'application=%s\n' "$application"
if [ -f "${PROJECT_ROOT}/.west/config" ]; then
  printf '%s\n' "evidence=.west/config"
fi
if [ -n "$application" ]; then
  printf 'evidence=%s\n' "${application%/}/CMakeLists.txt"
  printf 'evidence=%s\n' "${application%/}/prj.conf"
fi
