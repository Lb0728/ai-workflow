#!/usr/bin/env bash
set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/test_helper.sh"

temp_root="$(mktemp -d "${TMPDIR:-/tmp}/workflow-codex.XXXXXX")"
trap 'rm -rf "$temp_root"' EXIT
project_root="${temp_root}/project"
copy_fixture flutter "$project_root"
git -C "$project_root" init -q
"${WORKFLOW_ROOT}/cli/ai-workflow" init --project-root "$project_root" --host codex >/dev/null

task_file="${project_root}/.ai/runtime/tasks/example.md"
printf '%s\n' "# Verify Router assembly" > "$task_file"
assembled="$("${WORKFLOW_ROOT}/cli/ai-workflow" assemble \
  --project-root "$project_root" router "$task_file")"

for section in \
  "## Core Agent" \
  "## Company Policy" \
  "## Role" \
  "## Host Instructions" \
  "## Generated Project Profile" \
  "## Current Task"; do
  assert_output_contains "$assembled" "$section"
done
assert_output_contains "$assembled" "Verify Router assembly"

printf '%s\n' "test_codex_host: PASS"
