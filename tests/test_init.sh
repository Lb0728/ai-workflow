#!/usr/bin/env bash
set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/test_helper.sh"

temp_root="$(mktemp -d "${TMPDIR:-/tmp}/workflow-init.XXXXXX")"
trap 'rm -rf "$temp_root"' EXIT
project_root="${temp_root}/project"
copy_fixture go "$project_root"
git -C "$project_root" init -q

[ ! -e "${project_root}/.ai" ] || fail "clean fixture unexpectedly contains .ai"
[ ! -e "${project_root}/ai" ] || fail "clean fixture unexpectedly contains ai source directory"

printf '%s\n' "# Existing Repository Rule" > "${project_root}/AGENTS.md"
if "${WORKFLOW_ROOT}/cli/ai-workflow" init \
  --project-root "$project_root" --no-doctor >"${temp_root}/missing-host.out" 2>&1; then
  fail "first init accepted a missing Host"
fi
assert_file_contains "${temp_root}/missing-host.out" "Host is required"

"${WORKFLOW_ROOT}/cli/ai-workflow" init --project-root "$project_root" --host codex
if grep -Fq "'.ai'" "${project_root}/.ai/project.yaml"; then
  fail "first init polluted Discovery with the .ai directory it created"
fi
"${WORKFLOW_ROOT}/cli/ai-workflow" init --project-root "$project_root"

assert_file_contains "${project_root}/AGENTS.md" "# Existing Repository Rule"
assert_file_contains "${project_root}/AGENTS.md" "<!-- ai-workflow-v2:start -->"
[ "$(grep -Fc '<!-- ai-workflow-v2:start -->' "${project_root}/AGENTS.md")" -eq 1 ] ||
  fail "managed AGENTS block is not idempotent"
[ -f "${project_root}/.ai/project.yaml" ] || fail "project profile missing"
[ -f "${project_root}/.ai/ai.lock" ] || fail "lock missing"
[ -L "${project_root}/.ai/workflow" ] || fail "workflow link missing"
[ ! -e "${project_root}/ai" ] || fail "init copied Workflow source into target project"

for skill_root in "${WORKFLOW_ROOT}"/skills/*; do
  [ -d "$skill_root" ] || continue
  skill_name="$(basename "$skill_root")"
  skill_destination="${project_root}/.agents/skills/${skill_name}"
  [ -L "${skill_destination}/SKILL.md" ] ||
    fail "Skill source link missing: ${skill_name}"
  [ -L "${skill_destination}/agents/openai.yaml" ] ||
    fail "Codex Skill metadata link missing: ${skill_name}"
done

printf '%s\n' "test_init: PASS"
