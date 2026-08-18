# Tech Debt Loop

## Discovery 前置关系

如果技术债讨论会形成长期术语、跨模块规则或难以反转的架构决定，先显式使用 `$grill-with-docs` 收敛并维护 `CONTEXT.md` / ADR。

如果已有 PRD、Task Card 或明确 cleanup 范围，则按本 Loop 分流。Discovery Skill 不替代 Architecture Gate、Self Test Gate 或 Review。

## 使用场景

- 开发自提技术债
- 架构收口
- 旧 manager 拆分
- runtime / platform 网关化
- 文档沉淀
- cleanup

## 交付等级原则

```text
技术债任务也需要分级。
交付等级决定本技术债应承担的流程成本，不等于业务优先级。
轻量技术债不是跳过质量，而是不把文档、命名、局部 cleanup 强行送进完整架构治理。
```

分流规则：

```text
micro_change:
- 纯文档单点修改、注释、无行为变化的命名修正
- 只要求 L0 Diff Gate

light_feature:
- 纯文档、命名、局部无行为变化 cleanup
- 可跳过 ARCHITECTURE CHECK 和正式 REVIEW
- 仍必须做 L0 Diff Gate；如有代码改动，至少记录 L1 结果或 NOT_RUN 原因

standard_delivery:
- 普通技术债
- 需要 ANALYZE / IMPACT_MAP / IMPLEMENT / VERIFY
- ARCHITECTURE CHECK 和 REVIEW 按影响范围启用

standard_delivery / high_risk_delivery:
- 影响真实业务链路、状态真源、旧 manager、runtime/platform、启动/登录/设备链路
- high_risk_delivery 进入 IMPLEMENT 前必须先到 ALIGNMENT_PENDING 等待用户确认
- 必须完整治理；蓝图或当前状态不清时先查真实代码和当前任务资料，只有无法形成安全方案且满足严格 Blocker 条件时 BLOCKED
```

## Loop 状态机

```text
ANALYZE
-> IMPACT_MAP
-> ARCHITECTURE CHECK
-> ALIGNMENT_PENDING，如 high_risk_delivery
-> IMPLEMENT
-> READY_FOR_SELF_TEST
-> SELF_TEST_IN_PROGRESS
-> REVIEW
-> READY_FOR_QA / BLOCKED
-> DONE
```

轻量技术债可以跳过 `ARCHITECTURE CHECK` 和正式 `REVIEW`，但必须在任务载体写清交付等级原因和跳过原因。

任何状态 / Gate 使用 `BLOCKED` 前，必须区分 Warning、Follow-up 和 Manual Verification；后者可限制最终 QA 结论，但默认不阻塞文档或代码实施。

## Stage 与 Agent 绑定

| Loop Stage | 主 Agent | 何时使用 | 产出 |
|---|---|---|---|
| ANALYZE | `core.agent.architecture_boundary` | 默认必用；先确认是否影响真实业务链路和蓝图 | 技术债边界、旧依赖、新接线点、风险 |
| ROUTER | `core.agent.router` | 不确定是 techdebt、bugfix 还是 feature 时 | 任务类型、风险级别、推荐 workflow |
| IMPACT_MAP | `core.agent.architecture_boundary` | 默认必用，纯文档可轻量 | 影响链、旧依赖、新接线点、回归范围 |
| ARCHITECTURE CHECK | `core.agent.architecture_boundary` | 默认必用，轻量任务跳过要写原因 | 分层、真源、旧依赖、blocking 结论 |
| ALIGNMENT_PENDING | `core.agent.architecture_boundary` | high_risk_delivery 进入 IMPLEMENT 前 | 高风险对齐包，等待用户明确确认 |
| IMPLEMENT | `core.agent.coding` | ANALYZE / ARCHITECTURE CHECK 通过后 | 一个可验证闭环的最小改动 |
| READY_FOR_SELF_TEST | `core.agent.coding` | IMPLEMENT 完成后 | Implement Summary，等待真实自测 |
| SELF_TEST_IN_PROGRESS | `core.agent.self_test` | READY_FOR_SELF_TEST 后 | 读取真实 diff，执行自动检查，收集人工验证回填，输出提测结论 |
| REVIEW | `core.agent.pr_review` | SELF_TEST_IN_PROGRESS 通过后，轻量任务跳过要写原因 | blocking issue 检查、旧依赖是否减少 |
| READY_FOR_QA | `core.agent.self_test` | REVIEW 通过后 | READY_FOR_QA / READY_FOR_QA_WITH_RISK / NOT_READY_FOR_QA |
| COMMIT_READY | `core.agent.commit` | Coding / Self Test / PR Review 均完成后，需要生成提交信息时 | 可复制 Commit 信息，等待人工提交 |

