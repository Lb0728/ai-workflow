#!/usr/bin/env bash
set -eu

PROJECT_KIND=""

usage() {
  printf '%s\n' "Usage: project_command_guard.sh --kind <kind> -- <command> [args...]"
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --kind)
      [ "$#" -ge 2 ] || { usage >&2; exit 2; }
      PROJECT_KIND="$2"
      shift 2
      ;;
    --)
      shift
      break
      ;;
    *)
      printf 'ERROR unknown argument: %s\n' "$1" >&2
      exit 2
      ;;
  esac
done

[ -n "$PROJECT_KIND" ] && [ "$#" -gt 0 ] || { usage >&2; exit 2; }

if [ "$PROJECT_KIND" != "zephyr" ]; then
  printf '%s\n' "ERROR Zephyr command rules require detected_kind=zephyr" >&2
  exit 1
fi

for argument in "$@"; do
  case "$argument" in
    *';'*|*'&&'*|*'||'*|*'|'*|*'`'*|*'$('*|*'<'*|*'>'*)
      printf '%s\n' "ERROR shell composition is forbidden for managed project commands" >&2
      exit 1
      ;;
  esac
done

command_name="$(basename "$1")"
subcommand="${2:-}"
case "${command_name}:${subcommand}" in
  west:build)
    exit 0
    ;;
  west:flash|west:debug|west:attach)
    printf 'STOP forbidden Zephyr device command: %s %s\n' "$command_name" "$subcommand" >&2
    exit 1
    ;;
esac

case "$command_name" in
  nrfjprog|openocd|JLinkExe|pyocd|esptool|esptool.py)
    printf 'STOP forbidden device tool: %s\n' "$command_name" >&2
    exit 1
    ;;
esac

printf 'ERROR unmanaged Zephyr command is not allowed: %s\n' "$command_name" >&2
exit 1
