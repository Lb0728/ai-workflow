---
name: grill-me
description: 交互式澄清尚未收敛的需求、方案、PRD 初稿、Fast Brief、Task Card、Bug 现象或中断恢复任务。仅在用户明确调用 $grill-me 时使用；一次只问一个高影响问题，先查直接相关代码和文档，不写代码、不生成 PRD、不创建任务卡、不写长期架构文档。
---

# Grill Me

Use this Skill as the explicit requirement clarification Gate before `$to-prd`, Router, or Bugfix Agent.

Inputs can be raw chat, vague ideas, PRD drafts, Fast Briefs, Task Cards, Bug symptoms, logs, screenshots, code paths, or incomplete handoff recovery. The user should not need to fill a template; extract and organize the fields from available context.

## Workflow

1. Read the repository guidance exposed by the active Host Adapter and respect
   it as the repository rule source.
2. Read the user's current request and any directly referenced PRD, task card, Fast Brief, case, design, log, or code path.
3. Search and read only directly relevant code or documents. Do not scan all agents, all docs, or all history by default.
4. Separate confirmed facts from assumptions. Do not write assumptions as facts.
5. Check whether four items are clear enough for routing: goal, scope, key rules, and acceptance.
6. Ask one highest-impact question at a time only when the answer can change goal, scope, implementation direction, acceptance, safety, compatibility, or rollback.
7. For each question, include why it matters and 2-3 real options only when the options genuinely exist. Include a recommended option when there is enough evidence.
8. Do not ask the user for information that can be confirmed from code, docs, logs, or existing task artifacts.
9. If the user cannot answer and evidence is missing, switch to `DISCOVERY_REQUIRED` instead of infinite questioning.
10. Stop asking when goal, scope, key rules, non-goals, and acceptance direction are clear enough for planning.
11. When stopping, bridge to the next phase instead of ending with a vague suggestion. State whether the output is ready for `$to-prd`, Router, or Bugfix Agent, and whether the current session can continue without more Owner input.

## Ask Before Ask

Before emitting `CLARIFICATION_PENDING`, run a directed Evidence Check against the directly referenced Figma, PRD, Task Card / Fast Brief, code, logs and API definitions:

```text
- What decision is still needed?
- What is already confirmed, and from which source?
- What can AI verify without Owner input?
- Is this a real business choice, or only a missing search / incomplete reading?
```

Do not ask again when Figma already defines the UI / copy / state, PRD already defines the rule, a task artifact already defines the scope, or code / logs can confirm the event, callback or owner. Ask exactly one question only when an unresolved conflict or product choice would change goal, scope, rules, acceptance, safety, compatibility or rollback.

## Clarity Check

The request is not ready for Router, Coding, or a full task card until these are clear enough:

1. Goal: what result the task must achieve, or what user-visible outcome should change.
2. Scope: what is included now, and what is explicitly out of scope.
3. Key rules: data source of truth, device capability, API compatibility, login/session state, state machine, old device/version compatibility, or rollback constraints that must not break.
4. Acceptance: scenarios, expected results, and validation direction.

If any item can significantly change implementation, risk level, task boundary, or acceptance, stay in clarification.

## Information Classes

Use these categories strictly:

```text
已确认事实
- Only from explicit user confirmation, verified code, verified logs, verified API docs, or current task artifacts.

用户描述但尚未验证
- User-reported behavior, suspected cause, or reproduction detail that has not been checked.

假设 / 待验证点
- Possible root cause, implementation direction, or evidence gap. Never present these as confirmed conclusions.
```

Attach source hints whenever practical, such as `来源：用户复现`, `来源：代码已验证`, `来源：日志`, or `来源：任务卡`.

## Output

Choose exactly one of these closeout states.

### CLARIFICATION_PENDING

Use when one answer can materially change goal, scope, key rules, acceptance, safety, compatibility, or rollback.

```md
## CLARIFICATION_PENDING

### 当前唯一阻塞点
[一个最高影响问题]

### 为什么重要
[该答案会如何影响范围、方案、验收或风险]

### 当前已知
- [最多 3 条已确认事实，带来源]

### 需要用户回填
[明确说明用户只需回答什么]

### 回填后自动恢复到
`$grill-me` 重新判断澄清完整度，并自动进入：
- `$to-prd`
- Router
- Bugfix Agent
- 或下一轮单问题澄清

## Loop Closeout

- 当前状态：CLARIFICATION_PENDING
- 是否 Done：否
- 唯一下一步：Owner 只回填“[当前唯一阻塞点]”；收到后由 `$grill-me` 重新判断并进入上方指定阶段。
- 是否需要 Owner 输入：是；不得追加第二个问题或把“继续下一步”留给 Owner 猜测。
```

