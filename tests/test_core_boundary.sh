#!/usr/bin/env bash
set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/test_helper.sh"

boundary_output="${TMPDIR:-/tmp}/workflow-core-boundary.$$"
trap 'rm -f "$boundary_output"' EXIT

if grep -R -E -i -n \
  'Codex|Cursor|Claude([[:space:]]+Code)?|GPT([[:space:]-]*[0-9.]+)?|OpenAI|Anthropic|Gemini|DeepSeek|openai\.yaml|AGENTS\.md|CLAUDE\.md|\.cursor/rules|AI_MODEL_ID|model_id|model_provider' \
  "${WORKFLOW_ROOT}/core" \
  >"$boundary_output"; then
  sed -n '1,120p' "$boundary_output" >&2
  fail "Core contains a concrete Host, model, provider or Host-specific entry"
fi

if grep -R -E -i -n \
  'Flutter|Dart|Swift|Kotlin|Android|(^|[^[:alnum:]_])iOS([^[:alnum:]_]|$)|Xcode|TestFlight|Figma|IMEI
  "${WORKFLOW_ROOT}/core" \
  >"$boundary_output"; then
  sed -n '1,120p' "$boundary_output" >&2
  fail "Core contains a fixed Project fact, path or technology-stack example"
fi

if grep -R -E -n \
  '/Users/[A-Za-z0-9._-]+/|/Volumes/[A-Za-z0-9._-]+/|[A-Za-z]:\\Users\\[^\\]+\\' \
  "${WORKFLOW_ROOT}/core" \
  >"$boundary_output"; then
  sed -n '1,120p' "$boundary_output" >&2
  fail "Core contains a personal absolute path"
fi

if grep -R -E -n \
  'Project Adapter|project_adapter|adapter_inputs|adapter\.' \
  "${WORKFLOW_ROOT}/core" \
  >"$boundary_output"; then
  sed -n '1,120p' "$boundary_output" >&2
  fail "Core contains residual project Adapter semantics"
fi

printf '%s\n' "test_core_boundary: PASS"
