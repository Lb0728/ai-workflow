---
name: to-prd
description: 将当前会话、已确认结论、相关代码和长期文档整理成可执行 PRD。仅在用户明确调用 $to-prd 时使用；不重新无限追问、不写代码、不直接进入 IMPLEMENT，高风险主题仍交给 Router 和 ALIGNMENT_PENDING。
---

# To PRD

Use this Skill after discovery has enough confirmed decisions to create an executable PRD.

## Workflow

1. Read the repository guidance exposed by the active Host Adapter.
2. Prefer confirmed conclusions in the current session.
3. Read directly relevant `CONTEXT.md`, ADRs, code, design material, existing PRDs, Fast Briefs, or task cards.
4. Do not restart discovery. Ask only the smallest blocking question when missing information prevents goal, scope, acceptance, safety, or test decisions.
5. Put non-blocking uncertainty in `Open Questions / Known Risks`.
6. Use standard terms from `CONTEXT.md` and honor relevant ADRs.
7. Write the PRD under `docs/prd/YYYY-MM-DD-<slug>.md`.
8. Do not create a task card or start implementation automatically.
9. When the PRD is complete, bridge to Router by stating the exact next entry, recommended delivery level, and whether the current session can continue without more Owner input.

Use `assets/prd-template.md` as the source template.

## Output

End with:

```text
PRD 路径
PRD 是否可进入 Router
仍然 BLOCKED 的最小问题（如有）
建议的交付等级（仅建议，最终仍由 Router 判定）
是否可在当前会话继续：是 / 否，原因
```

## Boundaries

- Do not generate code.
- Do not directly enter `IMPLEMENT`.
- Do not mix PRD, task card, and handoff into one file.
- Do not fake user confirmation.
- A PRD does not bypass high-risk `ALIGNMENT_PENDING`.
- Do not start implementation from this Skill; if continuing, hand off to Router / task slicing first.
