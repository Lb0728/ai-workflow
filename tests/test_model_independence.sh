#!/usr/bin/env bash
set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/test_helper.sh"

if grep -R -E -i -n \
  'Codex|Cursor|Claude([[:space:]]+Code)?|GPT([[:space:]-]*[0-9.]+)?|OpenAI|Anthropic|Gemini|DeepSeek|AI_MODEL_ID|model_id|model_provider|model_routing' \
  "${WORKFLOW_ROOT}/core" >/dev/null; then
  fail "Core contains a concrete Host, model or model-provider binding"
fi

if grep -R -E -i -n \
  'GPT([[:space:]-]*[0-9.]+)?|OpenAI|Anthropic|Gemini|DeepSeek|AI_MODEL_ID|model_id|model_provider|model_routing' \
  "${WORKFLOW_ROOT}/cli" "${WORKFLOW_ROOT}/dist" >/dev/null; then
  fail "generic CLI or package strategy contains model-provider routing"
fi

for host_root in "${WORKFLOW_ROOT}"/hosts/*; do
  [ -d "$host_root" ] || continue
  if grep -R -E -i -n \
    'model_id|model_provider|model_routing|selected_model|(^|[^[:alnum:]_])GPT([^[:alnum:]_]|$)|Anthropic|Gemini|DeepSeek' \
    "$host_root" >/dev/null; then
    fail "Host Adapter branches on a model or provider: $(basename "$host_root")"
  fi
done

printf '%s\n' "test_model_independence: PASS"
