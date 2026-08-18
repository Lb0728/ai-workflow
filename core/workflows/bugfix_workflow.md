# Bugfix Loop

## Discovery 前置关系

如果 Bug 的现象、预期行为、影响范围或“什么算问题”还不清楚，先显式使用 `$grill-me` 收敛；不要直接把现象当根因。

如果 Bug 已定义清楚，只是不知道根因，则按本 Loop 进入 Bugfix Agent。高风险 Bug 仍必须保留 `ALIGNMENT_PENDING`。

Bugfix Agent 内部必须先选择唯一主路径：

```text
NEEDS_CLARIFICATION
FAST_FIX
STANDARD_FIX
DIAGNOSTIC_LOOP
```

根因没有证据时，只能标记为“假设”或“高概率判断”，不得写“根因已确认”。`DIAGNOSTIC_LOOP` 必须先建立反馈闭环，再建议修改代码。

## 使用场景

- 测试反馈 Bug
- 用户反馈问题
- UI 不刷新
- 状态错位
- 设备命令异常
- 跨模块或共享状态联动异常
- 多 transport 行为不一致

## 交付等级原则

```text
本 Loop 不默认跑满所有阶段。
交付等级决定本 Bugfix 应承担的流程成本，不等于业务优先级。
轻量路径不是跳过质量；只是让低风险小 Bug 不承担完整治理成本。
```

分流规则：

```text
micro_change:
- 单句文案、单点样式、明确展示 Bug，不改变业务行为
- 只要求 L0 Diff Gate 和页面验证

light_feature:
- 小 UI / 文案 / 展示字段 / 已知低风险小修
- ANALYZE 后可直接 IMPLEMENT
- VERIFY 仍必须记录 L0/L1/L2；L3 不适用时写 N/A 原因
- 触碰设备或平台能力、当前实体切换、多 transport、运行态、资料态时必须升级

standard_delivery:
- 普通 Bugfix
- 需要 ANALYZE / 最小影响范围 / IMPLEMENT / VERIFY
- REVIEW 按风险启用

high_risk_delivery:
- 平台命令、多 transport、Project Local Knowledge 重点回归面联动、运行态、资料态
- 必须完整治理；进入 IMPLEMENT 前必须先到 ALIGNMENT_PENDING 等待用户确认
- 关键证据缺失且无法形成可执行方案时，先按 Evidence Check 排除日志、代码、接口或任务资料可自查项；仍满足严格 Blocker 条件才 BLOCKED
```

Bugfix 路径规则：

```text
FAST_FIX:
- 现象明确、根因明确或可直接定位、修改局部、回归范围小。
- 不涉及状态流、并发、时序、设备协议、跨端差异。
- 需要针对性验证，但不要求完整假设树或复杂 Harness。

STANDARD_FIX:
- 现象和方向已知，但根因仍需确认或涉及状态刷新、缓存、数据流、错误处理、多个页面或模块。
- 需要复现步骤、已确认事实、根因结论或假设、修复前后验证和防回归建议。

DIAGNOSTIC_LOOP:
- 根因未知、偶现、难复现、线上才出现，或涉及并发、升级、多 transport、时区、跨端、Crash、网络波动、数据一致性、多实体/账号/状态组合。
- 必须先设计反馈闭环，例如失败测试、Mock / 可控 Future、请求回放、日志回放、最小 Harness、Maestro、真机固定复现、跨端日志或线上监控。
- 修复后必须用同一个反馈闭环证明问题消失。
```

以下主题默认不得走 FAST_FIX，除非有明确证据证明只是纯局部 UI / 文案错误：

```text
升级 / 多 transport / 时区 / 实体绑定 / 产品或型号差异 / 数据迁移 /
领域数据聚合或 Baseline / 多端行为差异 / 本地缓存与服务端状态一致性
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
高风险协议 / 设备规则 / 产品口径不明确 -> BLOCKED
```

`BLOCKED` 不是“尚未定位文件”或“需要补验证”的默认结果：可以继续实现的风险分别记录为 Warning / Follow-up，真机或环境缺口记录为 Manual Verification，并在对应阶段处理。

## Bugfix 证据驱动动态路由

第 8 轮起，以上状态机只描述可用阶段，不再代表必须顺序执行。Bugfix 关键阶段必须在现有任务载体中填写统一 `下一步决策`，`ai/tool/ai_loop_next.sh` 校验后决定真实下一阶段。

