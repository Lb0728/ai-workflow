# Feature Delivery Loop

## Discovery 前置关系

如果 Feature 只有散乱聊天、目标 / 范围 / 验收尚不清楚，先显式使用 `$grill-me` 或 `$grill-with-docs` 收敛；不要直接进入 Coding。

如果已有 PRD、Fast Brief 或 Task Card，则按本 Loop 进入 Router / Requirement 分流。PRD 不能替代 delivery_level 判定，也不能绕过 high_risk_delivery 的 `ALIGNMENT_PENDING`。

## 使用场景

- 产品 PRD
- 新需求
- 新接口接入
- 新页面或用户可见功能变化
- 普通功能改造

## 交付等级原则

```text
Feature Delivery Loop 不默认把所有需求都送进完整治理。
交付等级决定本需求应承担的研发流程成本，不等于业务优先级。
轻量路径不是更快跳过流程，而是让小任务只承担它应有的流程成本。
```

分流规则：

```text
micro_change:
- 单句文案、单点样式、明确展示 Bug，不改变业务行为
- 使用极简记录，只要求 L0 Diff Gate 和页面验证

light_feature:
- 小 UI / 文案 / 简单字段透传 / 已知低风险小改
- 已确认事实足够时，ANALYZE 后可直接 IMPLEMENT
- VERIFY 仍必须记录 L0/L1/L2；专项 Gate 不适用时写 N/A 原因
- 触碰接口契约、运行态、资料态、设备、跨模块时必须升级

standard_delivery:
- 普通产品需求或普通功能改造
- 需要 ANALYZE / IMPACT_MAP / IMPLEMENT / VERIFY
- Architecture / i18n / Device / Review Gate 按影响范围启用

standard_delivery（中等风险）:
- 中等风险需求
- 需要更明确的 Impact Map、Minimal Implementation Plan 和 Review 证据

high_risk_delivery:
- 核心链路、设备或平台能力、多 transport、升级、登录态、数据迁移、多语言结构
- 必须完整治理；进入 IMPLEMENT 前必须先到 ALIGNMENT_PENDING 等待用户确认
- 关键口径或证据缺失且无法形成可执行方案时，先按 Evidence Check 排除仓库可自查项、安全降级和后续 Gate；仍满足严格 Blocker 条件才 BLOCKED
```

## Loop 状态机

```text
ANALYZE
-> IMPACT_MAP
-> ARCHITECTURE CHECK，如需要
-> ALIGNMENT_PENDING，如 high_risk_delivery
-> IMPLEMENT
-> READY_FOR_SELF_TEST
-> SELF_TEST_IN_PROGRESS
-> REVIEW
-> READY_FOR_QA / BLOCKED
-> DONE
```

回退规则：

```text
SELF_TEST_IN_PROGRESS 失败 -> IMPLEMENT
REVIEW blocking issue -> IMPLEMENT
iteration > max_iterations -> BLOCKED
产品口径 / 协议 / 数据契约不明确且影响实现 -> BLOCKED
```

所有 `BLOCKED` 只在缺失输入会导致明显错误或高风险、无法自行补齐、无安全降级且不能延后时使用；Warning、Follow-up 和 Manual Verification 不是同义状态。

## Stage 与 Agent 绑定

