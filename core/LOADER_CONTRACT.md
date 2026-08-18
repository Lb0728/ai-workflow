# Core Loader Contract

## 1. Status

- Contract version: `1`
- Migration phase: `phase4-agent-activation`
- Runtime task owner: selected Runtime root
- Project-specific physical asset owner: Project Local Knowledge
- Agent owner: Core plus Project Profile and Project Local Knowledge

Phase 4 activates all reusable Agents after their behavior-equivalence Gate passes.

## 2. Layer ownership

| Layer | Owns | Must not own |
|---|---|---|
| Core | Evidence First, risk levels, actions, Gate result vocabulary, routing and closeout protocols | Project names, project paths, project commands, business classes |
| Project Profile and Project Local Knowledge | Detected project facts, architecture sources, risk domains, commands, project-specific Gates and i18n rules | Core state/action semantics, role permissions, Runtime task instances |
| Role Adapter | Role stages, permissions and role-specific execution policy | Project facts, runtime evidence, Core protocol vocabulary |
| Runtime | Task state, evidence, handoffs, defects and closeouts | Reusable policy or project configuration |

An item must have one target owner. Compatibility links are aliases, never duplicate owners.

## 3. Load order and merge rules

The active loader order is:

```text
core/config/core-defaults.yaml
-> adapters/<project>/project-profile.yaml
-> adapters/<project>/config/*.yaml
-> roles/<role>/role-profile.yaml
-> <runtime_root>/tasks/<current-task>.md
```

Rules:

1. Layers are namespaced; the loader must not perform an unrestricted recursive merge.
2. Project and Role Adapters may extend configured slots but may not override Core protocol fields.
3. Runtime may select configured project and role IDs, but may not redefine reusable policy.
4. These Core fields are immutable outside Core:
   - `risk_levels`
   - `decision_actions`
   - `gate_results`
   - `evidence_first`
   - `default_to_lowest_reasonable_cost`
   - `allow_implicit_skill_invocation`
5. A duplicate owner is an error, not a last-write-wins condition.

## 4. Path resolution

- `project_root`: supplied by the caller.
- `workflow_root`: directory containing this repository.
- Project paths are resolved from `project_root`.
- Legacy and shadow workflow paths are resolved from `workflow_root`.
- Adapter-internal paths are resolved from the selected Adapter directory.
- Runtime paths are resolved from `AI_RUNTIME_ROOT` when explicitly supplied.
- Otherwise an installed project uses `<project_root>/.ai-runtime`; source and
  legacy operation fall back to `<workflow_root>/runtime`.
- Absolute personal paths are invalid in distributable Core and public Adapter configuration.

## 5. Missing data behavior

| Condition | Result |
|---|---|
| Core defaults, project profile, required Adapter config or role profile missing | Error |
| Required project rules or architecture source missing | Error |
| Optional project context missing | Warning |
| Runtime directory not writable after config-driven routing is active | Error |
| Runtime directory not writable | Error for state-changing operations; Warning for read-only inspection |
| Project validation command not configured | Error when its Gate is required; otherwise Warning |
| Existing generated i18n output found but source path unresolved | Warning |

The loader must not infer a missing project fact or ask the Owner for information that can be found through configured repository paths.

## 6. Command contract

- Commands are declared as argument arrays.
- `doctor` validates declarations but never executes project commands.
- The future runner must not use `eval`.
- Environment variables required by a command must be explicitly declared.
- Project commands belong to the Project Profile or Project Local Knowledge, not Core.

## 7. Phase 4 Agent compatibility

- Existing scripts remain the active entry points.
- Existing copy-paste commands remain valid.
- `<runtime_root>/tasks/` is canonical. The root `tasks` compatibility link
  applies only when `<workflow_root>/runtime` is the selected Runtime.
- Project-specific workflow, self-test and case assets are canonical inside Project Local Knowledge; their old names are relative compatibility links.
- `core/agents/*.md` and `core/agents.yaml` are canonical; root Agent entries are relative compatibility links.
- Agent project facts and commands are loaded from Project Profile; risks, Gates, i18n and project policy supplements come from Project Local Knowledge.
- `ai_agent.sh` accepts explicit project, Adapter and Role selection while preserving its original positional invocation.
- Agent prompt assembly defaults to the Router budget: it inlines only the selected Agent's required Project Profile, Project Local Knowledge and Role inputs plus the task. There is no automatic full-knowledge mode.
- Compatibility links never create a second active copy.
- Core, Company Policy, Project Profile, Project Local Knowledge and Role are active for Agent assembly.
- The Loader resolves declared paths but does not execute project commands or perform unrestricted recursive merges.

## 8. Activated migration boundary

Active now:

- runtime task instances;
- project-specific device workflow;
- project-specific self-test notes;
- project-bound cases.
- all generic Core Agents plus selected Project Profile, Project Local Knowledge and Role context;
- reusable Core Workflows and Templates;
- config-driven task types, validation commands and commit conventions.

Deferred:

- reusable handoff and defect-memory definitions;
- optional removal of compatibility links after downstream adoption.

## 9. Activation gate

Core activation remains valid only while:

1. Core protocol, Project Profile facts and Project Local Knowledge each have one owner.
2. Core contains no selected-project terms.
3. Setup, routing and Agent assembly regressions pass.
4. Every assembled Agent contains only its required Project Profile, Project Local Knowledge and Role inputs.
5. Old entries resolve to canonical files without duplicate active copies.