```text
STAY     -> 保留当前阶段，继续补证据
ADVANCE  -> 进入目标阶段
RETURN   -> 返回目标阶段，并保留推翻原结论的新证据
STOP     -> 停止自动推进，目标固定为 human
COMPLETE -> 仅由 PR Review 进入 loop_closeout
ESCALATE -> 提升 delivery_level 后返回诊断或进入 arch_boundary
```

合法阶段名固定为：

```text
requirement_breakdown
bugfix_diagnosis
arch_boundary
coding
self_test
pr_review
human
loop_closeout
```

脚本会把这些语义阶段映射到现有 Loop 状态，不创建第二套状态系统：

| 决策阶段 | 现有 Loop 状态 / Agent |
|---|---|
| `requirement_breakdown` | `requirement_breakdown` / Requirement |
| `bugfix_diagnosis` | `analyze` / Bugfix |
| `arch_boundary` | `architecture` / Architecture Boundary |
| `coding` | `implement` / Coding |
| `self_test` | `self_test_in_progress` / Self Test |
| `pr_review` | `review` / PR Review |
| `human` | `blocked` / 人工解除阻塞 |
| `loop_closeout` | `done` / Loop Closeout |

### 决策 Gate

所有 Bugfix 决策必须有当前阶段、当前结论、事实证据、缺少证据、动作、目标阶段和决策原因。`legacy: true` 或尚无 `下一步决策` 章节的旧任务卡继续使用旧状态路由，迁移后再启用强校验。

`ADVANCE -> coding` 额外要求 `Bugfix 诊断证据` 已填写：实际现象、触发条件、预期行为、根因结论、根因证据、最小修改范围和验证计划。推测性措辞可以记录为假设，但不能代替这些事实证据。

`ADVANCE -> pr_review` 额外要求 `Bugfix 自测证据` 已填写：测试结果、原问题场景验证、回归检查范围和未验证项，并且 Self Test 分类为 `NONE`。

`STOP -> human` 额外要求：阻塞原因、已完成内容、缺少信息或资源、人工下一步、恢复后返回阶段。缺任一项都留在当前阶段修正决策块。

`ESCALATE` 额外要求：升级前 / 后 `delivery_level`、触发风险信号和事实证据；任务卡 frontmatter 必须已经更新到升级后的等级。只允许 L1 -> L2/L3 或 L2 -> L3，不允许自动降级。

Self Test 失败分类固定为：

| 分类 | 动作 | 目标阶段 |
|---|---|---|
| `IMPLEMENTATION_ERROR` | `RETURN` | `coding` |
| `ROOT_CAUSE_ERROR` | `RETURN` | `bugfix_diagnosis` |
| `REQUIREMENT_ERROR` | `RETURN` | `requirement_breakdown` |
| `ENVIRONMENT_BLOCKED` | `STOP` | `human` |
| `NONE` | `ADVANCE` | `pr_review` |

## 风险、自测与成本裁剪

```text
L1 = micro_change / light_feature
   Router -> Coding -> Targeted Self Test -> Diff Review Lite -> Complete

L2 = standard_delivery
   Bugfix Diagnosis -> Coding -> Self Test -> PR Review -> Closeout

L3 = high_risk_delivery
   Requirement / Diagnosis -> 定向 Defect Memory -> Change Impact
   -> Architecture -> Coding -> Regression Self Test -> PR Review -> Closeout
```

L1 验证修改目标和一个主要相邻场景；L2 验证原问题、主要相邻场景和静态检查；L3 额外验证命中的历史缺陷、接口异常、状态恢复和必要回归。L3 的 Historical Regression Gate 在命中历史缺陷时必须 PASS；无命中时可 N/A，但必须有定向检索证据。

上下文也按等级裁剪：L1 只读任务摘要和目标文件；L2 读取目标链路和必要架构片段；L3 只额外读取最多 5 张命中缺陷卡。任何等级都不得每阶段重复扫描完整仓库或加载全部历史资料。

线上逃逸或重复缺陷在 Review 通过、根因和回归场景均有真实证据后，由现有 PR Review / Closeout 过程使用 `defect_memory/template.md` 写入一张最小缺陷卡；不新增 Memory Agent。尚未确认根因、普通本地缺陷或只有推测时不得写入。

