#!/usr/bin/env bash
set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/test_helper.sh"

skill_count="$(find "${WORKFLOW_ROOT}/skills" -mindepth 2 -maxdepth 2 -name SKILL.md | wc -l | tr -d ' ')"
[ "$skill_count" -eq 5 ] || fail "expected five canonical Skills"

for skill_file in "${WORKFLOW_ROOT}"/skills/*/SKILL.md; do
  assert_file_contains "$skill_file" "name:"
  assert_file_contains "$skill_file" "description:"
done

if grep -R -E -n \
  'Codex|Claude|Cursor|DeepSeek|BLE|MQTT|Flutter|AGENTS\.md|CLAUDE\.md|\.cursor/rules|/Users/|/Volumes/' \
  "${WORKFLOW_ROOT}/skills" >/dev/null; then
  fail "canonical Skills contain a Host, project or personal binding"
fi

if find "${WORKFLOW_ROOT}/skills" -path '*/agents/openai.yaml' -print -quit |
  grep -q .; then
  fail "Host-specific Skill metadata remains in canonical Skills"
fi

for skill_root in "${WORKFLOW_ROOT}"/skills/*; do
  [ -d "$skill_root" ] || continue
  skill_name="$(basename "$skill_root")"
  [ -f "${WORKFLOW_ROOT}/hosts/codex/skill-metadata/${skill_name}/openai.yaml" ] ||
    fail "Codex Skill metadata missing: ${skill_name}"
done

printf '%s\n' "test_skills: PASS"
