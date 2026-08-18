#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
NEXT_SCRIPT="${AI_LOOP_NEXT_SCRIPT:-${SCRIPT_DIR}/ai_loop_next.sh}"
PROJECT_ROOT="${1:-${AI_PROJECT_ROOT:-}}"
TEST_TMP="$(mktemp -d)"
trap 'rm -rf "$TEST_TMP"' EXIT

failures=0

if [ -z "$PROJECT_ROOT" ] || [ ! -d "$PROJECT_ROOT" ]; then
  printf '%s\n' "Usage: ./tool/test_ai_loop_next.sh <project-root>"
  exit 2
fi

assert_contains() {
  local name="$1"
  local output="$2"
  local expected="$3"
  if printf '%s\n' "$output" | grep -F -- "$expected" >/dev/null; then
    echo "PASS ${name}: ${expected}"
  else
    echo "FAIL ${name}: missing ${expected}"
    failures=$((failures + 1))
  fi
}

run_case() {
  AI_PROJECT_ROOT="$PROJECT_ROOT" "$NEXT_SCRIPT" "$1"
}

cat > "${TEST_TMP}/advance-coding.md" <<'EOF'
---
task_id: SIM-1
type: bugfix
delivery_level: standard_delivery
status: analyze
legacy: false
---
## Bugfix 诊断证据
- 实际现象：Me 页面套餐不显示，进入 Pet 页面后返回即可显示
- 触发条件：冷启动后直接进入 Me 页面
- 预期行为：Me 页面首次进入即可展示套餐
- 根因结论：套餐加载 owner 只绑定在 Pet 页面生命周期
- 根因证据：
  - Me 页面只读取缓存字段，plans-by-sncodes 仅由 PetMainController.loadNet() 触发
- 最小修改范围：把套餐加载移到共享订阅 owner
- 禁止修改范围：不改套餐接口契约
- 验证计划：冷启动后直接进入 Me，并回归 Pet 页面
## 下一步决策
- 当前阶段：bugfix_diagnosis
- 当前结论：调用链和恢复行为形成完整因果链
- 证据：
  - 进入 Pet 后接口写回套餐字段
- 缺少证据：无
- 动作：ADVANCE
- 目标阶段：coding
- 决策原因：根因、最小修改点和验证方法明确
- Self Test 失败分类：NONE
EOF

cat > "${TEST_TMP}/return-diagnosis.md" <<'EOF'
---
task_id: SIM-2
type: bugfix
delivery_level: standard_delivery
status: self_test_in_progress
legacy: false
---
## 下一步决策
- 当前阶段：self_test
- 当前结论：update() 已执行但原问题仍存在，原 UI 刷新根因不成立
- 证据：
  - 运行日志确认 update() 已调用且页面仍无套餐
- 缺少证据：真实数据写入入口尚未确认
- 动作：RETURN
- 目标阶段：bugfix_diagnosis
- 决策原因：新证据推翻原因果链
- Self Test 失败分类：ROOT_CAUSE_ERROR
EOF

cat > "${TEST_TMP}/stop-human.md" <<'EOF'
---
task_id: SIM-3
type: bugfix
delivery_level: high_risk_delivery
status: analyze
legacy: false
---
## 下一步决策
- 当前阶段：bugfix_diagnosis
- 当前结论：静态链路已确认，动态行为只能在指定 D2 固件与真机验证
- 证据：
  - 代码搜索确认问题路径依赖真实 BLE 回包
- 缺少证据：指定固件的真实回包
- 动作：STOP
- 目标阶段：human
- 决策原因：本地没有必要设备与固件
- 阻塞原因：缺少指定 D2 真机
- 已完成内容：完成静态调用链调查
- 缺少信息或资源：D2 真机和目标固件版本
- 人工下一步：Owner 提供设备并执行固定复现步骤
- 恢复后返回阶段：bugfix_diagnosis
- Self Test 失败分类：ENVIRONMENT_BLOCKED
EOF

cat > "${TEST_TMP}/return-coding.md" <<'EOF'
---
task_id: SIM-4
type: bugfix
delivery_level: standard_delivery
status: self_test_in_progress
legacy: false
---
## 下一步决策
- 当前阶段：self_test
- 当前结论：根因成立，但实现遗漏第二个赋值入口
- 证据：
  - 目标测试命中未修改的第二个调用点
