#!/usr/bin/env bash
# Task Card Schema validation tests (P2):
#   - ai-workflow new produces schema-valid cards for every delivery level
#   - tc_validate rejects invalid frontmatter / high-risk violations
#   - transition.sh refuses to apply transitions on schema-invalid cards
#   - legacy: true cards skip strict validation

set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/test_helper.sh"

source "${WORKFLOW_ROOT}/core/lib/task_card.sh"

temp_root="$(mktemp -d "${TMPDIR:-/tmp}/workflow-task-schema.XXXXXX")"
trap 'rm -rf "$temp_root"' EXIT
project_root="${temp_root}/project"
copy_fixture go "$project_root"
git -C "$project_root" init -q
"${WORKFLOW_ROOT}/cli/ai-workflow" init --project-root "$project_root" --host codex >/dev/null

# --- 1. ai-workflow new creates schema-valid cards ----------------------
for level in micro_change light_feature standard_delivery high_risk_delivery; do
  card="$("${WORKFLOW_ROOT}/cli/ai-workflow" new --project-root "$project_root" \
    feature "SCHEMA-${level}" schema-probe P2 "$level" | awk '/^已创建任务卡：/{getline; print; exit}')"
  [ -f "$card" ] || fail "new did not create a card for ${level}"
  if ! tc_validate "$card" >/dev/null; then
    fail "new card failed schema validation (${level}): $(tc_validate "$card")"
  fi
done

# --- 2. invalid frontmatter is rejected ---------------------------------
bad_type="${temp_root}/bad-type.md"
{
  printf '%s\n' "---"
  printf '%s\n' "task_id: BAD-1"
  printf '%s\n' "type: not_a_real_type"
  printf '%s\n' "delivery_level: standard_delivery"
  printf '%s\n' "status: analyze"
  printf '%s\n' "---"
} > "$bad_type"
if tc_validate "$bad_type" | grep -Fq -- "- type 非法: not_a_real_type"; then
  printf '%s\n' "PASS bad type rejected"
else
  fail "bad type was not rejected"
fi

bad_delivery="${temp_root}/bad-delivery.md"
{
  printf '%s\n' "---"
  printf '%s\n' "task_id: BAD-2"
  printf '%s\n' "type: feature"
  printf '%s\n' "delivery_level: massive_rewrite"
  printf '%s\n' "status: analyze"
  printf '%s\n' "---"
} > "$bad_delivery"
if tc_validate "$bad_delivery" | grep -Fq -- "- delivery_level 非法: massive_rewrite"; then
  printf '%s\n' "PASS bad delivery_level rejected"
else
  fail "bad delivery_level was not rejected"
fi

# --- 3. high_risk_delivery rules ----------------------------------------
high_risk_bad="${temp_root}/high-risk-bad.md"
{
  printf '%s\n' "---"
  printf '%s\n' "task_id: BAD-3"
  printf '%s\n' "type: device"
  printf '%s\n' "delivery_level: high_risk_delivery"
  printf '%s\n' "self_test_level: quick"
  printf '%s\n' "alignment_required: false"
  printf '%s\n' "alignment_status: weird"
  printf '%s\n' "status: analyze"
  printf '%s\n' "---"
} > "$high_risk_bad"
high_risk_output="$(tc_validate "$high_risk_bad" || true)"
printf '%s\n' "$high_risk_output" | grep -Fq -- "- high_risk_delivery 必须填写交付风险信号" ||
  fail "high_risk missing risk section not rejected"
printf '%s\n' "$high_risk_output" | grep -Fq -- "- high_risk_delivery 必须设置 alignment_required=true" ||
  fail "high_risk alignment_required not rejected"
printf '%s\n' "$high_risk_output" | grep -Fq -- "- high_risk_delivery 的 self_test_level 必须为 specialized" ||
  fail "high_risk self_test_level not rejected"
printf '%s\n' "$high_risk_output" | grep -Fq -- "- alignment_status 只能为 pending / confirmed: weird" ||
  fail "high_risk alignment_status not rejected"

# --- 4. implement on high_risk requires confirmed alignment --------------
implement_unconfirmed="${temp_root}/implement-unconfirmed.md"
{
  printf '%s\n' "---"
  printf '%s\n' "task_id: BAD-4"
  printf '%s\n' "type: device"
  printf '%s\n' "delivery_level: high_risk_delivery"
  printf '%s\n' "self_test_level: specialized"
  printf '%s\n' "alignment_required: true"
  printf '%s\n' "alignment_status: pending"
  printf '%s\n' "status: implement"
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
  printf '%s\n' "- 风险证据：无"
  printf '%s\n' "---"
} > "$implement_unconfirmed"
implement_output="$(tc_validate "$implement_unconfirmed" || true)"
printf '%s\n' "$implement_output" | grep -Fq -- "- status=implement 需要 alignment_status=confirmed" ||
  fail "implement without confirmed alignment not rejected"
printf '%s\n' "$implement_output" | grep -Fq -- "- status=implement 需要 alignment_confirmed_at" ||
  fail "implement without alignment_confirmed_at not rejected"

# --- 5. transition.sh refuses schema-invalid cards ------------------------
transition_card="${temp_root}/transition-invalid.md"
{
  printf '%s\n' "---"
  printf '%s\n' "task_id: BAD-5"
  printf '%s\n' "type: bogus_type"
  printf '%s\n' "delivery_level: standard_delivery"
  printf '%s\n' "status: analyze"
  printf '%s\n' "validation_static: PASS"
  printf '%s\n' "validation_runtime: PASS"
  printf '%s\n' "---"
  printf '%s\n' "## 下一步决策"
  printf '%s\n' "- 当前阶段: bugfix_diagnosis"
  printf '%s\n' "- 动作: ADVANCE"
  printf '%s\n' "- 目标阶段: coding"
  printf '%s\n' "- 决策原因: probe"
} > "$transition_card"
before="${temp_root}/transition-invalid.before"
cp "$transition_card" "$before"
if "${WORKFLOW_ROOT}/cli/ai-workflow" transition --project-root "$project_root" \
  "$transition_card" >"${temp_root}/transition.out" 2>&1; then
  fail "transition.sh accepted a schema-invalid card"
fi
cmp -s "$before" "$transition_card" || fail "transition.sh modified a schema-invalid card"
grep -Fq -- "任务卡 Schema 校验失败" "${temp_root}/transition.out" ||
  fail "transition.sh did not report the schema failure"

# --- 6. legacy cards skip strict validation ------------------------------
legacy_card="${temp_root}/legacy.md"
{
  printf '%s\n' "---"
  printf '%s\n' "task_id: LEGACY-1"
  printf '%s\n' "type: old"
  printf '%s\n' "delivery_level: whatever"
  printf '%s\n' "status: something"
  printf '%s\n' "legacy: true"
  printf '%s\n' "---"
} > "$legacy_card"
tc_validate "$legacy_card" || fail "legacy card must skip strict validation"

printf '%s\n' "test_task_card_schema: PASS"
