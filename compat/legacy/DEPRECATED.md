# DEPRECATED — V1 Legacy Loader

V1 legacy entry points are frozen for compatibility only. They are NOT active
workflow entries and must not be used for new work.

- New work starts with the V2 machine-level CLI: `ai-workflow`.
- Project installation: `ai-workflow init --host <codex|cursor>`.
- Task lifecycle: `ai-workflow new` → `ai-workflow next` → `ai-workflow finish`
  → `ai-workflow transition` (validated) → `ai-workflow assemble` / `doctor`.
- V1 scripts (`tool/ai_loop_new.sh`, `tool/ai_loop_next.sh`, `tool/ai_agent.sh`,
  `compat/legacy/loader.sh`, root symlinks) remain only so historical tasks and
  documented commands do not break. Do not extend them.

Freeze condition: V1 is frozen when the V2 internal developer trial completes
acceptance (the V2 acceptance suite in `tests/run_all.sh`). After that,
V1 files are removed in a single cleanup commit; no new V1 behavior is added
before then either.
