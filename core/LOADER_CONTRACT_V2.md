# Loader Contract v2

## Status

- Contract version: `2`
- Activation state: `shadow`
- Fixed project binding required: no
- Active V1 Loader replaced: no

This contract defines the Host-neutral V2 load boundary. It does not activate
V2 through any legacy entry until compatibility regression passes.

## Owners

| Layer | Owns | Must not own |
|---|---|---|
| Core | State protocol, routing semantics, risk levels, Gate vocabulary, reusable Agents, Workflows, Skills and Templates | Host paths, project facts, company-specific formats, Runtime instances |
| Host Adapter | Host instruction entry, supported capabilities, permissions, confirmation mapping and output presentation | Risk levels, Skills, Agent behavior, Company Policy, project facts |
| Company Policy | Company-wide Commit, Review, Security and Delivery constraints | Project architecture or task evidence |
| Project Profile | Evidence-detected technical facts and commands | Business rules or guessed architecture |
| Project Local Knowledge | Business architecture, risks, defects and project policies | Core state/action semantics |
| Role | Role stages, permissions and execution policy | Project facts, Company Policy or Runtime evidence |
| Runtime | Current task state, evidence, handoff and closeout | Reusable behavior |
| User task | Current request, scope and explicit constraints | Silent override of immutable constraints |

One fact has one owner. A compatibility entry is an alias, never another owner.

## Immutable constraints

These constraints cannot be overridden by Role, Project Profile, Project Local
Knowledge, Runtime or the user task:

- Core safety Guardrails;
- Company Policy;
- automatic Commit and Push remain prohibited;
- hard Gates;
- STOP conditions.

The Loader must report both sources of an immutable conflict and return a
non-zero result. It must not silently apply last-write-wins behavior.

## Context precedence

For ordinary contextual facts:

```text
current user task
> current Runtime state
> Project Local Knowledge and generated Project Profile
> Role defaults
> Core defaults
```

The Host Adapter is not a semantic precedence layer. It makes the resolved
context available to the host.

The selected Host comes from an explicit generic Host id or the target
project's `.ai/ai.lock`. Missing and unknown Host ids are errors; Core has no
concrete Host default. Model selection remains internal to the Host and is not
an input to Loader, Router, Agent selection, risk calculation or Gate results.

## Required inputs

```text
workflow VERSION
core defaults and selected Core Agent
hosts/<host>/host.yaml
policies/company/policy.yaml and declared policy files
roles/<role>/role-profile.yaml
<project>/.ai/project.yaml
<project>/.ai/ai.lock
<project>/.ai/architecture/
<project>/.ai/risks/
<project>/.ai/defects/
<project>/.ai/policies/
<project>/.ai/runtime/
```

Project Local Knowledge directories may be empty. Generated facts that cannot
be confirmed must be `unknown` or `missing`; they must not be invented.

## Risk-adaptive context assembly

- Router bootstrap receives the Project Profile, a bounded directory-level
  Project Local Knowledge index and the current Runtime task. It does not
  inline architecture, risk, defect or project-policy bodies.
- Router outputs `context_budget` (`L1`, `L2` or `L3`) and `required_context`.
- `required_context` contains exact project-relative `.ai/` knowledge files,
  not whole knowledge directories.
- L1 loads no Project Local Knowledge bodies.
- L2 loads only exact task-relevant files selected by Router.
- L3 loads selected architecture and related knowledge; defect cards are
  capped at five.
- The Host makes this resolved context available but must not infer relevance
  by loading every knowledge file.

## Command policy

- Commands are represented as argv arrays.
- No Loader, Doctor or Discovery component may use `eval`.
- Doctor validates command declarations but does not execute project commands.
- Host Adapter permissions cannot weaken Core or Company Policy.
- State-changing commands remain subject to the current host's approval model
  and explicit user authority.

## Compatibility policy

- V1 commands and paths remain active until V2 acceptance.
- The Compatibility Loader defaults to V1 unless V2 is explicitly selected or
  a valid `.ai/project.yaml` and `.ai/ai.lock` are present.
- V2 shadow assembly may run beside V1.
- Rollback is removal of the V2 selection, not deletion of V1 assets.
- Existing Runtime instances are never copied into a release package.

## Exit contract

| Result | Exit |
|---|---:|
| Resolve/describe/validation success | 0 |
| Missing required input or immutable conflict | 1 |
| Invalid command or argument | 2 |

Diagnostics must identify the missing or conflicting source without printing
credentials, personal absolute paths or project source content.
