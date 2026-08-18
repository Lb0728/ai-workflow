---
name: handoff
description: 为上下文压缩、会话中断、换会话继续或当天暂停任务生成短小可恢复的状态快照。仅在用户明确调用 $handoff 时使用；引用 PRD、Task Card、ADR 路径，不复制完整聊天、不制造新决策、不伪造命令结果。
---

# Handoff

Use this Skill when work needs to resume in another session or after context compression.

## Workflow

1. Read the repository guidance exposed by the active Host Adapter.
2. Read the active task card, PRD, Fast Brief, ADR, or relevant current artifacts.
3. Summarize only what is needed to resume.
4. Include only commands that were actually executed and their real results.
5. Reference long documents by path. Do not copy them into the handoff.
6. Resolve `runtime.handoffs` through the active Loader, then write
   `YYYY-MM-DD-<topic>.md` there.
7. Preserve only the current conclusion, critical evidence paths, delivery risk, `next_action_decision`, and one resume action; omit investigation chronology and repeated upstream analysis.

Use `assets/handoff-template.md` as the source template.

## Output

End with:

```text
Handoff 路径
恢复时应先读的文件
下一步最小动作
仍然阻塞 / 未验证的内容
```

## Boundaries

- Do not copy full chat history.
- Do not copy full PRDs, ADRs, or task cards.
- Do not copy search output, full defect memory cards, or reasoning chronology; reference only matched paths.
- Do not create product or architecture decisions.
- Do not claim tests or commands ran unless they did.
- If a task card exists, update only necessary status and cite it.
