#!/usr/bin/env bash
set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/test_helper.sh"

assert_file_contains "${WORKFLOW_ROOT}/.gitattributes" "*.sh text eol=lf"
assert_file_contains "${WORKFLOW_ROOT}/.gitattributes" "cli/ai-workflow text eol=lf"

shell_list="${TMPDIR:-/tmp}/workflow-shell-list.$$"
trap 'rm -f "$shell_list"' EXIT
find \
  "${WORKFLOW_ROOT}/cli" \
  "${WORKFLOW_ROOT}/core/loader" \
  "${WORKFLOW_ROOT}/core/router" \
  "${WORKFLOW_ROOT}/discovery" \
  "${WORKFLOW_ROOT}/hosts" \
  "${WORKFLOW_ROOT}/dist" \
  -type f \( -name '*.sh' -o -path "${WORKFLOW_ROOT}/cli/ai-workflow" \) \
  -print >"$shell_list"

while IFS= read -r shell_file; do
  if LC_ALL=C grep -q "$(printf '\r')" "$shell_file"; then
    fail "Shell entry contains CRLF: ${shell_file}"
  fi
  bash -n "$shell_file" || fail "Bash syntax invalid: ${shell_file}"
done <"$shell_list"

if grep -R -E -i -n \
  'uname|wsl|cygwin|mingw|darwin|powershell|cmd\.exe' \
  "${WORKFLOW_ROOT}/core" >/dev/null; then
  fail "operating-system compatibility logic leaked into Core"
fi

temp_root="$(mktemp -d "${TMPDIR:-/tmp}/workflow path compatibility.XXXXXX")"
trap 'rm -f "$shell_list"; rm -rf "$temp_root"' EXIT
project_root="${temp_root}/project with spaces"
copy_fixture go "$project_root"

"${WORKFLOW_ROOT}/cli/ai-workflow" init \
  --project-root "$project_root" --host codex >/dev/null
"${WORKFLOW_ROOT}/cli/ai-workflow" doctor \
  --project-root "$project_root" >/dev/null

[ -L "${project_root}/.ai/workflow" ] ||
  fail "Workflow symlink missing for a path containing spaces"
[ -L "${project_root}/.agents/skills/grill-me/SKILL.md" ] ||
  fail "Skill symlink missing for a path containing spaces"

printf '%s\n' "test_platform_compat: PASS"
