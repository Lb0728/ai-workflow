#!/usr/bin/env bash
set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/test_helper.sh"

temp_root="$(mktemp -d "${TMPDIR:-/tmp}/workflow-cursor.XXXXXX")"
trap 'rm -rf "$temp_root"' EXIT
project_root="${temp_root}/project"
copy_fixture go "$project_root"

"${WORKFLOW_ROOT}/cli/ai-workflow" init \
  --project-root "$project_root" --host cursor >/dev/null

assert_file_contains "${project_root}/.ai/ai.lock" "id: 'cursor'"
assert_file_contains "${project_root}/.cursor/rules/ai-workflow.mdc" "ai-workflow-v2"
[ -f "${project_root}/.ai/hosts/cursor/instructions.md" ] ||
  fail "Cursor Host instructions missing"

for skill_root in "${WORKFLOW_ROOT}"/skills/*; do
  [ -d "$skill_root" ] || continue
  skill_name="$(basename "$skill_root")"
  skill_destination="${project_root}/.cursor/skills/${skill_name}"
  [ -L "${skill_destination}/SKILL.md" ] ||
    fail "Cursor Skill source link missing: ${skill_name}"
  [ ! -e "${skill_destination}/agents/openai.yaml" ] ||
    fail "Cursor installation contains another Host's Skill metadata"
done

doctor_output="$("${WORKFLOW_ROOT}/cli/ai-workflow" doctor \
  --project-root "$project_root")"
assert_output_contains "$doctor_output" "V2 doctor: PASS"
assert_output_contains "$doctor_output" "Host: cursor"

task_file="${project_root}/.ai/runtime/tasks/cursor-assemble.md"
printf '%s\n' "# Verify Cursor assembly" >"$task_file"
assembled="$("${WORKFLOW_ROOT}/cli/ai-workflow" assemble \
  --project-root "$project_root" router "$task_file")"
assert_output_contains "$assembled" "## Core Agent"
assert_output_contains "$assembled" "## Host Instructions"
assert_output_contains "$assembled" "Cursor Host Instructions"
assert_output_contains "$assembled" "Verify Cursor assembly"

printf '%s\n' "test_cursor_host: PASS"
