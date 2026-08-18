#!/usr/bin/env bash
set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WORKFLOW_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
LOADER="${SCRIPT_DIR}/ai_core_loader.sh"
CHECK="${SCRIPT_DIR}/ai_core_compat_check.sh"
PROJECT_ROOT="${1:-}"
failures=0

if [ -z "$PROJECT_ROOT" ]; then
  printf '%s\n' "Usage: ./tool/test_ai_core_compat.sh <project-root>"
  exit 2
fi

assert_equal() {
  local name="$1"
  local actual="$2"
  local expected="$3"
  if [ "$actual" = "$expected" ]; then
    printf 'PASS %s\n' "$name"
  else
    printf 'FAIL %s expected=%s actual=%s\n' "$name" "$expected" "$actual"
    failures=$((failures + 1))
  fi
}

compat_output="$(
  LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8 \
    "$CHECK" --project-root "$PROJECT_ROOT"
)"
if printf '%s\n' "$compat_output" | grep -F "RESULT PASS" >/dev/null; then
  printf '%s\n' "PASS compatibility check"
else
  printf '%s\n' "FAIL compatibility check"
  failures=$((failures + 1))
fi

assert_equal \
  "canonical task resolution" \
  "$("$LOADER" --project-root "$PROJECT_ROOT" resolve runtime.tasks)" \
  "${WORKFLOW_ROOT}/runtime/tasks"

assert_equal \
  "legacy task resolution" \
  "$("$LOADER" --project-root "$PROJECT_ROOT" resolve legacy.tasks)" \
  "${WORKFLOW_ROOT}/tasks"

set +e
invalid_output="$(
  "$LOADER" --project-root "$PROJECT_ROOT" resolve __invalid_key__ 2>&1
)"
invalid_status=$?
set -e
if [ "$invalid_status" -ne 0 ]; then
  printf '%s\n' "PASS invalid key is rejected"
else
  printf '%s\n' "FAIL invalid key should be rejected"
  failures=$((failures + 1))
fi
if printf '%s\n' "$invalid_output" | grep -F "unknown resolve key" >/dev/null; then
  printf '%s\n' "PASS invalid key error is explicit"
else
  printf '%s\n' "FAIL invalid key error is not explicit"
  failures=$((failures + 1))
fi

set +e
missing_key_output="$(
  "$LOADER" --project-root "$PROJECT_ROOT" resolve 2>&1
)"
missing_key_status=$?
set -e
if [ "$missing_key_status" -ne 0 ]; then
  printf '%s\n' "PASS missing resolve key is rejected"
else
  printf '%s\n' "FAIL missing resolve key should be rejected"
  failures=$((failures + 1))
fi
if printf '%s\n' "$missing_key_output" | grep -F "resolve key is required" >/dev/null; then
  printf '%s\n' "PASS missing resolve key error is explicit"
else
  printf '%s\n' "FAIL missing resolve key error is not explicit"
  failures=$((failures + 1))
fi

if [ "$failures" -gt 0 ]; then
  printf 'FAILED: %d assertion(s)\n' "$failures"
  exit 1
fi

printf '%s\n' "ALL PASS: Phase 4 compatibility scenarios"
