# AI Workflow V2 Quickstart

## Release state

V2 is isolated from V1 and approved for the internal developer trial. It does
not replace the current V1 stable workflow.

## Install into a project

After extracting the package, install it once on the developer machine.

macOS:

```bash
./dist/install.sh --prefix <user-tools-prefix>
```

Add `<user-tools-prefix>/bin` to `PATH`. Then, from any target project root:

```bash
ai-workflow init --host codex
# or
ai-workflow init --host cursor
```

Initialization:

- detects the project stack and writes `.ai/project.yaml`;
- writes a version and selection lock to `.ai/ai.lock`;
- creates project-local knowledge and Runtime directories;
- installs the selected Host entry declared by `hosts/<host>/host.yaml`;
- links repository Skills at the selected Host's declared discovery location;
- runs Doctor without executing project build or test commands.

The Workflow package remains in its dedicated installation/extraction directory.
Do not copy or symlink an `ai/` source directory into a target project. Every
target project uses the same command above; only generated `.ai/` state belongs
in that project.

The current working directory becomes the project root unless
`--project-root` is supplied. Packages are not built for one fixed repository
path or one coworker.

## Windows through WSL2

Windows support uses the same package and Bash CLI through WSL2. Native
PowerShell, Command Prompt and Git Bash execution are not part of this release.
Keep both the extracted package and target project in the WSL filesystem rather
than under `/mnt/c`, so repository and Skill symlinks retain Linux semantics.

From a WSL2 Bash terminal:

```bash
cd ~/tools/universal-workflow-v2-<version>
./dist/install.sh --prefix "$HOME/.local"
export PATH="$HOME/.local/bin:$PATH"

cd ~/work/<target-project>
ai-workflow init --host codex
ai-workflow doctor
```

The Windows Codex Host must open and execute the project through its WSL
environment. Operating-system compatibility is limited to the installer and CLI
runtime; Core routing semantics remain unchanged.

## Zephyr projects in WSL2

Zephyr projects may use evidence-based Project Discovery and managed
compilation:

```bash
ai-workflow init --host codex
ai-workflow build
```

The developer environment supplies `west`, the Zephyr SDK, toolchain and
workspace configuration. Automatic build is allowed. Automatic flash, debug,
attach and device connection are forbidden. A successful build never represents
device validation.

See `docs/ZEPHYR_WSL2_GUIDE.md` for board/application discovery, STOP behavior
and manual validation evidence.

## Host and model boundary

`codex` and `cursor` are Host Adapter ids. A Host Adapter exposes repository
instructions, Skills, permissions, Shell capabilities and unified state
presentation. It does not select or report a model.

The model currently selected inside Cursor is opaque to the Workflow. Changing
that model must not change Router state, risk level, Gate results or Agent
selection.

## Validate

```bash
<workflow-root>/cli/ai-workflow doctor --project-root <project-root>
<workflow-root>/cli/ai-workflow feedback --project-root <project-root>
```

`feedback` intentionally reports only Workflow version, Host, Role, detected
project kind, profile version and optional task state fields. It does not
include source paths, logs, accounts, tokens or Runtime content.

When reporting a problem, use `docs/ISSUE_TEMPLATE.md` and attach only this
sanitized output.

## Assemble a task

```bash
<workflow-root>/cli/ai-workflow assemble \
  --project-root <project-root> \
  --role developer \
  router \
  <project-root>/.ai/runtime/tasks/<task>.md
```

Codex discovers the repository entry through `AGENTS.md`. Cursor discovers
`.cursor/rules/ai-workflow.mdc`. Both are thin entries to the same Core, Company
Policy, Project and Runtime inputs; Core behavior is not copied per Host.

Company Policy is the company Commit rule source. Project-local
`.ai/policies/` may add non-conflicting repository rules. `AGENTS.md` remains a
Host discovery entry and repository guidance, not the complete Commit policy
source.

To inspect the deterministic next-state and Gate result for an existing task:

```bash
ai-workflow next .ai/runtime/tasks/<task>.md
```

To apply a validated task decision, use the Runner rather than editing `status`
by hand:

```bash
ai-workflow next --apply .ai/runtime/tasks/<task>.md
```

The Runner rejects an illegal transition without changing the task. It records
three independent validation layers in the task frontmatter: `STATIC`,
`RUNTIME`, and `ACCEPTANCE`. `FIXED` / `DONE` requires all three to be `PASS`;
an attempted fix that was reverted must remain `reverted` and return to a
diagnosis, requirement, or human stage.

To create a task card and to close a loop stage:

```bash
ai-workflow new <bugfix|feature|techdebt|device> <task-id> [slug] [priority] [delivery_level]
ai-workflow finish .ai/runtime/tasks/<task>.md
```

Cards are schema-checked on creation and before every transition
(`core/schemas/task-card.schema.yaml`); `finish` also refuses to move a task
into `ready_for_qa` without real self-test evidence. Stage names, transitions
and required gates are defined once in `core/config/state-machine.yaml`.

## Roll back

V1 remains independent. To stop using a project-local V2 installation, remove
the V2 entry block and local links in that project. Do not delete or mutate the
V1 stable branch or tag.
