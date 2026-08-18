#!/usr/bin/env bash
set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/test_helper.sh"

router_file="${WORKFLOW_ROOT}/core/agents/00_router_agent.md"
defaults_file="${WORKFLOW_ROOT}/core/config/core-defaults.yaml"
self_test_file="${WORKFLOW_ROOT}/core/agents/05_self_test_agent.md"
commit_file="${WORKFLOW_ROOT}/core/agents/08_commit_agent.md"
grill_file="${WORKFLOW_ROOT}/skills/grill-me/SKILL.md"
task_template="${WORKFLOW_ROOT}/core/templates/task_card_template.md"

for risk_level in L1 L2 L3; do
  assert_file_contains "$router_file" "$risk_level"
done

for action in STAY ADVANCE RETURN ESCALATE STOP COMPLETE; do
  assert_file_contains "$defaults_file" "$action"
done

for gate_result in PASS FAIL NOT_RUN N/A BLOCKED; do
  assert_file_contains "$self_test_file" "$gate_result"
done

assert_file_contains "$router_file" "ALIGNMENT_PENDING"
assert_file_contains "$self_test_file" "READY_FOR_SELF_TEST"
assert_file_contains "$self_test_file" "READY_FOR_QA"
assert_file_contains "$commit_file" '`git add`'
assert_file_contains "$commit_file" '`git commit`'
assert_file_contains "$commit_file" '`git push`'
assert_file_contains "$grill_file" 'CLARIFICATION_PENDING` is a hard boundary'
assert_file_contains "$grill_file" '唯一下一步'
assert_file_contains "$task_template" 'CHANGED_PENDING_SELF_TEST / REVERTED / NO_CHANGE'
assert_file_contains "$self_test_file" 'REVERTED'

AI_ADAPTER_ID=demo-project \
  "${WORKFLOW_ROOT}/tool/test_ai_loop_next.sh" \
  "${WORKFLOW_ROOT}/examples/demo-project" >/dev/null
LC_ALL=C LANG=C AI_ADAPTER_ID=demo-project \
  "${WORKFLOW_ROOT}/tool/test_ai_loop_next.sh" \
  "${WORKFLOW_ROOT}/examples/demo-project" >/dev/null

printf '%s\n' "test_behavior_regression: PASS"
