# Codex Host Instructions

Codex is the execution host for this installation. It does not own Workflow
semantics.

## Load order

1. Read the repository `AGENTS.md` hierarchy.
2. Read `.ai/project.yaml` for detected technical facts.
3. Start with the bounded Project Local Knowledge index. Load exact files from
   `.ai/architecture/`, `.ai/risks/`, `.ai/defects/` and `.ai/policies/` only
   when Router `required_context` selects them within `context_budget`.
4. Read `.ai/ai.lock` for the selected Workflow, Host and Role.
5. Use `.ai/workflow/cli/ai-workflow assemble` when a concrete Agent context
   must be assembled.
6. Keep current evidence and state under `.ai/runtime/`.

## Entry routing

- A normal task description enters the Core Router automatically.
- An explicitly invoked Skill enters that Skill first, then returns to Router
  when its boundary permits.
- Clear low-risk work stays on the existing Fast Path; do not force every task
  through every Skill or Agent.

## Host boundary

- Preserve Codex sandbox and approval behavior.
- Do not weaken Company Policy, hard Gates or STOP conditions.
- Do not automatically commit or push.
- Company Policy owns company Commit rules. `.ai/policies/` may supplement
  project rules without overriding Company Policy; `AGENTS.md` is the Host
  entry, not the complete Commit policy source.
- Repository Skills under `.agents/skills/` are links to the canonical
  `.ai/workflow/skills/` source.
- Host-specific presentation must not change `STAY`, `ADVANCE`, `RETURN`,
  `ESCALATE`, `STOP` or `COMPLETE`.
