#!/usr/bin/env bash
set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/test_helper.sh"

temp_root="$(mktemp -d "${TMPDIR:-/tmp}/workflow-context.XXXXXX")"
trap 'rm -rf "$temp_root"' EXIT

task_file="${temp_root}/task.md"
{
  printf '%s\n' "task_type: bugfix"
  printf '%s\n' "risk_level: L2"
  printf '%s\n' "current_stage: analyze"
  printf '%s\n' "# Context budget fixture"
} > "$task_file"

v1_output="${temp_root}/v1.out"
AI_ADAPTER_ID=demo-project \
  "${WORKFLOW_ROOT}/tool/ai_agent.sh" \
  --project-root "${WORKFLOW_ROOT}/examples/demo-project" \
  --adapter demo-project \
  --role developer \
  --context-mode minimal \
  router "$task_file" > "$v1_output"

v2_project="${temp_root}/v2-project"
copy_fixture go "$v2_project"
git -C "$v2_project" init -q
"${WORKFLOW_ROOT}/cli/ai-workflow" init --project-root "$v2_project" --host codex >/dev/null
empty_l1_output="${temp_root}/v2-empty-l1.out"
"${WORKFLOW_ROOT}/cli/ai-workflow" assemble \
  --project-root "$v2_project" router "$task_file" > "$empty_l1_output"

i=1
while [ "$i" -le 30 ]; do
  {
    printf '# Architecture fixture %s\n' "$i"
    printf 'ARCHITECTURE-BULK-MARKER-%s\n' "$i"
    line=1
    while [ "$line" -le 100 ]; do
      printf 'large architecture knowledge line %s\n' "$line"
      line=$((line + 1))
    done
  } > "${v2_project}/.ai/architecture/area-${i}.md"
  i=$((i + 1))
done

i=1
while [ "$i" -le 8 ]; do
  {
    printf '# Defect fixture %s\n' "$i"
    printf 'DEFECT-%s-MARKER\n' "$i"
  } > "${v2_project}/.ai/defects/defect-${i}.md"
  i=$((i + 1))
done

large_l1_output="${temp_root}/v2-large-l1.out"
"${WORKFLOW_ROOT}/cli/ai-workflow" assemble \
  --project-root "$v2_project" router "$task_file" > "$large_l1_output"

v1_bytes="$(wc -c < "$v1_output" | tr -d ' ')"
v2_bytes="$(wc -c < "$large_l1_output" | tr -d ' ')"
maximum_bytes=$((v1_bytes * 2))
[ "$v2_bytes" -le "$maximum_bytes" ] ||
  fail "V2 minimal Router context exceeds 2x the V1 baseline (${v2_bytes} > ${maximum_bytes})"

empty_l1_bytes="$(wc -c < "$empty_l1_output" | tr -d ' ')"
growth_bytes=$((v2_bytes - empty_l1_bytes))
[ "$growth_bytes" -le 256 ] ||
  fail "L1 context grows with full Project Local Knowledge (${growth_bytes} bytes)"
if grep -Fq "ARCHITECTURE-BULK-MARKER" "$large_l1_output" ||
  grep -Fq "DEFECT-1-MARKER" "$large_l1_output"; then
  fail "L1 assembly inlined Project Local Knowledge bodies"
fi

l2_task="${temp_root}/l2-task.md"
{
  printf '%s\n' "---"
  printf '%s\n' "delivery_level: standard_delivery"
  printf '%s\n' "context_budget: L2"
  printf '%s\n' "required_context:"
  printf '%s\n' "  - .ai/architecture/area-2.md"
  printf '%s\n' "---"
  printf '%s\n' "# L2 selected context"
} > "$l2_task"
l2_output="$("${WORKFLOW_ROOT}/cli/ai-workflow" assemble \
  --project-root "$v2_project" coding "$l2_task")"
assert_output_contains "$l2_output" "ARCHITECTURE-BULK-MARKER-2"
if printf '%s\n' "$l2_output" | grep -Fq "ARCHITECTURE-BULK-MARKER-3"; then
  fail "L2 assembly loaded non-selected architecture knowledge"
fi

l3_task="${temp_root}/l3-task.md"
{
  printf '%s\n' "---"
  printf '%s\n' "delivery_level: high_risk_delivery"
  printf '%s\n' "context_budget: L3"
  printf '%s\n' "required_context:"
  printf '%s\n' "  - .ai/architecture/area-1.md"
  i=1
  while [ "$i" -le 7 ]; do
    printf '  - .ai/defects/defect-%s.md\n' "$i"
    i=$((i + 1))
  done
  printf '%s\n' "---"
  printf '%s\n' "# L3 bounded defects"
} > "$l3_task"
l3_output="$("${WORKFLOW_ROOT}/cli/ai-workflow" assemble \
  --project-root "$v2_project" architecture_boundary "$l3_task")"
assert_output_contains "$l3_output" "ARCHITECTURE-BULK-MARKER-1"
assert_output_contains "$l3_output" "DEFECT-5-MARKER"
if printf '%s\n' "$l3_output" | grep -Fq "DEFECT-6-MARKER"; then
  fail "L3 assembly loaded more than five defect cards"
fi

printf 'test_context_budget: PASS (v1=%s, l1-empty=%s, l1-large=%s, growth=%s bytes)\n' \
  "$v1_bytes" "$empty_l1_bytes" "$v2_bytes" "$growth_bytes"
