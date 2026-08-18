# Task Card Template

> 用途：让 当前 AI Host Loop 有可恢复的状态，并把任务推进到可信提测结论。
> 使用方式：复制本文件到 Loader 解析出的 `runtime.tasks`，提单阶段只填确定事实；不确定的信息留空。
> `影响地图`、`最小实现计划`、`门禁结果` 由 当前 AI Host 在 `ANALYZE / IMPACT_MAP` 阶段基于源码和证据回填。

---
task_id:
title:
type: bugfix | feature | techdebt | device
priority: P0 | P1 | P2
delivery_level: standard_delivery | high_risk_delivery
self_test_level: standard | specialized
alignment_required: false
alignment_status: not_required
alignment_confirmed_at:
alignment_confirmation_note:
risk: low | normal | high
mode: discuss | plan | execute | verify | review
status: requirement_breakdown | analyze | impact_map | architecture | capability | alignment_pending | fix_ready | implement | ready_for_self_test | validation_pending | self_test_in_progress | review | commit_ready | blocked | ready_for_qa | done
qa_status: pending | ready_for_qa | ready_for_qa_with_risk | not_ready_for_qa
validation_static: NOT_RUN | PASS | FAIL
validation_runtime: NOT_RUN | PASS | FAIL | BLOCKED
validation_acceptance: NOT_RUN | PASS | FAIL | BLOCKED
fix_status: pending | fixed | reverted | no_change
iteration: 0
max_iterations: 2
owner:
created_at:
updated_at:
legacy: false
context_budget: L1 | L2 | L3
required_context: []
---

## 目标

本次任务要达成什么结果。

## 交付等级

> 交付等级决定本任务应承担的研发流程成本，不等于业务优先级。
> 小任务只承担它应有的流程成本；完整治理留给真正高风险的任务。

- 当前等级：standard_delivery
- 选择原因：
- 是否命中强制升级：
- 评分明细：
- 原交付等级 / 调整后交付等级 / 调整原因：
- 本任务必须经过的 Agent / Gate：
- 本任务可跳过的 Agent / Gate 及原因：

## 交付风险信号

> Router 只填写有事实依据的布尔值。`micro_change / light_feature` 对应 L1，`standard_delivery` 对应 L2，`high_risk_delivery` 对应 L3。高风险一旦被证据确认，不自动降级。

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
- 建议交付强度：L1 / L2 / L3
- 最终 delivery_level：

## 已确认事实

> 只填写确定事实；不确定的信息留空。
> 对 Feature 来说，只要这里已经写清“用户要看到什么 / 发生在哪个页面或模块 / 已知业务口径”，就可以进入 `ANALYZE`。
> PRD / task reference / 设计稿链接、范围、验收标准不是提单阶段必填项，当前 AI Host 应在 `ANALYZE` 阶段基于已确认事实和源码回填。

- 现象 / 需求：
- 发生页面 / 模块：
- 影响用户 / 设备 / 环境：
- 复现频率（Bugfix）：
- 已知触发条件（没有确定条件则留空）：
- PRD / task reference / 设计稿 / 日志 / 截图：
- Discovery / PRD / Handoff：
- 约束或明确口径：

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

## Decision Evidence

> 仅在提问、`blocked`、`ESCALATE`、扩大范围、新增 bridge / owner / callback / SDK API 或判定不可提测时填写；普通 Fast Path 不要求展开。

- 当前任务要判断什么：
- 已确认事实（含来源）：
- 尚未验证：
- AI 推断：
- 当前结论：可继续自行查证 / 必须用户决策 / Warning / Follow-up / Manual Verification / Blocker

### Decision Correction

> Owner 指出资料漏读、Gate 误判或既有链路漏查时填写；不得要求重复说明已有资料。

- 原判断：
- 错误类型：资料漏读 / Gate 等级误判 / 链路漏查 / 架构原则过度推演 / 假设被当成事实
- 修正后的事实（含来源）：
- 状态修正与恢复阶段：
- 最小后续动作：

## 范围

本次允许分析或修改的范围。

## 不做范围

本次明确不做什么，避免扩大范围。

## 验收标准

- [ ] 验收点 1
- [ ] 验收点 2

## 影响地图

> 中等及以上任务必须填写；小 Bug 可以轻量填写。只写源码和证据支持的结论。

- 入口文件 / 类 / 方法：
- 真实调用链：
- 关键状态或数据流：
- 允许改动范围：
- 直接影响页面 / 模块：
- 直接影响状态 / 数据 / 设备流程：
- 必须回归的旧流程：
- 本次最少必须测试：
- 风险与未知项：

## 缺陷 Memory 检索

> L3 必填；L1 不要求执行。只使用 feature / module / state / API 等当前任务关键词检索，不加载全部缺陷卡。没有命中时明确写“未找到相关历史缺陷记录”。

