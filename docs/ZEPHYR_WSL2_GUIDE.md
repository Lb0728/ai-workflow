# Zephyr on Windows + WSL2 + Codex

## Scope

AI Workflow V2 supports evidence-based discovery and managed compilation for
generic Zephyr applications in WSL2. It does not bind the Workflow to a VS Code
extension, chip vendor, board family or project name.

```text
Windows -> WSL2 Bash -> Codex -> AI Workflow V2 -> west build
```

VS Code may provide the developer-facing entry, but its extensions and private
settings are not Workflow inputs.

## Developer-provided environment

The developer is responsible for installing and configuring:

- WSL2 and a Linux distribution;
- `west`;
- the Zephyr SDK and toolchain;
- `ZEPHYR_BASE` or the equivalent west workspace environment;
- project-specific modules and dependencies.

Keep the Workflow package, west workspace and application under the WSL
filesystem, such as `~/tools` and `~/work`. Paths under `/mnt/c` are outside the
recommended release setup.

Verify the environment:

```bash
west --version
west topdir
```

## Initialize and build

From the project or west workspace root:

```bash
ai-workflow init --host codex
ai-workflow doctor
ai-workflow build
```

Zephyr detection requires either valid Zephyr build metadata or an application
containing both a Zephyr `find_package` reference and `prj.conf`. A generic
`CMakeLists.txt`, `src/`, `include/`, `build/`, `boards/`, `west.yml`,
`.west/config` or `ZEPHYR_BASE` alone is not sufficient.

When a valid build directory exists, the Workflow reuses it:

```bash
west build -d <build-dir>
```

For a first build, the Workflow uses the following only when both values are
supported by evidence:

```bash
west build -b <board> <application-dir>
```

If board or application cannot be confirmed:

```text
Build: NOT_RUN
Action: STOP
Required input: target board and application directory
Flash: NOT_RUN
Device Validation: NOT_RUN
```

The Owner should provide only the target board value accepted by Zephyr and the
project-relative application directory. The Workflow must not guess either
value from a vendor, chip family, open file or VS Code extension state.

## Device safety boundary

Automatic compilation is allowed. Automatic flashing, debugging, attaching or
device connection is forbidden, including:

```text
west flash
west debug
west attach
nrfjprog
openocd
JLinkExe
pyocd flash
esptool
```

Shell aliases, command chains, pipes, subshells and vendor-specific tools do not
weaken this rule. Every managed build reports:

```text
Flash: NOT_RUN
Device Validation: NOT_RUN
```

`Build: PASS` proves compilation only. It does not prove that the image was
flashed or that firmware behavior passed on hardware.

## Manual evidence

Flashing and device validation remain human actions. Record the result in the
active Task Card:

```md
### Manual Flash

- Board: [confirmed board]
- Build directory or image: [project-relative path]
- Command owner: human
- Flash result: PASS | FAIL | NOT_RUN | BLOCKED
- Evidence: [sanitized log or screenshot path]

### Device Validation

- Environment: [board and relevant external setup]
- Preconditions: [required setup]
- Steps: [manual steps]
- Expected result: [expected behavior]
- Actual result: [observed behavior]
- Device Validation: PASS | FAIL | NOT_RUN | BLOCKED
- Evidence: [sanitized log, screenshot or measurement]
```

Do not change `Flash` or `Device Validation` from `NOT_RUN` without real human
evidence.
