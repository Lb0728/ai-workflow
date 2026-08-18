---
name: grill-with-docs
description: 交互式澄清会形成长期术语、跨模块规则或架构决策的需求讨论。仅在用户明确调用 $grill-with-docs 时使用；可维护 CONTEXT.md 和 docs/adr，但不写业务代码、不生成 PRD、不绕过高风险 ALIGNMENT_PENDING。
---

# Grill With Docs

Use this Skill when requirement discovery may create durable domain language, cross-module rules, or hard-to-reverse architecture decisions.

## Workflow

1. Read the repository guidance exposed by the active Host Adapter.
2. Read the current request and directly relevant code, docs, task cards, PRDs, cases, or designs.
3. If present, read `CONTEXT.md`.
4. Read only ADRs directly related to the current topic. Do not scan every ADR by default.
5. Clarify like `$grill-me`: one highest-impact question at a time, no guessing, no low-impact interrogation.
6. Use existing terms when possible. Add a new term only when its definition is stable and likely to be reused.
7. Create or update an ADR only when the decision is hard to reverse, future readers would not understand the reason from code alone, and real alternatives were considered.
8. After any document write, briefly state the path and what changed. Do not paste full documents into the chat.

## Durable Documents

- `CONTEXT.md`: shared terminology only. No task history, implementation detail, or unconfirmed proposal.
- `docs/adr/`: durable architecture decisions with real tradeoffs.

Read `references/CONTEXT-FORMAT.md` before editing `CONTEXT.md`.
Read `references/ADR-FORMAT.md` before creating or editing ADRs.

## Output

End with exactly one status-driven closeout. The closeout must be mutually
exclusive: do not recommend `$to-prd` unless the status is `READY_FOR_PRD`, and
do not include more than one `下一步` line in the same response.

### Status Selection

Use `NEEDS_CLARIFICATION` when there are still important unresolved questions
about impact, behavior, boundaries, architecture, product rules, protocol
rules, or validation direction.

Use `READY_FOR_PRD` only when the goal, scope, key behavior, main boundaries,
acceptance direction, and blocking risks are confirmed enough to create an
executable PRD.

Use `DEFERRED` when the discussion decides not to implement now, or progress
depends on external information, product confirmation, firmware confirmation,
backend contract changes, or another outside decision.

### Required Closeout Shapes

For `NEEDS_CLARIFICATION`, end with:

```text
当前状态：NEEDS_CLARIFICATION
已确认事实
已做决策
本次新增 / 更新的术语
本次新增 / 更新的 ADR
本次范围与非目标
当前最高影响未决项
下一步：继续 $grill-with-docs
```

For `READY_FOR_PRD`, end with:

```text
当前状态：READY_FOR_PRD
已确认事实
已做决策
本次新增 / 更新的术语
本次新增 / 更新的 ADR
本次范围与非目标
已收敛摘要
下一步：$to-prd
```

For `DEFERRED`, end with:

```text
当前状态：DEFERRED
已确认事实
已做决策
本次新增 / 更新的术语
本次新增 / 更新的 ADR
本次范围与非目标
当前决策
重新进入流程的条件
下一步：等待重新进入条件满足
```

### Output Guards

- Same response, exactly one status.
- Same response, exactly one `下一步`.
- Never output both "建议进入 `$to-prd`" and "暂不建议进入 `$to-prd`".
- Only `READY_FOR_PRD` may display or recommend `$to-prd`.
- `NEEDS_CLARIFICATION` must continue `$grill-with-docs`.
- `DEFERRED` must not display or recommend `$to-prd`.

### Examples

`NEEDS_CLARIFICATION`:

```text
当前状态：NEEDS_CLARIFICATION
已确认事实
- 当前旧流程使用本地发现完成绑定。
已做决策
- 暂无。
本次新增 / 更新的术语
- 无。
本次新增 / 更新的 ADR
- 无。
本次范围与非目标
- 不写业务代码。
当前最高影响未决项
- Device Capability 的真源是后端下发还是 App 本地 registry。
下一步：继续 $grill-with-docs
```

`READY_FOR_PRD`:

```text
当前状态：READY_FOR_PRD
已确认事实
- 目标、范围、关键行为和边界已确认。
已做决策
- 设备差异由 capability + strategy 表达。
本次新增 / 更新的术语
- Device Capability。
本次新增 / 更新的 ADR
- 无。
本次范围与非目标
- 不创建未来型号实现。
已收敛摘要
- 可以整理为 PRD，交给 Router 判定交付等级。
下一步：$to-prd
```

`DEFERRED`:

```text
当前状态：DEFERRED
已确认事实
- 目标依赖固件协议确认。
已做决策
- 本轮暂不实现。
本次新增 / 更新的术语
- 无。
本次新增 / 更新的 ADR
- 无。
本次范围与非目标
- 不进入 PRD，不进入实现。
当前决策
- 等待固件提供协议字段定义。
重新进入流程的条件
- 固件确认 capability 字段和兼容规则。
下一步：等待重新进入条件满足
```

## Boundaries

- Do not create a PRD automatically.
- Do not implement code.
- Do not create an ADR for every discussion.
- Do not put temporary requirement details into `CONTEXT.md`.
- Do not use device generation, upgrade, transport, or similar keywords as
  automatic reasons to write long-term docs.
- High-risk work still must enter the existing `ALIGNMENT_PENDING` gate before implementation.