- 缺少证据：无
- 动作：RETURN
- 目标阶段：coding
- 决策原因：属于已确认方案的实现遗漏
- Self Test 失败分类：IMPLEMENTATION_ERROR
EOF

cat > "${TEST_TMP}/return-requirement.md" <<'EOF'
---
task_id: SIM-5
type: bugfix
delivery_level: standard_delivery
status: self_test_in_progress
legacy: false
---
## 下一步决策
- 当前阶段：self_test
- 当前结论：离线设备的预期展示规则存在冲突
- 证据：
  - 验收描述与现有产品规则要求不同
- 缺少证据：产品对离线展示的最终口径
- 动作：RETURN
- 目标阶段：requirement_breakdown
- 决策原因：实现无法决定产品规则
- Self Test 失败分类：REQUIREMENT_ERROR
EOF

cat > "${TEST_TMP}/insufficient-evidence.md" <<'EOF'
---
task_id: SIM-6
type: bugfix
delivery_level: standard_delivery
status: analyze
legacy: false
---
## Bugfix 诊断证据
- 实际现象：页面偶尔不刷新
- 触发条件：未知
- 预期行为：页面展示最新数据
- 根因结论：可能是 update() 未调用
- 根因证据：
- 最小修改范围：待确认
- 验证计划：待确认
## 下一步决策
- 当前阶段：bugfix_diagnosis
- 当前结论：怀疑 UI 未刷新
- 证据：
  - 只有现象描述，尚无调用链或日志
- 缺少证据：触发条件、代码链路和最小验证方案
- 动作：ADVANCE
- 目标阶段：coding
- 决策原因：建议尝试调用 update()
- Self Test 失败分类：NONE
EOF

cat > "${TEST_TMP}/advance-review.md" <<'EOF'
---
task_id: SIM-7
type: bugfix
delivery_level: standard_delivery
status: self_test_in_progress
legacy: false
---
## 提测门禁结果
- L0 Diff Gate（变更范围检查）: PASS
- L1 Basic Run Gate（基础可运行检查）: PASS
- L2 Feature Verification Gate（本功能验证）: PASS
- L3 Direct Regression Gate（直接影响回归）: PASS
## Bugfix 自测证据
- 测试结果：目标测试和静态检查通过
- 原问题场景验证：冷启动直达 Me 已展示套餐
- 回归检查范围：Pet 套餐与设备切换
- 未验证项：无
## Self Test 红绿灯
总体：[绿] 可提测
L0 [绿] | L1 [绿] | L2 [绿] | L3 [绿]
- 绿灯依据：L0-L3 PASS
- 黄灯依据：无
- 红灯依据：无
## 下一步决策
- 当前阶段：self_test
- 当前结论：原问题和直接回归均验证通过
- 证据：
  - L0-L3 均有 PASS 记录
- 缺少证据：无
- 动作：ADVANCE
- 目标阶段：pr_review
- 决策原因：Self Test Gate 满足
- Self Test 失败分类：NONE
EOF

cat > "${TEST_TMP}/l1-fast-path.md" <<'EOF'
---
task_id: SIM-8
type: bugfix
delivery_level: light_feature
self_test_level: quick
status: analyze
legacy: false
---
## 交付风险信号
- core_user_flow: false
- api_contract_changed: false
- shared_state_changed: false
- multiple_modules_affected: false
- multiple_repositories_affected: false
- similar_defect_happened_before: false
- impact_scope_unclear: false
- architecture_boundary_involved: false
- real_device_or_production_required: false
- 风险证据：无
## Bugfix 诊断证据
- 实际现象：单页面图标间距错误
- 触发条件：打开目标页面
- 预期行为：图标使用设计间距
- 根因结论：目标组件写错固定间距
- 根因证据：
  - 目标组件常量与设计 token 不一致
- 最小修改范围：单个组件常量
- 验证计划：页面检查并回归相邻按钮
## 下一步决策
- 当前阶段：bugfix_diagnosis
- 当前结论：单文件局部修复且无风险信号
- 证据：
  - 只影响目标组件样式常量
- 缺少证据：无
- 动作：ADVANCE
- 目标阶段：coding
- 决策原因：满足 L1 快速路径
- Self Test 失败分类：NONE
EOF

