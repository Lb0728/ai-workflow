#!/usr/bin/env bash
set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/test_helper.sh"

temp_root="$(mktemp -d "${TMPDIR:-/tmp}/workflow-feedback.XXXXXX")"
trap 'rm -rf "$temp_root"' EXIT
project_root="${temp_root}/project"
copy_fixture go "$project_root"
git -C "$project_root" init -q
"${WORKFLOW_ROOT}/cli/ai-workflow" init --project-root "$project_root" --host codex >/dev/null

task_file="${project_root}/.ai/runtime/tasks/example.md"
{
  printf '%s\n' "legacy: true"
  printf '%s\n' "task_type: bugfix"
  printf '%s\n' "risk_level: L2"
  printf '%s\n' "current_stage: SELF_TEST_IN_PROGRESS"
  printf '%s\n' "secret: must-not-appear"
  printf '%s\n' "source_path: /Users/example/private"
} > "$task_file"

report="$("${WORKFLOW_ROOT}/cli/ai-workflow" feedback \
  --project-root "$project_root" --task "$task_file")"
assert_output_contains "$report" "stack: ['go']"
assert_output_contains "$report" "core_version: '2.0.0-rc.5'"
assert_output_contains "$report" "id: 'codex'"
assert_output_contains "$report" "risk: 'L2'"
if printf '%s\n' "$report" | grep -Eq '/Users/|/Volumes/|must-not-appear|source_path|secret:'; then
  fail "feedback leaked a non-allowlisted field"
fi

doctor_report="$("${WORKFLOW_ROOT}/cli/ai-workflow" doctor \
  --project-root "$project_root" --report)"
assert_output_contains "$doctor_report" "V2 doctor: PASS"
assert_output_contains "$doctor_report" "core_version: '2.0.0-rc.5'"

printf '%s\n' "test_feedback: PASS"
