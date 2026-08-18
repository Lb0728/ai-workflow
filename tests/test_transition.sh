#!/usr/bin/env bash
set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/test_helper.sh"

temp_root="$(mktemp -d "${TMPDIR:-/tmp}/workflow-transition.XXXXXX")"
trap 'rm -rf "$temp_root"' EXIT
task="${temp_root}/task.md"

write_task() {
  cat > "$task" <<EOF
---
task_id: TRANSITION-1
type: bugfix
delivery_level: standard_delivery
status: review
validation_static: ${1}
validation_runtime: ${2}
validation_acceptance: ${3}
fix_status: pending
---
## 下一步决策
- 当前阶段：pr_review
- 动作：COMPLETE
- 目标阶段：loop_closeout
EOF
}

write_task PASS PASS NOT_RUN
if "${WORKFLOW_ROOT}/cli/ai-workflow" transition "$task" >"${temp_root}/red.out" 2>&1; then
  fail "completion without acceptance unexpectedly applied"
fi
assert_file_contains "${temp_root}/red.out" "validation_static/runtime/acceptance all PASS"
assert_file_contains "$task" "status: review"

write_task PASS PASS PASS
"${WORKFLOW_ROOT}/cli/ai-workflow" transition "$task" >"${temp_root}/green.out"
assert_file_contains "${temp_root}/green.out" "Transition: APPLIED review -> done"
assert_file_contains "$task" "status: done"
assert_file_contains "$task" "fix_status: fixed"

cat > "$task" <<'EOF'
---
task_id: TRANSITION-2
type: bugfix
delivery_level: standard_delivery
status: self_test_in_progress
validation_static: PASS
validation_runtime: FAIL
validation_acceptance: NOT_RUN
fix_status: reverted
---
## 下一步决策
- 当前阶段：self_test
- 动作：RETURN
- 目标阶段：coding
EOF
"${WORKFLOW_ROOT}/cli/ai-workflow" next --apply "$task" >"${temp_root}/return.out"
assert_file_contains "${temp_root}/return.out" "Transition: APPLIED self_test_in_progress -> implement"
assert_file_contains "$task" "status: implement"
assert_file_contains "$task" "fix_status: reverted"

printf '%s\n' "test_transition: PASS"
