#!/usr/bin/env bash
# Commit policy ownership tests:
#   - Company Policy is the Commit rule source of truth;
#   - project Adapter commit rules mirror the Core policy keys;
#   - Host entries and Core Agents do not claim Commit ownership.

set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/test_helper.sh"

for required_key in title_pattern change_types fix_body source_of_truth; do
  assert_file_contains "${WORKFLOW_ROOT}/adapters/demo-project/config/commit.yaml" "$required_key"
done

for section_name in \
  "BUG根因分析" \
  "引入问题的提交" \
  "引入问题时如何有效拦截" \
  "修复后做了哪些自测"; do
  assert_file_contains "${WORKFLOW_ROOT}/policies/company/commit-convention.yaml" "$section_name"
done

assert_file_contains "${WORKFLOW_ROOT}/core/agents/08_commit_agent.md" \
  "Company Policy 是公司 Commit 规则真源"
assert_file_contains "${WORKFLOW_ROOT}/policies/company/commit-convention.yaml" \
  "source_of_truth: Company Policy"
assert_file_contains "${WORKFLOW_ROOT}/policies/company/commit-convention.yaml" \
  "project_supplements: .ai/policies/"
assert_file_contains "${WORKFLOW_ROOT}/core/agents/08_commit_agent.md" \
  '`.ai/policies/` 只补充项目规则'
assert_file_contains "${WORKFLOW_ROOT}/hosts/codex/entry-template/AGENTS.block.md" \
  "not the complete Commit policy source"
if grep -R -F "仓库规则是仓库级编码规则、提交流程和改动输出要求的真源" \
  "${WORKFLOW_ROOT}/core/agents" >/dev/null; then
  fail "Core still assigns complete Commit policy ownership to Host repository rules"
fi

printf '%s\n' "test_company_commit: PASS"