Do not output "是否继续下一步", a bundle of questions, implementation details,
Coding Prompt, code diff, or a claim that implementation has started in this
state. `CLARIFICATION_PENDING` is a hard boundary: the same response may not
also emit a `Requirement Clarification Result` or any downstream handoff.

### DISCOVERY_REQUIRED

Use when the user cannot define the problem and the missing evidence prevents a decision.

```md
## DISCOVERY_REQUIRED

### 当前无法直接决策的原因
[缺少用户路径、日志、失败样本、数据或现有流程证据]

### 建议补齐的最小证据
- [只列最必要的 1-3 项]

### 可由 AI 先自行完成的检查
- [代码链路]
- [现有日志]
- [任务资料]
- [接口定义]

### 完成后自动恢复到
`$grill-me`

## Loop Closeout

- 当前状态：DISCOVERY_REQUIRED
- 是否 Done：否
- 唯一下一步：先完成“可由 AI 先自行完成的检查”中的第一项；只有该项不能补齐证据时才请求列出的最小证据。
- 是否需要 Owner 输入：否 / 是（仅在 AI 检查无法补齐时）。
```

If evidence can be obtained from the repo, logs, code, or task artifacts, inspect it first instead of asking the user.

### Requirement Clarification Result

Use when goal, scope, key rules, and acceptance are clear enough for routing.

```md
# Requirement Clarification Result

## 1. 原始诉求
- [用户最初希望解决的问题]

## 2. 已确认事实
- [事实]（来源：用户确认 / 代码 / 日志 / 文档 / 任务载体）

## 3. 用户描述但未验证
- [内容]

## 4. 假设与待验证点
- [内容]

## 5. 本次目标
- [一句明确、可验证的目标]

## 6. 本次范围
### 要做
- [范围]

### 不做
- [明确排除项]

## 7. 关键规则 / 不可破坏项
- [数据真源 / 设备能力 / 接口兼容 / 登录态或状态机 / 旧版本或旧设备兼容]

## 8. 验收标准
- [场景 + 预期结果]

## 9. 当前风险
- 风险等级：低 / 中 / 高
- 风险点：
  - [风险]
- 仍需验证：
  - [验证点]

## 10. 自动路由结果
- 下一阶段：`$to-prd` / Router / Bugfix Agent
- 路由原因：[一句说明]
- 是否可在当前会话继续：是 / 否，原因

## Loop Closeout
- 当前状态：ANALYZE
- 是否 Done：否
- 唯一下一步：[进入自动路由结果中的唯一阶段；写明 Agent、最小输入和是否需要 Owner 输入]
- 是否需要 Owner 输入：是 / 否
```

When writing into an existing Fast Brief or Task Card, update only the existing clarification/checkpoint/evidence areas needed to preserve recovery. Do not create a parallel task system.

## Routing

Route after clarification:

```text
Product definition still needs an executable requirement document -> `$to-prd` handoff prompt.
Clear enough to judge delivery level, or already has PRD / Fast Brief / Task Card -> Router.
Bug symptom is clear but root cause is unknown -> Bugfix Agent.
Simple bug has known root cause and minimal fix boundary -> Router or minimal fix input, preserving existing delivery-level rules.
One key answer is still missing -> CLARIFICATION_PENDING.
The user cannot define the problem and evidence is missing -> DISCOVERY_REQUIRED.
```

Respect explicit-only Skill boundaries: do not execute `$to-prd` from inside this Skill unless the current session already has explicit permission to continue into that Skill. It is allowed to hand off with a precise `$to-prd` prompt. Router and Bugfix Agent may be continued by the current session when no hard gate is present.

A clarification handoff is not implementation authorization. Do not turn a
clarification result into code changes until the selected downstream phase has
accepted it and its own Gate is satisfied.

## Boundaries

- Do not modify business code.
- Do not create or update `CONTEXT.md` or ADRs.
- Do not generate a full PRD.
- Do not create Task Card / Fast Brief files unless the user explicitly asks.
- Do not require the user to fill an original requirement template before the conversation can start.
- Do not keep asking low-impact questions for completeness.
- Do not treat scattered chat as an executable requirement until it is summarized and confirmed.
- Do not execute the next phase inside this Skill when doing so would generate a PRD, task card, or code; instead hand off with a precise next-phase prompt.
- Do not turn Bug symptoms into root cause conclusions; Bugfix Agent owns reproduction, minimization, hypotheses, observation, evidence closure, and root-cause judgment.
