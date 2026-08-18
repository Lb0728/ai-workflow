#!/usr/bin/env bash
# shellcheck disable=SC2034  # WORKFLOW_ROOT is exported for sourced consumers
set -eu

TESTS_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKFLOW_ROOT="$(cd "${TESTS_ROOT}/.." && pwd)"

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

select_utf8_locale() {
  local candidate
  for candidate in "${LC_ALL:-}" "${LANG:-}" C.UTF-8 C.utf8 UTF-8 en_US.UTF-8; do
    [ -n "$candidate" ] || continue
    if LC_ALL="$candidate" LANG="$candidate" locale charmap 2>/dev/null |
      grep -Eiq '^UTF-?8$'; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done

  locale -a 2>/dev/null | while IFS= read -r candidate; do
    if LC_ALL="$candidate" LANG="$candidate" locale charmap 2>/dev/null |
      grep -Eiq '^UTF-?8$'; then
      printf '%s\n' "$candidate"
      break
    fi
  done
}

TEST_UTF8_LOCALE="$(select_utf8_locale || true)"
[ -n "$TEST_UTF8_LOCALE" ] || fail "no usable UTF-8 locale is installed"
export TEST_UTF8_LOCALE
export LC_ALL="$TEST_UTF8_LOCALE"
export LANG="$TEST_UTF8_LOCALE"

assert_file_contains() {
  local file="$1"
  local expected="$2"
  grep -Fq -- "$expected" "$file" || fail "${file} does not contain ${expected}"
}

assert_output_contains() {
  local output="$1"
  local expected="$2"
  printf '%s\n' "$output" | grep -Fq -- "$expected" || fail "output does not contain ${expected}"
}

copy_fixture() {
  local fixture_name="$1"
  local destination_root="$2"
  mkdir -p "$destination_root"
  cp -R "${TESTS_ROOT}/fixtures/${fixture_name}/." "$destination_root/"
}
