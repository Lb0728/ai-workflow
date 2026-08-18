#!/usr/bin/env bash
# P4 quality gate tests: finish.sh must refuse to move a task into
# ready_for_qa without real self-test evidence, and accept it with evidence.

set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/test_helper.sh"

temp_root="$(mktemp -d "${TMPDIR:-/tmp}/workflow-quality-gate.XXXXXX")"
trap 'rm -rf "$temp_root"' EXIT
project_root="${temp_root}/project"
copy_fixture go "$project_root"
git -C "$project_root" init -q
"${WORKFLOW_ROOT}/cli/ai-workflow" init --project-root "$project_root" --host codex >/dev/null

make_card() {
  local file="$1"
  local with_evidence="$2"
  {
    printf '%s\n' "---"
    printf '%s\n' "task_id: QG-1"
    printf '%s\n' "type: feature"
    printf '%s\n' "delivery_level: light_feature"
    printf '%s\n' "self_test_level: quick"
    printf '%s\n' "status: self_test_in_progress"
    printf '%s\n' "iteration: 1"
    printf '%s\n' "max_iterations: 2"
    printf '%s\n' "---"
    printf '%s\n' "## 提测门禁结果"
    printf '%s\n' "- L0 Diff Gate（变更范围检查）: PASS"
    printf '%s\n' "- L1 Basic Run Gate（基础可运行检查）: PASS"
    printf '%s\n' "- L2 Feature Verification Gate（本功能验证）: PASS"
    printf '%s\n' "- L3 Direct Regression Gate（直接影响回归）: PASS"
    if [ "$with_evidence" = "yes" ]; then
      printf '%s\n' "## Self Test 红绿灯"
      printf '%s\n' "总体：[绿] 可提测"
      printf '%s\n' "L0 [绿] | L1 [绿] | L2 [绿] | L3 [绿]"
      printf '%s\n' "- 绿灯依据：L0-L3 PASS"
      printf '%s\n' "## 证据记录"
      printf '%s\n' "### 验证证据"
      printf '%s\n' "- 命令：go test ./..."
      printf '%s\n' "- 输出摘要：全部通过"
      printf '%s\n' "- 人工验证：页面检查通过"
      printf '%s\n' "- 未覆盖风险：无"
    fi
    printf '%s\n' "## Loop Closeout"
    printf '%s\n' "- 当前状态：self_test_in_progress"
    printf '%s\n' "- 下一阶段：ready_for_qa"
    printf '%s\n' "- 是否 Done：否"
    printf '%s\n' "- 唯一下一步：输出提测结论"
    printf '%s\n' "- 是否需要 Owner 输入：否"
  } > "$file"
}

# --- 1. no evidence -> finish to ready_for_qa rejected, file unchanged ----
no_evidence="${temp_root}/no-evidence.md"
make_card "$no_evidence" no
cp "$no_evidence" "${temp_root}/no-evidence.before"
if "${WORKFLOW_ROOT}/cli/ai-workflow" finish --project-root "$project_root" \
  "$no_evidence" >"${temp_root}/no-evidence.out" 2>&1; then
  fail "finish accepted ready_for_qa without evidence"
fi
cmp -s "$no_evidence" "${temp_root}/no-evidence.before" ||
  fail "finish modified the card despite the evidence gate"
grep -Fq -- "证据不足，不能进入 READY_FOR_QA" "${temp_root}/no-evidence.out" ||
  fail "finish did not report the evidence gate"
grep -Fq -- "缺少 Self Test 红绿灯证据" "${temp_root}/no-evidence.out" ||
  fail "finish did not report the missing traffic light"
printf '%s\n' "PASS ready_for_qa blocked without evidence"

# --- 2. with evidence -> finish to ready_for_qa accepted -----------------
with_evidence="${temp_root}/with-evidence.md"
make_card "$with_evidence" yes
"${WORKFLOW_ROOT}/cli/ai-workflow" finish --project-root "$project_root" \
  "$with_evidence" >"${temp_root}/with-evidence.out" 2>&1 ||
  fail "finish rejected a card with evidence: $(cat "${temp_root}/with-evidence.out")"
grep -Fq -- "status: ready_for_qa" "$with_evidence" ||
  fail "finish did not update status to ready_for_qa"
grep -Fq -- "iteration: 2" "$with_evidence" ||
  fail "finish did not bump iteration"
printf '%s\n' "PASS ready_for_qa accepted with evidence"

# --- 3. traffic light present but evidence placeholders -> rejected ------
placeholder_evidence="${temp_root}/placeholder-evidence.md"
make_card "$placeholder_evidence" no
{
  printf '%s\n' "## Self Test 红绿灯"
  printf '%s\n' "总体：[绿] 可提测"
  printf '%s\n' "L0 [绿] | L1 [绿] | L2 [绿] | L3 [绿]"
  printf '%s\n' "- 绿灯依据：L0-L3 PASS"
  printf '%s\n' "## 证据记录"
  printf '%s\n' "### 验证证据"
  printf '%s\n' "- 命令：待填写"
  printf '%s\n' "- 输出摘要：待补充"
} >> "$placeholder_evidence"
if "${WORKFLOW_ROOT}/cli/ai-workflow" finish --project-root "$project_root" \
  "$placeholder_evidence" >"${temp_root}/placeholder.out" 2>&1; then
  fail "finish accepted placeholder-only evidence"
fi
grep -Fq -- "缺少真实证据" "${temp_root}/placeholder.out" ||
  fail "finish did not report placeholder evidence"
printf '%s\n' "PASS placeholder evidence rejected"

printf '%s\n' "test_quality_gate: PASS"
