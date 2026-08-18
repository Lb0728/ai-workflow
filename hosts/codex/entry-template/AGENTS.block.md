<!-- ai-workflow-v2:start -->
## AI Workflow V2

This repository uses the project-local AI Workflow V2 installation.

Before workflow-driven work:

1. Read `.ai/hosts/codex/instructions.md`.
2. Use `.ai/project.yaml` only for detected technical facts.
3. Use Router `required_context` and `context_budget` to select exact files
   from `.ai/architecture/`, `.ai/risks/`, `.ai/defects/` and `.ai/policies/`;
   never load every project-local knowledge file by default.
4. Use `.ai/runtime/` for current task evidence and state.
5. Do not bypass Company Policy, hard Gates, STOP conditions, Self Test or
   manual Commit/Push confirmation.
6. Treat Company Policy as the company Commit rule source. `.ai/policies/` may
   add project rules without overriding it; this `AGENTS.md` block is only the
   Host entry and repository guidance, not the complete Commit policy source.

Reusable Skills are installed from the canonical Workflow source into
`.agents/skills/`.
<!-- ai-workflow-v2:end -->
