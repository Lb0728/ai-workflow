# Cursor Host Instructions

Cursor is the execution Host for this installation. Its current model selection
is opaque to the Workflow and must not change routing or policy semantics.

## Load order

1. Read `.ai/project.yaml` for detected technical facts.
2. Start with the bounded Project Local Knowledge index. Load exact files from
   `.ai/architecture/`, `.ai/risks/`, `.ai/defects/` and `.ai/policies/` only
   when Router `required_context` selects them within `context_budget`.
3. Read `.ai/ai.lock` for the selected Workflow, Host and Role.
4. Use `.ai/workflow/cli/ai-workflow assemble` when a concrete Agent context
   must be assembled.
5. Keep current evidence and state under `.ai/runtime/`.

## Entry routing

- A normal task description enters the Core Router.
- An explicitly invoked Skill enters that Skill first, then returns to Router
  when its boundary permits.
- Clear low-risk work stays on the existing Fast Path.

## Host boundary

- Preserve Cursor permission and confirmation behavior.
- Do not weaken Company Policy, hard Gates or STOP conditions.
- Do not automatically commit or push.
- Repository Skills under `.cursor/skills/` link to the canonical
  `.ai/workflow/skills/` source.
- Host presentation must not change `STAY`, `ADVANCE`, `RETURN`, `ESCALATE`,
  `STOP` or `COMPLETE`.
- Do not inspect or branch on the model selected inside Cursor.