cat > "${TEST_TMP}/risk-needs-escalation.md" <<'EOF'
---
task_id: SIM-9
type: bugfix
delivery_level: light_feature
self_test_level: quick
status: analyze
legacy: false
---
## 交付风险信号
- core_user_flow: false
- api_contract_changed: false
- shared_state_changed: true
- multiple_modules_affected: true
- multiple_repositories_affected: false
- similar_defect_happened_before: false
- impact_scope_unclear: false
- architecture_boundary_involved: false
- real_device_or_production_required: false
- 风险证据：搜索确认三个模块写入同一 Session 状态
## Bugfix 诊断证据
- 实际现象：登录后 loading 不结束
- 触发条件：接口字段为空
- 预期行为：Session 进入明确失败或 Ready 状态
- 根因结论：共享 Session 状态未完成流转
- 根因证据：
  - 三个模块存在写入口
- 最小修改范围：待边界分析
- 验证计划：登录状态矩阵
## 下一步决策
- 当前阶段：bugfix_diagnosis
- 当前结论：尝试按轻量任务直接修复
- 证据：
  - 已确认共享状态跨模块写入
- 缺少证据：owner 和完整影响范围
- 动作：ADVANCE
- 目标阶段：coding
- 决策原因：尝试局部修改
- Self Test 失败分类：NONE
EOF

cat > "${TEST_TMP}/escalate-l3.md" <<'EOF'
---
task_id: SIM-10
type: bugfix
delivery_level: high_risk_delivery
self_test_level: specialized
alignment_required: true
alignment_status: pending
status: analyze
legacy: false
---
## 交付风险信号
- core_user_flow: false
- api_contract_changed: false
- shared_state_changed: true
- multiple_modules_affected: true
- multiple_repositories_affected: false
- similar_defect_happened_before: false
- impact_scope_unclear: false
- architecture_boundary_involved: true
- real_device_or_production_required: false
- 风险证据：Session 状态跨模块写入且 owner 不明确
## 下一步决策
- 当前阶段：bugfix_diagnosis
- 当前结论：原 L1 判断被共享状态与架构边界证据推翻
- 证据：
  - 搜索确认三个写入口
- 缺少证据：完整 Change Impact
- 动作：ESCALATE
- 目标阶段：bugfix_diagnosis
- 决策原因：先补历史缺陷和影响分析
- 升级前 delivery_level：light_feature
- 升级后 delivery_level：high_risk_delivery
- 触发风险信号：shared_state_changed, architecture_boundary_involved
- Self Test 失败分类：NONE
EOF

cat > "${TEST_TMP}/l3-ready-for-coding.md" <<'EOF'
---
task_id: SIM-11
type: bugfix
delivery_level: high_risk_delivery
self_test_level: specialized
alignment_required: true
alignment_status: confirmed
status: analyze
legacy: false
---
## 交付风险信号
- core_user_flow: true
- api_contract_changed: true
- shared_state_changed: false
- multiple_modules_affected: true
- multiple_repositories_affected: false
- similar_defect_happened_before: false
- impact_scope_unclear: false
- architecture_boundary_involved: false
- real_device_or_production_required: false
- 风险证据：Auth API 字段变化影响登录初始化
## Bugfix 诊断证据
- 实际现象：登录成功后初始化停留在 loading
- 触发条件：Auth API 新字段为空
- 预期行为：登录状态进入 Ready 或明确失败
- 根因结论：DTO 空值路径未映射为 Session 状态
- 根因证据：
  - 请求回放确认空值分支没有状态写入
- 最小修改范围：Auth repository DTO 映射
- 验证计划：成功、失败、空值、超时和重新登录
## 缺陷 Memory 检索
- 检索关键词：auth session login
- 检索命令：./ai/tool/ai_defect_memory_search.sh auth session login
- 命中缺陷卡：未找到相关历史缺陷记录
- 历史根因：N/A
- 本次重新引入风险：N/A
- 必须回归的历史场景：N/A
- 检索结论：未找到相关历史缺陷记录
## Change Impact Analysis
- 变化入口：Auth API DTO mapper
- 受影响业务状态：Session ready / failed
- 状态 owner / 数据真源：SessionStore
- 写入方与读取方：AuthCoordinator 写，Bootstrap 读
- API 成功 / 失败 / 空值 / 超时路径：四条路径均已列出
- 初始化与状态恢复路径：首次登录、重新登录、token 过期
- 相邻业务场景：启动恢复和退出登录
- 涉及模块 / 仓库：session 与 auth，单仓库
- 明确不受影响范围：设备运行态
## 必要门禁
- Architecture Gate（架构门禁）: PASS
## 下一步决策
- 当前阶段：bugfix_diagnosis
- 当前结论：L3 前置证据已完整
- 证据：
  - 定向 Memory 和 Change Impact 已完成