### 改造前后流程图

改造前：

```text
Diagnosis -> Coding -> Self Test -> Review
                         |
                         +-- 失败通常固定回 Coding / Blocked
```

改造后：

```text
Requirement <-------------------------+
     |                                |
     v                                |
Diagnosis --边界问题--> Architecture  |
  |  ^                    |     |      |
  |  +--根因被推翻--------+-----+      |
  |                                     |
  +--证据充分--> Coding <---实现错误---+|
                    |                  ||
                    v                  ||
                Self Test ------------+|
                    | 根因错误 ----------+
                    | 需求错误 -----------> Requirement
                    | 环境阻塞 -----------> Human / STOP
                    v
                 PR Review --普通问题--> Coding
                    |       --方向问题--> Diagnosis
                    |       --需求问题--> Requirement
                    v
               Loop Closeout / COMPLETE
```

## Stage 与 Agent 绑定

| Loop Stage | 主 Agent | 何时使用 | 产出 |
|---|---|---|---|
| ANALYZE | `core.agent.bugfix` | 默认必用 | 真实链路、根因候选、最小修复点、回归范围 |
| IMPACT_MAP | `core.agent.bugfix` | 中等及以上 Bug 默认必用，小 Bug 可轻量 | 入口、调用链、影响范围、回归范围、最少测试 |
| ARCHITECTURE CHECK | `core.agent.architecture_boundary` | 触碰运行态、设备或平台能力、跨模块或架构边界时 | blocking / non-blocking 结论 |
| ALIGNMENT_PENDING | `core.agent.architecture_boundary` | high_risk_delivery 进入 IMPLEMENT 前 | 高风险对齐包，等待用户明确确认 |
| IMPLEMENT | `core.agent.coding` | ANALYZE 结论被确认后 | 最小代码改动和原因 |
| READY_FOR_SELF_TEST | `core.agent.coding` | IMPLEMENT 完成后 | Implement Summary，等待真实自测 |
| SELF_TEST_IN_PROGRESS | `core.agent.self_test` | READY_FOR_SELF_TEST 后 | 读取真实 diff，执行自动检查，收集人工验证回填，输出提测结论 |
| REVIEW | `core.agent.pr_review` | SELF_TEST_IN_PROGRESS 通过后 | blocking issue 检查 |
| i18n / UI CHECK | `core.agent.i18n_text_ui_risk` | 改用户可见文案、本地化资源、UI 或第三方 UI 时 | 文案 / UI 风险结论 |
| READY_FOR_QA | `core.agent.self_test` | REVIEW 通过后 | READY_FOR_QA / READY_FOR_QA_WITH_RISK / NOT_READY_FOR_QA |
| COMMIT_READY | `core.agent.commit` | Coding / Self Test / PR Review 均完成后，需要生成提交信息时 | 可复制 Commit 信息，等待人工提交 |

`SELF_TEST_IN_PROGRESS` 就是真实自测阶段；`verify` 仅作为脚本兼容别名。Commit Agent 不执行 `git add` / `git commit` / `git push`，只在 `COMMIT_READY` 生成提交信息，等待人工手动提交。

## 运行方式

### 1. 创建任务载体

推荐使用脚本：

```bash
<task-creator> bugfix <TASK-ID> short-slug P1 standard_delivery
```

轻量修复：

```bash
<task-creator> bugfix <TASK-ID> short-slug P2 light_feature
```

也可以手工复制 Loader 解析出的 Task Card Template。现有任务的恢复方式
由 Compatibility Loader 提供，不改变其基线行为。

如果使用旧格式任务卡，至少补齐：

- Goal
- Bug Report Snapshot，或用文字写清已知现象
- Scope，根因未知时可以只写“先分析，不改代码”
- Acceptance Criteria，可在 ANALYZE 后再由 当前 AI Host 基于真实链路补齐
- Evidence
- Current Checkpoint
- Next Action

注意：

- 最小信息不是完整结论。
- 对偶现问题 / corner case，不要求一开始写出稳定复现路径、准确根因或最终修改点。
- 提单阶段只填写确定事实；不确定的信息留空，不写假设。
- `未知项`、`根因候选`、`下一步验证动作` 只能由 当前 AI Host 在 ANALYZE 阶段基于源码、日志或测试证据回填。

### 2. 在 当前 AI Host 中启动

