#!/usr/bin/env bash
set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/test_helper.sh"

contract="${WORKFLOW_ROOT}/hosts/HOST_ADAPTER_CONTRACT.md"
[ -f "$contract" ] || fail "Host Adapter Contract missing"

section_value() {
  local manifest="$1"
  local section="$2"
  local key="$3"
  awk -v section="$section" -v key="$key" '
    $0 == section ":" { in_section = 1; next }
    in_section && /^[^[:space:]]/ { in_section = 0 }
    in_section && $0 ~ "^[[:space:]]+" key ":[[:space:]]*" {
      value = $0
      sub(/^[^:]+:[[:space:]]*/, "", value)
      gsub(/^['\''"]|['\''"]$/, "", value)
      print value
      exit
    }
  ' "$manifest"
}

host_count=0
for manifest in "${WORKFLOW_ROOT}"/hosts/*/host.yaml; do
  [ -f "$manifest" ] || continue
  host_count=$((host_count + 1))
  host_root="$(dirname "$manifest")"
  directory_id="$(basename "$host_root")"
  manifest_id="$(awk '
    /^host:[[:space:]]*$/ { in_host = 1; next }
    in_host && /^[^[:space:]]/ { in_host = 0 }
    in_host && /^[[:space:]]+id:[[:space:]]*/ {
      value = $0
      sub(/^[^:]+:[[:space:]]*/, "", value)
      gsub(/^['\''"]|['\''"]$/, "", value)
      print value
      exit
    }
  ' "$manifest")"

  [ "$manifest_id" = "$directory_id" ] ||
    fail "Host manifest id does not match directory: ${directory_id}"

  for required_section in \
    host instruction_entry skill_locations capabilities permission_model \
    state_presentation semantic_ownership; do
    grep -Eq "^${required_section}:" "$manifest" ||
      fail "Host manifest missing ${required_section}: ${directory_id}"
  done

  for entry_key in \
    filename template instructions_template install_mode verification_marker \
    discovery_scope; do
    [ -n "$(section_value "$manifest" instruction_entry "$entry_key")" ] ||
      fail "Host manifest missing instruction_entry.${entry_key}: ${directory_id}"
  done

  [ -n "$(section_value "$manifest" skill_locations repository)" ] ||
    fail "Host manifest missing skill_locations.repository: ${directory_id}"
  [ "$(section_value "$manifest" skill_locations source_owner)" = "skills" ] ||
    fail "Host Adapter does not reuse canonical Skills: ${directory_id}"

  for ownership_key in \
    core_protocol skills agents company_policy project_facts runtime; do
    [ "$(section_value "$manifest" semantic_ownership "$ownership_key")" = "false" ] ||
      fail "Host Adapter claims semantic ownership of ${ownership_key}: ${directory_id}"
  done

  if grep -R -E -i -n \
    'model_id|model_provider|model_routing|(^|[^[:alnum:]_])GPT([^[:alnum:]_]|$)|Anthropic|Gemini|DeepSeek' \
    "$host_root" >/dev/null; then
    fail "Host Adapter contains model selection or model-provider routing: ${directory_id}"
  fi

  if find "$host_root" -type f \
    \( -name 'SKILL.md' -o -name 'agents.yaml' -o -name 'policy.yaml' \
       -o -name 'project.yaml' -o -name 'role-profile.yaml' \) \
    -print -quit | grep -q .; then
    fail "Host Adapter copies canonical Agent, Skill, Policy, Role or Project facts: ${directory_id}"
  fi

  if grep -R -E -i -n \
    "(^|[^[:alnum:]_-])${directory_id}([^[:alnum:]_-]|$)" \
    "${WORKFLOW_ROOT}/core" >/dev/null; then
    fail "Core names a concrete Host Adapter: ${directory_id}"
  fi

  if grep -R -E -i -n \
    "(^|[^[:alnum:]_-])${directory_id}([^[:alnum:]_-]|$)" \
    "${WORKFLOW_ROOT}/cli" \
    "${WORKFLOW_ROOT}/dist/package.sh" \
    "${WORKFLOW_ROOT}/dist/universal-workflow-v2.yaml" >/dev/null; then
    fail "generic CLI or package strategy names a concrete Host Adapter: ${directory_id}"
  fi
done

[ "$host_count" -ge 1 ] || fail "no Host Adapter manifests found"
[ -f "${WORKFLOW_ROOT}/hosts/codex/host.yaml" ] || fail "Codex Host Adapter missing"
[ -f "${WORKFLOW_ROOT}/hosts/cursor/host.yaml" ] || fail "Cursor Host Adapter missing"

printf '%s\n' "test_host_adapter_contract: PASS"
