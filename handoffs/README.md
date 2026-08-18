# Handoffs

Use this directory for short cross-session recovery snapshots created by `$handoff`.

A handoff should cite the active PRD, task card, Fast Brief, ADR, or relevant files by path. It should not copy the full chat, PRD, ADR, or task card.

Template:

```md
# Handoff: <topic>

## Current Task

- PRD / Task Card / Fast Brief 路径：
- 当前 delivery_level：
- 当前 status：

## Confirmed Facts and Decisions

- 仅列继续工作所必需的结论。

## Completed

- 已完成的分析、修改、验证和证据。

## Current Checkpoint

- 当前停在哪一步；为什么停在这里。

## Remaining / Next Action

1. 

## Blockers / Risks

- 

## Relevant Files

- 只列继续所需的文件路径。

## Commands and Results

- 仅列真正执行过的关键命令及结果。

## Resume Instruction

- 下一会话应先读哪些文件、从哪一步继续。
```
