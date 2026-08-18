#!/usr/bin/env bash
set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/test_helper.sh"

temp_root="$(mktemp -d "${TMPDIR:-/tmp}/workflow-cross-host.XXXXXX")"
trap 'rm -rf "$temp_root"' EXIT

codex_project="${temp_root}/codex-project"
cursor_project="${temp_root}/cursor-project"
copy_fixture go "$codex_project"
copy_fixture go "$cursor_project"

"${WORKFLOW_ROOT}/cli/ai-workflow" init \
  --project-root "$codex_project" --host codex >/dev/null
"${WORKFLOW_ROOT}/cli/ai-workflow" init \
  --project-root "$cursor_project" --host cursor >/dev/null

write_task() {
  local destination="$1"
  local task_id="$2"
  local delivery_level="$3"
  local status_value="$4"
  local multiple_modules="$5"
  {
    printf '%s\n' "---"
    printf 'task_id: %s\n' "$task_id"
    printf '%s\n' "type: feature"
    printf '%s\n' "priority: P2"
    printf 'delivery_level: %s\n' "$delivery_level"
    printf '%s\n' "self_test_level: quick"
    printf 'status: %s\n' "$status_value"
    printf '%s\n' "legacy: false"
    printf '%s\n' "---"
    printf '%s\n' "## 交付风险信号"
    printf '%s\n' "- core_user_flow: false"
    printf '%s\n' "- api_contract_changed: false"
    printf '%s\n' "- shared_state_changed: false"
    printf -- '- multiple_modules_affected: %s\n' "$multiple_modules"
    printf '%s\n' "- multiple_repositories_affected: false"
    printf '%s\n' "- similar_defect_happened_before: false"
    printf '%s\n' "- impact_scope_unclear: false"
    printf '%s\n' "- architecture_boundary_involved: false"
    printf '%s\n' "- real_device_or_production_required: false"
    if [ "$multiple_modules" = "true" ]; then
      printf '%s\n' "- 风险证据：任务明确影响两个模块"
    fi
  } >"$destination"
}

route_fingerprint() {
  grep -E \
    '^- 交付强度：|^- 建议交付强度：|^- 当前是否需要升级：|^- L[0-3] |^- 高风险专项：|^- Architecture Gate：|^- Platform / Transport Gate：|^- Historical Regression Gate：|^- 阶段：|^- 模式：|^- Agent：' \
    "$1"
}

compare_route() {
  local task_name="$1"
  local expected_tier="$2"
  local expected_agent="$3"
  local codex_task="${codex_project}/.ai/runtime/tasks/${task_name}.md"
  local cursor_task="${cursor_project}/.ai/runtime/tasks/${task_name}.md"
  local codex_output="${temp_root}/${task_name}.codex.out"
  local cursor_output="${temp_root}/${task_name}.cursor.out"

  CURSOR_SELECTED_MODEL=not-observable \
    "${WORKFLOW_ROOT}/cli/ai-workflow" next \
    --project-root "$codex_project" --host codex "$codex_task" >"$codex_output"
  CURSOR_SELECTED_MODEL=also-not-observable \
    "${WORKFLOW_ROOT}/cli/ai-workflow" next \
    --project-root "$cursor_project" --host cursor "$cursor_task" >"$cursor_output"

  route_fingerprint "$codex_output" >"${codex_output}.route"
  route_fingerprint "$cursor_output" >"${cursor_output}.route"
  cmp -s "${codex_output}.route" "${cursor_output}.route" ||
    fail "Router result differs across Hosts for ${task_name}"
  assert_file_contains "${codex_output}.route" "- 交付强度：${expected_tier}"
  assert_file_contains "${codex_output}.route" "- Agent：${expected_agent}"
}

for project_root in "$codex_project" "$cursor_project"; do
  write_task "${project_root}/.ai/runtime/tasks/l1.md" \
    "CROSS-HOST-L1" micro_change analyze false
  write_task "${project_root}/.ai/runtime/tasks/l2.md" \
    "CROSS-HOST-L2" standard_delivery impact_map true
done

compare_route l1 L1 coding
compare_route l2 L2 requirement

codex_assembled="${temp_root}/codex.assembled"
cursor_assembled="${temp_root}/cursor.assembled"
"${WORKFLOW_ROOT}/cli/ai-workflow" assemble \
  --project-root "$codex_project" --host codex \
  coding "${codex_project}/.ai/runtime/tasks/l1.md" >"$codex_assembled"
"${WORKFLOW_ROOT}/cli/ai-workflow" assemble \
  --project-root "$cursor_project" --host cursor \
  coding "${cursor_project}/.ai/runtime/tasks/l1.md" >"$cursor_assembled"

sed -n '/## Core Agent/,/## Host Instructions/p' "$codex_assembled" |
  sed '$d' >"${codex_assembled}.shared"
sed -n '/## Core Agent/,/## Host Instructions/p' "$cursor_assembled" |
  sed '$d' >"${cursor_assembled}.shared"
cmp -s "${codex_assembled}.shared" "${cursor_assembled}.shared" ||
  fail "Core Agent, Company Policy or Role assembly differs across Hosts"

printf '%s\n' "test_cross_host_router: PASS"
