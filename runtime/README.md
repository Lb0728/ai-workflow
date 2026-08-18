# Runtime

This is the source-repository and distribution-seed Runtime layout.

Runtime selection:

- an installed project uses `<project_root>/.ai-runtime/` so different projects
  never share task instances or handoffs;
- `AI_RUNTIME_ROOT` may explicitly select another Runtime root;
- source and legacy operation falls back to `<workflow_root>/runtime/`;
- the root `tasks` entry is a compatibility symlink only for that fallback;
- distribution archives contain only this empty layout;
- reusable definitions in root `handoffs/` and `defect_memory/` are not runtime data and remain unmoved.
