#!/usr/bin/env bash
set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

tests=(
  test_discovery.sh
  test_zephyr_discovery.sh
  test_zephyr_build.sh
  test_zephyr_safety.sh
  test_init.sh
  test_loader_v2.sh
  test_feedback.sh
  test_codex_host.sh
  test_cursor_host.sh
  test_company_commit.sh
  test_compat.sh
  test_skills.sh
  test_core_boundary.sh
  test_project_independence.sh
  test_host_adapter_contract.sh
  test_model_independence.sh
  test_behavior_regression.sh
  test_router_v2.sh
  test_transition.sh
  test_task_card_schema.sh
  test_quality_gate.sh
  test_cross_host_router.sh
  test_context_budget.sh
  test_platform_compat.sh
  test_package_v2.sh
)

for test_script in "${tests[@]}"; do
  "${SCRIPT_DIR}/${test_script}"
done

printf '%s\n' "V2 acceptance suite: PASS"