- 检索关键词：
- 检索命令：
- 命中缺陷卡：
- 历史根因：
- 本次重新引入风险：
- 必须回归的历史场景：
- 检索结论：

## Change Impact Analysis

> L3 必填；L2 按实际影响轻量填写；L1 不要求。复用上游证据，不重新扫描整个仓库。

- 变化入口：
- 受影响业务状态：
- 状态 owner / 数据真源：
- 写入方与读取方：
- API 成功 / 失败 / 空值 / 超时路径：
- 初始化与状态恢复路径：
- 相邻业务场景：
- 涉及模块 / 仓库：
- 明确不受影响范围：

## 最小实现计划

> 进入 `IMPLEMENT` 前必须明确；未明确时不得改代码。
> `high_risk_delivery` 还必须先完成高风险对齐，并记录明确用户确认。

- 改什么：
- 为什么改：
- 不改什么：
- 关键风险：
- 完成后需要验证什么：

## Bugfix 诊断证据

> 仅 `type: bugfix` 使用。进入 Coding 前所有必填项都必须来自已观察、搜索、运行或验证的事实；推测只能留在“缺少证据”。

- 实际现象：
- 触发条件：
- 预期行为：
- 根因结论：
- 根因证据：
  -
- 最小修改范围：
- 禁止修改范围：
- 验证计划：

## 高风险对齐

> 仅 `high_risk_delivery` 必填；普通任务保持 N/A。
> `ALIGNMENT_PENDING` 不是阻塞，而是高风险任务进入实现前的人工确认点。
> 未收到明确确认前，不得进入 `IMPLEMENT`，不得修改业务代码。

- 是否需要对齐：false
- 当前对齐状态：not_required
- 对齐包是否已生成：
- 用户确认记录：
- 阻止实施的原因：

### 对齐包

- 我理解的目标：
- 已确认事实：
- 实际调用链：
- 拟修改范围：
- 不修改范围：
- 关键风险：
- 需要人工确认：
- 最小实现方案：
- 实现后专项验证与回归：

## 必要门禁

> 结果只允许填写：PASS / FAIL / NOT_RUN / N/A / BLOCKED。
> `PASS` 必须有证据；`NOT_RUN` 不等于通过；`N/A` 必须写原因。`BLOCKED` 还必须证明：缺失是当前阶段必要输入、继续会明显错误或高风险、仓库无法补齐、无安全降级、且不能延后到后续 Gate 或人工验证。

- Architecture Gate（架构门禁）: NOT_RUN
  - 需要 / 不需要：
  - 原因：
- i18n / UI Gate（文案与界面门禁）: NOT_RUN
  - 需要 / 不需要：
  - 原因：
- Platform / Transport Gate（平台与传输链路门禁）: NOT_RUN
  - 需要 / 不需要：
  - 原因：
- PR Review Gate（评审门禁）: NOT_RUN
  - 需要 / 不需要：
  - 原因：

### 提测门禁结果

- L0 Diff Gate（变更范围检查）: NOT_RUN
  - 检查 git diff 是否仅包含本任务相关文件；无无关格式化、大范围重构、临时日志、Mock 数据。
- L1 Basic Run Gate（基础可运行检查）: NOT_RUN
  - 静态检查、构建或相关自动化测试。
- L2 Feature Verification Gate（本功能验证）: NOT_RUN
  - 本功能核心验收行为。
- L3 Direct Regression Gate（直接影响回归）: NOT_RUN
  - 同入口、共享状态、同数据链路上的旧功能回归。
- High Risk Gate（高风险专项）: NOT_RUN
  - Project Local Knowledge 声明的高风险型号、transport、升级、数据迁移、登录态、多语言结构或核心数据流专项。
- Historical Regression Gate（历史缺陷回归）: NOT_RUN
  - 有相关缺陷卡或命中 `similar_defect_happened_before` 时必须 PASS；未找到相关历史缺陷时可 N/A 并记录检索证据。

## Implement Summary

> Coding Agent 完成代码后填写。这里只记录实现结果，不输出最终提测结论。

- 修改文件：
- 关键改动：
- 影响范围：
- 对应验收项：
- 建议自测等级：
- 已知限制：
- 当前状态：READY_FOR_SELF_TEST

## Self Test Result

> 只有 Self Test Agent 可以写入最终提测结论。

self_test_level:
automatic_checks:
manual_checks:
gate_status:
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

> 仅 `type: bugfix` 使用。Self Test 推进 PR Review 前必须填写；未验证项没有时明确写“无”。

- 测试结果：
- 原问题场景验证：
- 回归检查范围：
- 未验证项：
- 历史缺陷场景：
- 相邻业务场景：
- 接口异常场景：
- 状态恢复场景：

## 决策记录

| 时间 | 决策 | 原因 | 影响 |
|---|---|---|---|
|  |  |  |  |

## 证据记录

### 分析证据

- 已阅读文件：
- 已确认链路：
- 已排除项：

