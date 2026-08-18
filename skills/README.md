# Universal AI Workflow Skills

These Agent Skills are Host-neutral, explicit discovery and handoff entry points
for the shared AI Workflow.

They do not replace `ai/agents/`, `ai/workflows/`, task cards, self-test gates, or high-risk `ALIGNMENT_PENDING`.

Source ownership:

- Canonical Skill source files live in the Workflow package under `skills/`.
- A Host Adapter exposes the canonical source through the Host-supported Skill
  discovery location.
- `ai-workflow init` asks the active Host Adapter to expose the canonical source
  through its repository Skill location.

Available Skills:

- `$grill-me`: clarify unclear local requirements, plans, or Bug scope.
- `$grill-with-docs`: clarify requirements and maintain durable terminology or ADRs when needed.
- `$to-prd`: turn confirmed decisions into an executable PRD.
- `$to-task-cards`: split a confirmed PRD or plan into executable vertical task slices.
- `$handoff`: create a short resumable state snapshot for another session.

All Skills are explicit-only. Do not invoke them implicitly just because a chat
is vague. The active Host Adapter defines the invocation syntax.

Skill closeout must be a bridge, not a dead end:

- If the Skill reaches its own stopping point, it must state the current phase, completed output, legal next phase, and whether the next phase can continue without Owner input.
- If the next phase is legal and does not violate the Skill boundary, the current session should continue through Router / Agent flow instead of waiting for the Owner to type “继续下一步”.
- A Skill must still stop at its own hard boundary: `$grill-me` does not write PRDs or code, `$to-prd` does not create task cards or implement, `$to-task-cards` does not implement, and `$handoff` does not make new decisions.
- When a Skill cannot continue, the final line must name the single blocker, not a generic “下一步”.
