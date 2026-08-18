# V2 Installation Contract

## Inputs

- one extracted universal V2 package;
- one target project root supplied at install time;
- a supported Host declared by `hosts/<host>/host.yaml`;
- a supported Role (`developer` in the first implementation).

No package contains a fixed coworker path or a fixed project adapter.

## Generated project state

```text
.ai/
  project.yaml
  ai.lock
  architecture/
  risks/
  defects/
  policies/
  runtime/
  hosts/<selected-host>/instructions.md
  workflow -> installed package
<host-skill-location>/ -> canonical V2 Skills plus optional Host metadata
<host-entry> -> Host-declared managed block or managed file
```

`project.yaml` contains evidence-detected facts only. Business architecture,
known risks and defects stay explicit in their corresponding project-local
directories.

## Ownership

- Package: Core, Company Policy, Host Adapter, Role, Skills and tooling.
- Project: generated profile, local knowledge and current Runtime.
- Host: permissions, sandbox, instruction and Skill discovery.
- User: task scope and authorization for state-changing actions.

The selected model belongs to the Host and is not an installation input.
Workflow Core, Router, Loader and Runtime do not read model ids or providers.

## Idempotency and safety

- Re-running `init` refreshes generated discovery and the lock.
- Existing project `AGENTS.md` content is preserved.
- Existing non-symlink Skill destinations cause a failure instead of overwrite.
- Doctor never executes declared build, static-check or test commands.
- Commit and Push are never automatic.

## Supported operating-system environments

- macOS with Bash;
- Windows through WSL2 with the package and project stored in the WSL
  filesystem.

Native PowerShell, Command Prompt and Git Bash execution are outside this
release contract. CRLF handling, path quoting, symlink checks and installation
prerequisites belong to Distribution and CLI validation, not Core semantics.

## Zephyr project capability

Zephyr support is a Project Discovery and managed-build capability for WSL2. It
does not add an Embedded Agent, Host semantic, chip-vendor binding or
board-specific workflow.

- Flutter, Dart and Go detection retain their existing priority and commands.
- Generic CMake files and directory names are not Zephyr evidence.
- Zephyr build rules apply only when `project.detected_kind` is `zephyr`.
- Existing valid build metadata is reused before considering a first build.
- Board and application remain unconfirmed unless project or build evidence
  provides them.
- Automatic `west build` is allowed through the managed build command.
- Flash, debug, attach and device connection are always manual.
- Build success is not device-validation success.

## V1 compatibility

The source repository keeps the existing V1 commands unchanged. A standalone
V2 package excludes fixed project adapters; when it must delegate a legacy
request, set `AI_WORKFLOW_V1_ROOT` to the existing V1 installation. V2 does not
copy, replace or delete V1 project knowledge.
