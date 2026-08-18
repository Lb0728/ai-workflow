# Micro Change Record

---
task_id:
title:
type: bugfix | feature | techdebt
priority: P0 | P1 | P2
delivery_level: micro_change
self_test_level: quick
mode: plan | execute | verify | review
status: requirement_breakdown | analyze | implement | ready_for_self_test | self_test_in_progress | review | commit_ready | ready_for_qa | done | blocked
qa_status: pending | ready_for_qa | ready_for_qa_with_risk | not_ready_for_qa
created_at:
updated_at:
legacy: false
context_budget: L1
required_context: []
---

## 目标

单点要改成什么。

## 范围

只允许修改的文件 / 页面 / 样式点。

## 不做

不改变业务行为、不改接口、不改状态流。

## 交付风险信号

> 默认按 L1 极简执行；发现接口、共享状态、多模块、历史缺陷或范围不清时立即 `ESCALATE`。

- core_user_flow: false
- api_contract_changed: false
- shared_state_changed: false
- multiple_modules_affected: false
- multiple_repositories_affected: false
- similar_defect_happened_before: false
- impact_scope_unclear: false
- architecture_boundary_involved: false
- real_device_or_production_required: false
- 风险证据：
  -
- 建议交付强度：L1
- 最终 delivery_level：micro_change

## Bugfix 诊断证据

> 仅 `type: bugfix` 使用。

- 实际现象：
- 触发条件：
- 预期行为：
- 根因结论：
- 根因证据：
  -
- 最小修改范围：
- 禁止修改范围：
- 验证计划：

## Requirement Clarification Result

> 可选。仅在经过 `$grill-me` 或同等澄清后填写；不要把用户描述或假设写成已确认事实。

- 原始诉求：
- 已确认事实：
- 用户描述但未验证：
- 假设与待验证点：
- 本次目标：
- 要做：
- 不做：
- 关键规则 / 不可破坏项：
- 验收标准：
- 当前风险：
- 自动路由结果：

## Fast Path Check

> 不生成完整证据报告。只确认：真源是否明确、是否可复用已有路径、是否存在符合严格定义的 Blocker；其余记为 Warning / Follow-up / Manual Verification。

- 真源与来源：
- 可复用路径：
- 当前结论：继续 / Warning / Blocker

## 验证

- L0 Diff Gate（变更范围检查）: NOT_RUN
  - 证据：
- L1 Basic Run Gate（基础可运行检查）: NOT_RUN
  - 证据：
- L2 Page Verification Gate（页面验证）: NOT_RUN
  - 证据：
- L3 Direct Regression Gate（直接影响回归）: NOT_RUN
  - 证据或 N/A 原因：
- Diff Review Lite Gate（轻量变更评审）: NOT_RUN
  - 证据：

## Implement Summary

- 修改文件：
- 关键改动：
- 影响范围：
- 对应验收项：
- 建议自测等级：
- 已知限制：
- 当前状态：READY_FOR_SELF_TEST

## Self Test

self_test_level:
automatic_checks:
manual_checks:
evidence:
untested_items:
known_risks:
release_result:

## Self Test 红绿灯

总体：[绿] / [黄] / [红]
L0 [绿] | L1 [绿] | L2 [黄] | L3 [绿] | DiffReview [绿]

- 绿灯依据：
- 黄灯依据：
- 红灯依据：

## Bugfix 自测证据

- 测试结果：
- 原问题场景验证：
- 回归检查范围：
- 未验证项：

## 提测结论

- 结论：
- 未测项与原因：
- 下一阶段动作：
  - 目标阶段：PR Review Agent / Coding Agent / Commit Agent / DONE / 人工验证回填 / BLOCKED
  - 具体动作：
  - 是否需要人工输入：

## Done

> 不需要提交或提交信息时使用。`DONE` 表示本轮 AI Loop 已完成到用户要求的终点，不代表工作区已提交。

- 是否进入 DONE：
- 完成依据：
- 提交处理：不提交 / 不需要 commit message / 已另行处理
- 工作区状态：未暂存 / 未提交 / 已提交 / N/A
- 后续如需提交：

## Loop Closeout

> 每次阶段输出和记录更新都必须填写，方便 Owner 判断当前是否真正 Done。

- 当前状态：IMPLEMENT / READY_FOR_SELF_TEST / SELF_TEST_IN_PROGRESS / REVIEW / COMMIT_READY / DONE / BLOCKED
- 下一阶段：
- 是否 Done：是 / 否
- Done 依据：如果是 DONE，列出代码、自测、Review、提交处理已经如何闭环；如果不是 DONE，写 N/A
- 唯一下一步：如果不是 DONE，只写一个可执行动作；如果是 DONE，写“无”
- 是否需要 Owner 输入：是 / 否；如果是，说明需要谁回填什么

## 流程成本记录

- 最终交付强度：L1
- 实际经过的 Agent：
- 跳过的非必要阶段：Requirement / Architecture / Full Review / Defect Memory，或写实际结果
- 读取的缺陷卡数量：0
- 是否复用上游证据：是 / 否
- 是否发生 ESCALATE：否 / L1->L2 / L1->L3

## 下一步决策

> 仅 Bugfix 链路强制使用。动作只允许 `STAY / ADVANCE / RETURN / STOP / COMPLETE / ESCALATE`。

- 当前阶段：
- 当前结论：
- 证据：
  -
- 缺少证据：
- 动作：
- 目标阶段：
- 决策原因：
- 升级前 delivery_level：
- 升级后 delivery_level：
- 触发风险信号：
- 阻塞原因：
- 已完成内容：
- 缺少信息或资源：
- 人工下一步：
- 恢复后返回阶段：
- Self Test 失败分类：NONE / IMPLEMENTATION_ERROR / ROOT_CAUSE_ERROR / REQUIREMENT_ERROR / ENVIRONMENT_BLOCKED

## 下一步动作

下一步只写一个最小动作，并必须和 `Loop Closeout` 的“唯一下一步”一致。
必须写成可执行承接动作，包含目标阶段、目标 Agent、最小动作和是否需要人工输入。
如果下一步不需要人工确认、人工验证、环境/设备条件或 Commit / Push 权限，应在当前会话主动继续执行，不等待 Owner 再说“继续”。
