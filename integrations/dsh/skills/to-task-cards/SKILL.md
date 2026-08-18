---
name: to-task-cards
description: 将已确认 PRD、技术方案或任务简报拆成可独立执行的 Task Card / Fast Brief / Micro Change 切片。仅在用户明确调用 $to-task-cards 时使用；不写业务代码、不执行任务、不绕过 Router、Self Test 或高风险 ALIGNMENT_PENDING。
---

# To Task Cards

Use this Skill after a PRD, technical plan, or confirmed brief exists and needs to be split into independently executable delivery slices.

## Workflow

1. Read the repository guidance exposed by the active Host Adapter.
2. Read the source PRD / plan / brief / task card explicitly referenced by the user.
3. Read only directly relevant `CONTEXT.md`, ADRs, workflows, templates, or code paths needed to understand boundaries.
4. Split work by vertical user-visible or independently verifiable slices, not by arbitrary file layers.
5. For each slice, identify goal, scope, non-goals, acceptance, dependency, delivery_level, and high-risk triggers.
6. Do not create implementation diffs. Do not execute any task.
7. If a slice is high risk, mark it as requiring `high_risk_delivery` and `ALIGNMENT_PENDING`.
8. If the PRD is not clear enough to slice safely, stop and ask the single highest-impact question.
9. When slicing is complete, bridge to Router or `ai_loop_new.sh` with the first executable slice and state whether the current session can continue without more Owner input.

Use `assets/task-slice-template.md` as the output structure.

## Output

End with:

```text
建议拆分清单
推荐执行顺序
高风险切片
需要补充确认的问题
下一步：Router / ai_loop_new.sh / $grill-me / $grill-with-docs
是否可在当前会话继续：是 / 否，原因
```

## Boundaries

- Do not modify business code.
- Do not create final task files unless the user explicitly asks.
- Do not invent acceptance criteria that the PRD does not support.
- Do not treat a PRD as permission to bypass Router or high-risk alignment.
- Do not split into technical layers when a vertical slice is possible.
