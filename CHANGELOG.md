# Changelog

All notable changes to this project are documented here. The project follows
[Keep a Changelog](https://keepachangelog.com/) and uses a baseline of
`2.0.0-rc.5` for its open-source start.

## [2.0.0-rc.5] - 2026-08-18

Open-source baseline. The repository was sanitized before first publication:
company Project Adapters, real task instances, internal migration records and
personal data were removed and archived privately; a generic `demo-project`
Adapter and sanitized example task cards remain as documentation.

### Added

- `core/config/state-machine.yaml`: single source of truth for stage aliases,
  stage↔decision mapping, transition table, required gates, default next stage
  and vocabulary enums.
- `core/lib/state_machine.sh`: awk-based read-only state machine accessor.
- `core/schemas/task-card.schema.yaml` + `core/lib/task_card.sh`: task card
  schema validation enforced by `new`, `transition` and `doctor`.
- `ci/pipeline.sh` and `.github/workflows/acceptance.yml`: six-gate CI pipeline
  (bash syntax, shellcheck, acceptance suite, distribution manifest, clean
  worktree, artifact freshness).
- `docs/GLOSSARY.md`: zh/en term mapping.
- `examples/tasks/`: sanitized example task cards (generic identifiers).
- MIT license and this changelog.

### Changed

- Router, `finish` and `transition` now consume the shared state machine tables
  instead of maintaining private copies.
- `finish` refuses to move a task into `ready_for_qa` without real self-test
  evidence (traffic light + substantive evidence sections).
- `dist/package.sh` ships `core/lib` and `core/schemas`, and generates
  checksums with relative filenames (no absolute paths).
- Shellcheck gate passes across all scripts (unicode-quote and unused-variable
  directives documented per file).

### Removed

- Company-specific Project Adapters, real task instances, migration records,
  internal distribution manifests, IDE metadata and personal artifacts
  (archived privately; never part of the public history).
