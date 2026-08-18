#!/usr/bin/env bash
set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/test_helper.sh"

temp_root="$(mktemp -d "${TMPDIR:-/tmp}/workflow-compat.XXXXXX")"
trap 'rm -rf "$temp_root"' EXIT
v1_project="${temp_root}/v1"
v2_project="${temp_root}/v2"
copy_fixture go "$v1_project"
copy_fixture go "$v2_project"
git -C "$v2_project" init -q

v1_resolved="$("${WORKFLOW_ROOT}/compat/legacy/loader.sh" \
  --project-root "$v1_project" --adapter demo-project resolve core.router)"
assert_output_contains "$v1_resolved" "core/agents/00_router_agent.md"
v1_handoffs="$("${WORKFLOW_ROOT}/compat/legacy/loader.sh" \
  --project-root "$v1_project" --adapter demo-project resolve runtime.handoffs)"
v1_closeouts="$("${WORKFLOW_ROOT}/compat/legacy/loader.sh" \
  --project-root "$v1_project" --adapter demo-project resolve runtime.closeouts)"
assert_output_contains "$v1_handoffs" "runtime/handoffs"
assert_output_contains "$v1_closeouts" "runtime/closeouts"

"${WORKFLOW_ROOT}/cli/ai-workflow" init --project-root "$v2_project" --host codex >/dev/null
v2_description="$("${WORKFLOW_ROOT}/compat/legacy/loader.sh" \
  --project-root "$v2_project" describe)"
assert_output_contains "$v2_description" "workflow_version=2.0.0-rc.5"
assert_output_contains "$v2_description" "project_profile=.ai/project.yaml"
v2_handoffs="$("${WORKFLOW_ROOT}/compat/legacy/loader.sh" \
  --project-root "$v2_project" resolve runtime.handoffs)"
v2_closeouts="$("${WORKFLOW_ROOT}/compat/legacy/loader.sh" \
  --project-root "$v2_project" resolve runtime.closeouts)"
assert_output_contains "$v2_handoffs" ".ai/runtime/handoffs"
assert_output_contains "$v2_closeouts" ".ai/runtime/closeouts"

printf '%s\n' "test_compat: PASS"