| Loop Stage | 主 Agent | 何时使用 | 产出 |
|---|---|---|---|
| ANALYZE | `core.agent.requirement_breakdown` | 默认必用 | 需求边界、影响链、Scope、Non-goals、验收口径 |
| ROUTER | `core.agent.router` | 任务类型或影响范围不明确时 | 任务类型、风险级别、推荐 workflow |
| IMPACT_MAP | `core.agent.requirement_breakdown` | 普通需求默认必用 | 入口、调用链、影响范围、回归范围、最少测试 |
| ARCHITECTURE CHECK | `core.agent.architecture_boundary` | 跨模块、设备或平台能力、运行态、接口契约或数据真源受影响时 | blocking / non-blocking 结论 |
| ALIGNMENT_PENDING | `core.agent.architecture_boundary` | high_risk_delivery 进入 IMPLEMENT 前 | 高风险对齐包，等待用户明确确认 |
| IMPLEMENT | `core.agent.coding` | ANALYZE / ARCHITECTURE CHECK 通过后 | 最小代码改动和原因 |
| READY_FOR_SELF_TEST | `core.agent.coding` | IMPLEMENT 完成后 | Implement Summary，等待真实自测 |
| SELF_TEST_IN_PROGRESS | `core.agent.self_test` | READY_FOR_SELF_TEST 后 | 读取真实 diff，执行自动检查，收集人工验证回填，输出提测结论 |
| REVIEW | `core.agent.pr_review` | SELF_TEST_IN_PROGRESS 通过后 | blocking issue 检查 |
| i18n / UI CHECK | `core.agent.i18n_text_ui_risk` | 用户可见文案、本地化资源、UI 或第三方 UI 受影响时 | 文案 / UI 风险结论 |
| READY_FOR_QA | `core.agent.self_test` | REVIEW 通过后 | READY_FOR_QA / READY_FOR_QA_WITH_RISK / NOT_READY_FOR_QA |
| COMMIT_READY | `core.agent.commit` | Coding / Self Test / PR Review 均完成后，需要生成提交信息时 | 可复制 Commit 信息，等待人工提交 |

`SELF_TEST_IN_PROGRESS` 就是真实自测阶段；`verify` 仅作为脚本兼容别名。Commit Agent 不执行 `git add` / `git commit` / `git push`，只在 `COMMIT_READY` 生成提交信息，等待人工手动提交。

## 运行方式

### 1. 创建任务载体

推荐使用脚本：

```bash
<task-creator> feature <TASK-ID> short-slug P1 standard_delivery
```

轻量任务：

```bash
<task-creator> feature <TASK-ID> short-slug P2 light_feature
```

也可以手工复制 Loader 解析出的 Task Card Template。现有任务的恢复方式
由 Compatibility Loader 提供，不改变其基线行为。

### 2. 在 当前 AI Host 中启动

```text
按 Core Feature Workflow 和当前 Runtime Task 跑 Feature Delivery Loop。
先进入 ANALYZE 阶段，补齐影响链、Scope、Non-goals 和 Required Gates，不改代码。
```

也可以用脚本生成下一阶段 prompt：

```bash
<loop-runner> <runtime-task>
<loop-runner> <runtime-task> architecture
```

## 阶段定义

### ANALYZE

目标：

- 先读取任务卡的 `已确认事实`，只把其中明确写出的内容当作需求事实
- PRD / task reference / 设计稿链接不是必填；如果 `已确认事实` 已写清用户可见行为、页面/模块和明确口径，可以继续分析
- 梳理 page -> controller -> flow/service -> repository/api/platform -> store/runtime 的真实链路
- 基于已确认事实和源码回填 Scope / Non-goals / Acceptance Criteria
- 判断是否需要 Architecture、i18n/UI、Device、Self Test、PR Review Gate

可用 Agent：

- `core.agent.router`
- `core.agent.requirement_breakdown`

完成条件：

- task card 写入真实影响链
- task card 写入最小方案和不做范围
- task card 写入 Required Gates
- 不把标题、slug、当前打开文件、聊天猜测或关键词搜索结果当作需求事实

阻断条件：

- `已确认事实` 没写清用户要看到什么或系统要改变什么
- 目标页面 / 模块完全无法从任务卡、附件或源码入口确认
- 产品规则冲突或关键业务口径缺失，且缺失会影响实现方向

不能阻断的情况：

- Scope 为空
- Non-goals 为空
- Acceptance Criteria 还是模板
- 没有单独 PRD/task reference/设计稿链接，但 `已确认事实` 已写清需求内容

### IMPACT_MAP