`SELF_TEST_IN_PROGRESS` 就是真实自测阶段；`verify` 仅作为脚本兼容别名。Commit Agent 不执行 `git add` / `git commit` / `git push`，只在 `COMMIT_READY` 生成提交信息，等待人工手动提交。

## 运行方式

```bash
<task-creator> techdebt <TASK-ID> cleanup P2 standard_delivery
```

轻量文档或 cleanup：

```bash
<task-creator> techdebt <TASK-ID> cleanup P2 light_feature
```

也可以手工复制 Loader 解析出的 Task Card Template。现有任务的恢复方式
由 Compatibility Loader 提供，不改变其基线行为。

当前 AI Host 启动语句：

```text
按 Core Tech Debt Workflow 和当前 Runtime Task 跑 Tech Debt Loop。
先进入 ANALYZE 阶段，确认是否影响真实业务链路和架构蓝图，不改代码。
```

也可以用脚本生成下一阶段 prompt：

```bash
<loop-runner> <runtime-task>
<loop-runner> <runtime-task> review
```

## 判断规则

### 必须按主链路处理

- 影响用户行为
- 影响 Project Local Knowledge 重点回归面
- 影响多 transport
- 影响宿主领域 / 升级 / 语音 / 同步
- 影响当前设备切换
- 影响资料态 / 运行态真源
- 影响启动、登录态、profile restore
- 改动会让旧 manager、旧 controller、旧 tools 职责继续扩大

### 可以轻量处理

- 纯文档
- 纯注释
- 不改变运行行为的小整理
- analyzer 明确标记的局部确定性清理

## 阶段要求

### ANALYZE

- 对齐 Project Local Knowledge 解析出的目标架构、当前状态与进度资料
- 明确这次技术债要移除哪条旧依赖、建立哪条新依赖
- 明确本轮不做范围

### IMPACT_MAP

- 明确本次技术债影响哪条真实业务链路
- 明确旧依赖减少点和新接线点
- 明确允许改动范围、直接影响模块、必须回归的旧流程
- 明确本次最少必须测试什么

### ARCHITECTURE CHECK

- 检查是否符合 `app / features / platform / shared` 目标分层
- 检查是否新增平行体系
- 检查是否把复杂编排继续堆进 Controller
- 检查是否把资料态和运行态混写

### IMPLEMENT

- 只做一个可验证闭环
- 不做“顺手大整理”
- 不创建只有目录没有真实接线的空骨架

### SELF_TEST_IN_PROGRESS

- L0 Diff Gate：确认 diff 只包含本任务相关文件
- L1 Basic Run Gate：静态检查、构建或相关自动化测试
- L2 Feature Verification Gate：验证被技术债影响的核心业务闭环
- L3 Direct Regression Gate：验证同入口、共享状态、同数据链路上的旧功能
- High Risk Gate：涉及设备、登录态、数据迁移等专项时必须执行或记录未覆盖风险
- 如果无法验证闭环，应设置为 `blocked`，不要标记 done

### REVIEW

- 检查旧依赖是否真的减少
- 检查新入口是否接到真实调用链
- 检查是否需要更新 Project Local Knowledge 声明的架构进度资料

## DONE 条件

- task card 写明旧依赖减少点和新接线点
- task card 写明验证证据
- task card 写明 QA Conclusion：READY_FOR_QA / READY_FOR_QA_WITH_RISK / NOT_READY_FOR_QA
- 如果影响蓝图进度，已同步或明确建议同步 docs