- 缺少证据：无
- 动作：ADVANCE
- 目标阶段：coding
- 决策原因：根因、影响范围和验证矩阵明确
- Self Test 失败分类：NONE
EOF

cat > "${TEST_TMP}/l3-self-test.md" <<'EOF'
---
task_id: SIM-12
type: bugfix
delivery_level: high_risk_delivery
self_test_level: specialized
alignment_required: true
alignment_status: confirmed
status: self_test_in_progress
legacy: false
---
## 交付风险信号
- core_user_flow: true
- api_contract_changed: true
- shared_state_changed: true
- multiple_modules_affected: true
- multiple_repositories_affected: false
- similar_defect_happened_before: true
- impact_scope_unclear: false
- architecture_boundary_involved: true
- real_device_or_production_required: false
- 风险证据：登录链路存在历史逃逸且本次修改 API 与 Session 状态
## 提测门禁结果
- L0 Diff Gate（变更范围检查）: PASS
- L1 Basic Run Gate（基础可运行检查）: PASS
- L2 Feature Verification Gate（本功能验证）: PASS
- L3 Direct Regression Gate（直接影响回归）: PASS
- High Risk Gate（高风险专项）: PASS
- Historical Regression Gate（历史缺陷回归）: PASS
## 必要门禁
- Architecture Gate（架构门禁）: PASS
## Bugfix 自测证据
- 测试结果：目标测试和状态矩阵通过
- 原问题场景验证：首次登录进入 Ready
- 回归检查范围：登录、退出、token 过期、启动恢复
- 未验证项：无
- 历史缺陷场景：历史 loading 卡死场景通过
- 相邻业务场景：退出后重新登录通过
- 接口异常场景：失败、空值、超时均进入明确状态
- 状态恢复场景：冷启动和 token 过期恢复通过
## Self Test 红绿灯
总体：[绿] 可提测
L0 [绿] | L1 [绿] | L2 [绿] | L3 [绿] | HighRisk [绿] | Historical [绿]
- 绿灯依据：L3 回归矩阵全部 PASS
- 黄灯依据：无
- 红灯依据：无
## 下一步决策
- 当前阶段：self_test
- 当前结论：L3 回归矩阵通过
- 证据：
  - 当前问题、历史缺陷、接口异常和状态恢复均有记录
- 缺少证据：无
- 动作：ADVANCE
- 目标阶段：pr_review
- 决策原因：所有 L3 Gate 满足
- Self Test 失败分类：NONE
EOF

cat > "${TEST_TMP}/feature-risk-escalation.md" <<'EOF'
---
task_id: SIM-14
type: feature
delivery_level: light_feature
self_test_level: quick
status: implement
legacy: false
---
## 交付风险信号
- core_user_flow: false
- api_contract_changed: true
- shared_state_changed: false
- multiple_modules_affected: false
- multiple_repositories_affected: false
- similar_defect_happened_before: false
- impact_scope_unclear: false
- architecture_boundary_involved: false
- real_device_or_production_required: false
- 风险证据：需求确认需要修改 API 响应契约
EOF

output="$(run_case "${TEST_TMP}/advance-coding.md")"
assert_contains "明确根因推进" "$output" "- 阶段：implement"
assert_contains "明确根因 Agent" "$output" "- Agent：coding"
assert_contains "明确根因决策 Gate" "$output" "## 决策协议错误"
assert_contains "明确根因无决策错误" "$output" "- 无"

output="$(AI_PROJECT_ROOT="$PROJECT_ROOT" "$NEXT_SCRIPT" "${TEST_TMP}/advance-coding.md" review)"
assert_contains "显式阶段不能绕过决策" "$output" "- 阶段：implement"
assert_contains "显式阶段冲突告警" "$output" "与 next_action_decision 路由 ADVANCE -> coding 不一致"