目标：

- 明确需求入口、真实调用链、状态 / 数据流
- 明确允许改动范围、直接影响模块、必须回归的旧流程
- 明确本次最少必须测试什么

完成条件：

- `Impact Map` 已能支撑最小实现计划
- `Minimal Implementation Plan` 明确改什么、为什么改、不改什么和验证什么

### ARCHITECTURE CHECK

仅在以下任一条件满足时启用：

- 跨模块
- 影响资料态 / 运行态真源
- 影响 Project Local Knowledge 标记的旧兼容、运行态或当前实体协调 owner
- 涉及多 transport、升级、语音、同步或宿主领域上下文
- 涉及持久化、数据迁移、接口契约变化
- 涉及新设备族、capability 或 strategy

可用 Agent：

- `core.agent.architecture_boundary`

完成条件：

- blocking / non-blocking 结论明确
- blocking issue 解决前不得进入 IMPLEMENT

### IMPLEMENT

目标：

- 按分析阶段确定的最小方案实现
- 不新增平行状态体系、平行主题体系、平行命令发送体系
- 不把复杂业务编排堆回 Controller

可用 Agent：

- `core.agent.coding`

完成条件：

- 代码改动完成
- task card 记录 changed files 和原因

### SELF_TEST_IN_PROGRESS

目标：

- 证明功能可用
- 证明关键回归未破坏

可用 Agent：

- `core.agent.self_test`

最低要求：

- L0 Diff Gate：确认 diff 只包含本任务相关文件
- L1 Basic Run Gate：静态检查、构建或相关自动化测试
- L2 Feature Verification Gate：验证本需求最关键的验收行为
- L3 Direct Regression Gate：验证同入口、共享状态、同数据链路上的旧功能
- High Risk Gate：涉及设备或平台能力、多 transport、登录态、数据迁移、多语言结构等专项时必须执行或记录未覆盖风险

完成条件：

- task card 的 `QA Gate Results` 有 PASS / FAIL / NOT_RUN / N/A / BLOCKED 结论
- `NOT_RUN` 不等于通过；`N/A` 和 `BLOCKED` 必须写清原因、影响和剩余风险
- 未执行的验证必须写原因

### REVIEW

目标：

- 检查功能正确性、架构边界、状态真源、回归、自测证据

可用 Agent：

- `core.agent.pr_review`
- `core.agent.i18n_text_ui_risk`，仅涉及文案 / 本地化资源 / UI / 第三方 UI 时启用

完成条件：

- PR Review 无 blocking issue
- i18n/UI Gate 已执行或明确无需执行

### DONE

目标：

- 输出最终交付说明
- 如需要提交信息，进入 COMMIT_READY，由 Commit Agent 生成可复制 Commit 信息，等待人工提交

可用 Agent：

- `core.agent.commit`

完成条件：

- task card 状态更新为 `done`
- 如需提测，输出测试重点和未覆盖风险

### READY_FOR_QA

目标：

- 基于 L0/L1/L2/L3/High Risk Gate 和 Review Evidence 输出提测结论

只允许三种结论：

- `READY_FOR_QA`
- `READY_FOR_QA_WITH_RISK`
- `NOT_READY_FOR_QA`

完成条件：

- `QA Conclusion` 写明改动摘要、影响范围、已执行检查、未测项、已知风险、建议测试重点
- 禁止用“理论可用”“暂未发现问题”代替真实证据

## 门禁

- 没有分析结论和最小方案，不进入 IMPLEMENT。
- Architecture Check 有 blocking issue，不进入 IMPLEMENT。
- SELF_TEST_IN_PROGRESS 没有 L0/L1/L2 真实证据，不进入 REVIEW。
- REVIEW 有 blocking issue，不进入 DONE / Commit。
- 未形成 QA Conclusion，不进入 DONE / Commit。
- 涉及用户可见文案但未做 i18n/UI 检查，不进入 Commit。