```text
按 Core Bugfix Workflow 和当前 Runtime Task 跑 Bugfix Loop。
先进入 ANALYZE 阶段，只分析真实链路和根因，不改代码。
```

也可以用脚本生成下一阶段 prompt：

```bash
<loop-runner> <runtime-task>
<loop-runner> <runtime-task> verify
```

### 3. 每阶段更新任务卡

- 更新 `status`
- 更新 `iteration`
- 记录真实文件、命令、输出摘要或人工验证证据
- 更新 `Current Checkpoint`
- 更新 `Next Action`

## 阶段定义

### ANALYZE

目标：

- 复述 Bug 现象和复现条件
- 输出唯一 Bugfix 路径：NEEDS_CLARIFICATION / FAST_FIX / STANDARD_FIX / DIAGNOSTIC_LOOP
- 对偶现问题，只使用 task card 中已有确定事实作为输入
- 梳理真实调用链
- 找到最小根因候选，或标记缺失证据和反馈闭环
- 明确不做范围和回归范围

可用 Agent：

- `core.agent.router`：不确定任务类型或影响范围时使用
- `core.agent.bugfix`：根因分析主入口
- `core.agent.architecture_boundary`：高风险链路才启用

完成条件：

- task card 保留提单阶段的确定事实，不把猜测写成事实
- task card 写入 Impact Map，或写清当前无法确认链路的阻塞点
- task card 写入基于证据的根因、待验证根因，或 DIAGNOSTIC_LOOP 的反馈闭环设计
- 明确当前允许分析 / 修改的最小范围；根因未确认时不强行进入 IMPLEMENT

### IMPACT_MAP

目标：

- 输出入口文件 / 类 / 方法
- 输出真实调用链、关键状态或数据流
- 明确允许改动范围和不做范围
- 明确直接影响模块、回归范围和本次最少必须测试

完成条件：

- `Impact Map` 足以约束 Coding Agent 不扩大范围
- `Minimal Implementation Plan` 明确改什么、为什么改、不改什么、验证什么

### IMPLEMENT

目标：

- 只按 ANALYZE 的最小修复点改动
- 不顺手重构
- 不修改无关文件

可用 Agent：

- `core.agent.coding`

完成条件：

- 代码改动完成
- task card 记录改动文件和原因

### SELF_TEST_IN_PROGRESS

目标：

- 证明修复有效
- 证明未引入关键回归

可用 Agent：

- `core.agent.self_test`

最低要求：

- L0 Diff Gate：确认 diff 只包含本任务相关文件
- L1 Basic Run Gate：静态检查、构建或相关自动化测试
- L2 Feature Verification Gate：验证本 Bug 的用户可见修复点
- L3 Direct Regression Gate：验证同入口、共享状态、同数据链路上的旧功能
- High Risk Gate：涉及多 transport / 平台命令 / 当前实体切换 / 升级时必须记录真实环境验证或未覆盖风险

完成条件：

- task card 的 `QA Gate Results` 有 PASS / FAIL / NOT_RUN / N/A / BLOCKED 结论
- `NOT_RUN` 不等于通过；`N/A` 和 `BLOCKED` 必须写清原因、影响和剩余风险
- 不允许只写“看起来没问题”

### REVIEW

目标：

- 检查修复是否扩大范围或引入回归
- blocking issue 必须回到 IMPLEMENT

可用 Agent：

- `core.agent.pr_review`
- `core.agent.i18n_text_ui_risk`，仅 UI / 文案 / 本地化资源 / 第三方 UI 受影响时启用

完成条件：

- 无 blocking issue
- i18n / UI Gate 已执行或明确无需执行

### DONE

目标：

- 给出最终交付说明
- 如需要提交信息，进入 COMMIT_READY，由 Commit Agent 生成可复制 Commit 信息，等待人工提交

可用 Agent：

- `core.agent.commit`

完成条件：

- task card 状态更新为 `done`
- 输出 changed files / reason / validation / remaining risks

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

## 阻断规则

以下情况不能进入 Commit Agent：

- Self Test 没有真实结论
- PR Review 存在 blocking issue
- QA Gate 缺少 L0/L1/L2 真实结论
- change type 缺少 Company Policy 要求的 task reference
- 代码改动和生成的 Commit 信息不一致
- task card 没有记录当前 checkpoint 和验证证据
