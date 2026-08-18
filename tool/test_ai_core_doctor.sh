#!/usr/bin/env bash
set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC2034
WORKFLOW_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
DOCTOR="${SCRIPT_DIR}/ai_core_doctor.sh"
PROJECT_ROOT="${1:-}"
failures=0

if [ -z "$PROJECT_ROOT" ]; then
  printf '%s\n' "Usage: ./tool/test_ai_core_doctor.sh <project-root>"
  exit 2
fi

assert_contains() {
  local name="$1"
  local output="$2"
  local expected="$3"
  if printf '%s\n' "$output" | grep -F -- "$expected" >/dev/null; then
    printf 'PASS %s\n' "$name"
  else
    printf 'FAIL %s: missing %s\n' "$name" "$expected"
    failures=$((failures + 1))
  fi
}

utf8_output="$(
  LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8 \
    "$DOCTOR" --project-root "$PROJECT_ROOT" --adapter demo-project --role developer
)"
assert_contains "UTF-8 doctor passes" "$utf8_output" "RESULT PASS"
assert_contains "all Agent links pass" "$utf8_output" "PASS legacy Agent link 08_commit_agent.md"
assert_contains "all Workflow links pass" "$utf8_output" "PASS legacy Workflow link tech_debt_workflow.md"
assert_contains "all Template links pass" "$utf8_output" "PASS legacy Template link task_card_template.md"
assert_contains "adapter routing active" "$utf8_output" "PASS adapter active"
assert_contains "runtime canonical owner" "$utf8_output" "PASS runtime canonical owner"
assert_contains "Core routing active" "$utf8_output" "PASS config-driven protocol owner"
assert_contains "Core Router active" "$utf8_output" "PASS Core Router active"
assert_contains "Router context active" "$utf8_output" "PASS adapter Router context active"
assert_contains "Role Agent selection active" "$utf8_output" "PASS Role Agent selection active"

set +e
c_output="$(LC_ALL=C LANG=C "$DOCTOR" --project-root "$PROJECT_ROOT" 2>&1)"
c_status=$?
set -e
if [ "$c_status" -ne 0 ]; then
  printf '%s\n' "PASS incompatible locale is rejected"
else
  printf '%s\n' "FAIL incompatible locale should be rejected"
  failures=$((failures + 1))
fi
assert_contains "locale failure is explicit" "$c_output" "UTF-8 locale required"

set +e
missing_adapter_output="$(
  LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8 \
    "$DOCTOR" --project-root "$PROJECT_ROOT" --adapter __missing_adapter__ 2>&1
)"
missing_adapter_status=$?
set -e
if [ "$missing_adapter_status" -ne 0 ]; then
  printf '%s\n' "PASS missing Adapter is rejected"
else
  printf '%s\n' "FAIL missing Adapter should be rejected"
  failures=$((failures + 1))
fi
assert_contains "missing Adapter error is explicit" "$missing_adapter_output" "project profile missing"

if [ "$failures" -gt 0 ]; then
  printf 'FAILED: %d assertion(s)\n' "$failures"
  exit 1
fi

printf '%s\n' "ALL PASS: migration Doctor scenarios"