### 实现证据

- 改动文件：
- 改动原因：
- 未改范围：

### 验证证据

- 命令：
- 输出摘要：
- 人工验证：
- 未覆盖风险：

### 评审证据

- blocking issue：
- non-blocking risk：
- 结论：

## 已知风险 / 未测项

- 未测项：
- 原因：
- 影响：
- 是否可接受：

## 提测结论

> 只能选择一个：READY_FOR_QA / READY_FOR_QA_WITH_RISK / NOT_READY_FOR_QA。

- 结论：
- 本次改动摘要：
- 影响范围：
- 已执行检查及结果：
- 未测项与原因：
- 已知风险：
- 建议测试重点：
- 下一阶段动作：
  - 目标阶段：PR Review Agent / Coding Agent / Commit Agent / DONE / 人工验证回填 / BLOCKED
  - 具体动作：
  - 是否需要人工输入：

## Commit Ready

> Coding、Self Test、PR Review 均完成后，若需要提交信息，进入 `COMMIT_READY`；若用户明确不提交 / 不需要 commit message，Review 通过后进入 `DONE`。
> Commit Agent 只生成可复制 Commit 信息，等待人工手动提交；不得执行 `git add`、`git commit`、`git push`，不得修改暂存内容。

- commit_required: true | false
- 是否进入 COMMIT_READY：
- 前置条件：
- 推荐 Commit 信息生成状态：
- 人工提交负责人：

## Done

> 不需要提交或提交信息时使用。`DONE` 表示本轮 AI Loop 已完成到用户要求的终点，不代表工作区已提交。

- 是否进入 DONE：
- 完成依据：
- 提交处理：不提交 / 不需要 commit message / 已另行处理
- 工作区状态：未暂存 / 未提交 / 已提交 / N/A
- 后续如需提交：

## 当前检查点

当前停在哪个阶段，已经完成了什么。

## 下一步决策

> 仅 Bugfix 链路强制使用。动作只允许 `STAY / ADVANCE / RETURN / STOP / COMPLETE / ESCALATE`；阶段只允许 `requirement_breakdown / bugfix_diagnosis / arch_boundary / coding / self_test / pr_review / human / loop_closeout`。

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

## Loop Closeout

> 每次阶段输出和任务卡更新都必须填写，方便 Owner 判断当前是否真正 Done。
> 澄清阶段也必须填写；`CLARIFICATION_PENDING` 和 `DISCOVERY_REQUIRED` 不是
> DONE，且必须保留唯一恢复动作。

- 当前状态：CLARIFICATION_PENDING / DISCOVERY_REQUIRED / ANALYZE / IMPLEMENT / READY_FOR_SELF_TEST / SELF_TEST_IN_PROGRESS / REVIEW / COMMIT_READY / DONE / BLOCKED
- 下一阶段：
- 是否 Done：是 / 否
- Done 依据：如果是 DONE，列出代码、自测、Review、提交处理已经如何闭环；如果不是 DONE，写 N/A
- 交付结果：NOT_STARTED / IN_PROGRESS / CHANGED_PENDING_SELF_TEST / REVERTED / NO_CHANGE
- 回滚事实：N/A；或写明已回滚的文件、触发原因、回滚后真实 diff 和证据来源
- 唯一下一步：如果不是 DONE，只写一个可执行动作；如果是 DONE，写“无”
- 是否需要 Owner 输入：是 / 否；如果是，说明需要谁回填什么

> `REVERTED` 代表本轮尝试未形成可交付改动：不得声称“完成”“已修复”或
> `READY_FOR_QA`，必须以 `RETURN` / `STOP` 记录恢复阶段和唯一下一步。

## 流程成本记录

> 不统计精确 Token，只记录是否按风险裁剪，避免优化后所有任务都变重。

- 最终交付强度：L1 / L2 / L3
- 实际经过的 Agent：
- 跳过的非必要阶段：
- 读取的缺陷卡数量：0
- 是否复用上游证据：是 / 否
- 是否发生 ESCALATE：否 / L1->L2 / L1->L3 / L2->L3

## 下一步动作

下一步只写一个最小动作，方便跨会话恢复，并必须和 `Loop Closeout` 的“唯一下一步”一致。
必须写成可执行承接动作，包含目标阶段、目标 Agent、最小动作和是否需要人工输入。
如果下一步不需要人工确认、人工验证、环境/设备条件或 Commit / Push 权限，应在当前会话主动继续执行，不等待 Owner 再说“继续”。

示例：

```text
进入 Self Test Agent，读取真实 diff，先执行 L0 diff scope 和 Project Local Knowledge 声明的 L1 analyze / lint；不需要人工输入，当前会话继续。
```

## 阻塞项

- 阻塞项：
- 需要谁决策：
- 最小问题：

## Loop 记录

| iteration | stage | result | evidence |
|---|---|---|---|
| 0 | analyze | pending |  |