output="$(run_case "${TEST_TMP}/return-diagnosis.md")"
assert_contains "根因推翻回退" "$output" "- 阶段：analyze"
assert_contains "根因推翻 Agent" "$output" "- Agent：bugfix"

output="$(run_case "${TEST_TMP}/stop-human.md")"
assert_contains "设备阻塞停止" "$output" "- 阶段：blocked"
assert_contains "设备阻塞动作" "$output" "- 动作：STOP"

output="$(run_case "${TEST_TMP}/return-coding.md")"
assert_contains "实现错误回退" "$output" "- 阶段：implement"
assert_contains "实现错误 Agent" "$output" "- Agent：coding"

output="$(run_case "${TEST_TMP}/return-requirement.md")"
assert_contains "需求错误回退" "$output" "- 阶段：requirement_breakdown"
assert_contains "需求错误 Agent" "$output" "- Agent：requirement"

output="$(run_case "${TEST_TMP}/insufficient-evidence.md")"
assert_contains "证据不足留在诊断" "$output" "- 阶段：analyze"
assert_contains "证据不足 Gate" "$output" "decision gate：Bugfix 诊断证据.触发条件 缺失"

output="$(run_case "${TEST_TMP}/advance-review.md")"
assert_contains "自测通过推进 Review" "$output" "- 阶段：review"
assert_contains "自测通过 Review Agent" "$output" "- Agent：review"

output="$(run_case "${TEST_TMP}/l1-fast-path.md")"
assert_contains "L1 快速路径" "$output" "- 交付强度：L1"
assert_contains "L1 直接 Coding" "$output" "- 阶段：implement"
assert_contains "L1 极简上下文" "$output" "极简：只读任务摘要"

output="$(run_case "${TEST_TMP}/risk-needs-escalation.md")"
assert_contains "高风险自动识别" "$output" "- 建议交付强度：L3"
assert_contains "高风险阻止 Coding" "$output" "- 阶段：analyze"
assert_contains "高风险要求 ESCALATE" "$output" "风险信号要求先 ESCALATE 到 L3"

output="$(run_case "${TEST_TMP}/escalate-l3.md")"
assert_contains "ESCALATE 动作" "$output" "- 动作：ESCALATE"
assert_contains "ESCALATE 更新等级" "$output" "- 升级后 delivery_level：high_risk_delivery"
assert_contains "ESCALATE 返回诊断" "$output" "- 阶段：analyze"

output="$(run_case "${TEST_TMP}/l3-ready-for-coding.md")"
assert_contains "L3 完整证据进入 Coding" "$output" "- 阶段：implement"
assert_contains "L3 定向上下文" "$output" "最多 5 张命中缺陷卡"

sed 's/Architecture Gate（架构门禁）: PASS/Architecture Gate（架构门禁）: NOT_RUN/' \
  "${TEST_TMP}/l3-ready-for-coding.md" > "${TEST_TMP}/l3-missing-architecture.md"
output="$(run_case "${TEST_TMP}/l3-missing-architecture.md")"
assert_contains "L3 缺架构 Gate 阻止 Coding" "$output" "- 阶段：analyze"
assert_contains "L3 架构 Gate 错误" "$output" "risk gate：L3 进入 Coding 前 Architecture Gate 必须为 PASS"

output="$(run_case "${TEST_TMP}/l3-self-test.md")"
assert_contains "L3 回归通过进入 Review" "$output" "- 阶段：review"
assert_contains "L3 历史回归 Gate" "$output" "- Historical Regression Gate：PASS"

output="$(run_case "${TEST_TMP}/feature-risk-escalation.md")"
assert_contains "Feature 风险自动升级" "$output" "- 建议交付强度：L3"
assert_contains "Feature 风险阻止轻量实现" "$output" "- 阶段：analyze"
assert_contains "Feature 返回 Requirement" "$output" "- Agent：requirement"

memory_output="$(bash "${SCRIPT_DIR}/ai_defect_memory_search.sh" __no_such_verified_defect__)"
if [ -z "$memory_output" ]; then
  echo "PASS 缺陷 Memory 无命中时返回空结果"
else
  echo "FAIL 缺陷 Memory 无命中时不应返回文件"
  failures=$((failures + 1))
fi

if [ "$failures" -ne 0 ]; then
  echo "FAILED: ${failures} assertion(s)"
  exit 1
fi

echo "ALL PASS: 14 risk-adaptive routing scenarios"
