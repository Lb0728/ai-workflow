#!/usr/bin/env bash
set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WORKFLOW_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"

exec "${WORKFLOW_ROOT}/cli/commands/assemble.sh" --host codex "$@"
