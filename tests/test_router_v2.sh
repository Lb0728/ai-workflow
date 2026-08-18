#!/usr/bin/env bash
set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/test_helper.sh"

temp_root="$(mktemp -d "${TMPDIR:-/tmp}/workflow-router-v2.XXXXXX")"
trap 'rm -rf "$temp_root"' EXIT
project_root="${temp_root}/project"
copy_fixture go "$project_root"
git -C "$project_root" init -q
"${WORKFLOW_ROOT}/cli/ai-workflow" init --project-root "$project_root" --host codex >/dev/null

AI_LOOP_NEXT_SCRIPT="${WORKFLOW_ROOT}/core/router/ai_loop_next_v2.sh" \
  "${WORKFLOW_ROOT}/tool/test_ai_loop_next.sh" "$project_root" >/dev/null
LC_ALL=C LANG=C AI_LOOP_NEXT_SCRIPT="${WORKFLOW_ROOT}/core/router/ai_loop_next_v2.sh" \
  "${WORKFLOW_ROOT}/tool/test_ai_loop_next.sh" "$project_root" >/dev/null

portable_task="${project_root}/.ai/runtime/tasks/portable-locale.md"
{
  printf '%s\n' "---"
  printf '%s\n' "task_id: PORTABLE-LOCALE"
  printf '%s\n' "type: feature"
  printf '%s\n' "delivery_level: light_feature"
  printf '%s\n' "self_test_level: quick"
  printf '%s\n' "status: analyze"
  printf '%s\n' "legacy: false"
  printf '%s\n' "context_budget: L1"
  printf '%s\n' "required_context: []"
  printf '%s\n' "---"
  printf '%s\n' "## 交付风险信号"
  printf '%s\n' "- core_user_flow: false"
  printf '%s\n' "- api_contract_changed: false"
  printf '%s\n' "- shared_state_changed: false"
  printf '%s\n' "- multiple_modules_affected: false"
  printf '%s\n' "- multiple_repositories_affected: false"
  printf '%s\n' "- similar_defect_happened_before: false"
  printf '%s\n' "- impact_scope_unclear: false"
  printf '%s\n' "- architecture_boundary_involved: false"
  printf '%s\n' "- real_device_or_production_required: false"
} > "$portable_task"

utf8_output="$(LC_ALL="$TEST_UTF8_LOCALE" LANG="$TEST_UTF8_LOCALE" \
  "${WORKFLOW_ROOT}/cli/ai-workflow" next --verbose --project-root "$project_root" "$portable_task")"
c_output="$(LC_ALL=C LANG=C \
  "${WORKFLOW_ROOT}/cli/ai-workflow" next --verbose --project-root "$project_root" "$portable_task")"
for output in "$utf8_output" "$c_output"; do
  assert_output_contains "$output" "- 交付强度：L1"
  assert_output_contains "$output" "- context_budget: L1"
  assert_output_contains "$output" "- required_context:"
done

utf8_route="$(printf '%s\n' "$utf8_output" | sed -n '/## 本次选择阶段/,/## 可复制 Prompt/p' | awk '/^- 阶段：/{print; exit}')"
c_route="$(printf '%s\n' "$c_output" | sed -n '/## 本次选择阶段/,/## 可复制 Prompt/p' | awk '/^- 阶段：/{print; exit}')"
[ "$utf8_route" = "$c_route" ] || fail "Router Chinese parsing differs between UTF-8 and C locale"

printf 'test_router_v2: PASS (14 scenarios, locale=%s)\n' "$TEST_UTF8_LOCALE"
