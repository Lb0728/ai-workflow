#!/usr/bin/env bash
set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/test_helper.sh"

guard="${WORKFLOW_ROOT}/cli/lib/project_command_guard.sh"

"$guard" --kind zephyr -- /usr/bin/west build -d build

assert_blocked() {
  local name="$1"
  shift
  if "$guard" --kind zephyr -- "$@" >/dev/null 2>&1; then
    fail "forbidden command was accepted: ${name}"
  fi
}

assert_blocked "west flash" west flash
assert_blocked "west debug" west debug
assert_blocked "west attach" west attach
assert_blocked "nrfjprog" nrfjprog --program image.hex
assert_blocked "openocd" openocd -f interface.cfg
assert_blocked "JLinkExe" JLinkExe -device example
assert_blocked "pyocd flash" pyocd flash image.hex
assert_blocked "esptool" esptool write_flash image.bin
assert_blocked "shell sequence" west build '-d;west flash'
assert_blocked "and sequence" west build '-d&&west flash'
assert_blocked "subshell" west build '$(west flash)'
if "$guard" --kind go -- west build -d build >/dev/null 2>&1; then
  fail "Zephyr command policy applied outside detected_kind=zephyr"
fi

printf '%s\n' "test_zephyr_safety: PASS"
