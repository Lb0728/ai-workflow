#!/usr/bin/env bash
# State Machine library — read-only access to core/config/state-machine.yaml.
#
# Consumers source this file and call sm_* functions. No eval is used;
# YAML is parsed with awk against a fixed, in-repo schema. Editing the
# state machine means editing the YAML, never this file or its consumers.
#
# Note: this library deliberately does not set -e/-u; option flags belong to
# the sourcing consumer (sourcing would otherwise mutate its shell state).

_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SM_YAML="${_LIB_DIR}/../config/state-machine.yaml"

# Parse a simple `key: value` section (stage_aliases, stage_to_decision,
# decision_to_stage, delivery_tiers, gate_result_kinds).
# Always exits 0 (empty output for an unknown key), mirroring the legacy
# `case ... *) echo ""` semantics — callers run under `set -e`.
_sm_simple_map() {
  local section="$1"
  local key="${2:-}"
  awk -v section="$section" -v key="$key" '
    $0 == section ":" { in_section = 1; next }
    in_section && /^[^[:space:]]/ && $0 != section ":" { exit }
    in_section && key != "" && $0 ~ "^[[:space:]]*" key ":" {
      sub("^[[:space:]]*" key ": *", "")
      print
      exit
    }
  ' "$SM_YAML"
}

# Parse a `- item` list section (canonical_stages, decision_stages).
_sm_list() {
  local section="$1"
  awk -v section="$section" '
    $0 == section ":" { in_section = 1; next }
    in_section && /^[^[:space:]]/ && $0 != section ":" { exit }
    in_section && $0 ~ /^[[:space:]]*- / {
      sub(/^[[:space:]]*-[[:space:]]*/, "")
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", $0)
      print
    }
  ' "$SM_YAML"
}

# Parse a `key: [a, b]` vocabulary section (vocabulary.decision_actions...).
_sm_vocabulary() {
  local list_name="$1"
  awk -v list_name="$list_name" '
    function trim(s) { gsub(/^[[:space:]]+|[[:space:]]+$/, "", s); return s }
    $0 == "vocabulary:" { in_vocab = 1; next }
    in_vocab && /^[^[:space:]]/ && $0 != "vocabulary:" { exit }
    in_vocab && $0 ~ "^[[:space:]]*" list_name ": *\\[" {
      line = $0
      sub("^[[:space:]]*" list_name ": *\\[", "", line)
      sub("\\].*$", "", line)
      n = split(line, items, ",")
      for (i = 1; i <= n; i += 1) { print trim(items[i]) }
    }
  ' "$SM_YAML"
}

# Normalize a stage input to its canonical name; unknown input echoes back.
# Empty input echoes an empty line and exits 0 (legacy `case *)` semantics).
sm_normalize_stage() {
  local input
  input="$(printf '%s' "${1:-}" | tr '[:upper:]' '[:lower:]')"
  if [ -z "$input" ]; then
    printf '\n'
    return 0
  fi
  local canonical
  canonical="$(_sm_simple_map stage_aliases "$input")"
  printf '%s\n' "${canonical:-$input}"
}

# Return 0 when the value is a canonical loop stage.
sm_is_stage() {
  local value="$1"
  local stage
  for stage in $(_sm_list canonical_stages); do
    [ "$stage" = "$value" ] && return 0
  done
  return 1
}

# Return 0 when the value is a canonical decision stage.
sm_is_decision_stage() {
  local value="$1"
  local stage
  for stage in $(_sm_list decision_stages); do
    [ "$stage" = "$value" ] && return 0
  done
  return 1
}

# loop stage → decision stage; empty when unknown. Input is normalized first
# (mirrors the legacy router behavior).
sm_loop_to_decision() {
  local normalized
  normalized="$(sm_normalize_stage "${1:-}")"
  _sm_simple_map stage_to_decision "$normalized"
}

# decision stage → representative loop stage; empty when unknown.
sm_decision_to_loop() {
  _sm_simple_map decision_to_stage "${1:-}"
}

# delivery_level → tier (L1/L2/L3); "unknown" when unknown.
sm_delivery_tier() {
  local tier
  tier="$(_sm_simple_map delivery_tiers "${1:-}")"
  printf '%s\n' "${tier:-unknown}"
}

# delivery_level → rank (1/2/3); 0 when unknown.
sm_delivery_rank() {
  local tier
  tier="$(sm_delivery_tier "${1:-}")"
  case "$tier" in
    L1) printf '1\n' ;;
    L2) printf '2\n' ;;
    L3) printf '3\n' ;;
    *) printf '0\n' ;;
  esac
}

# gate result value → kind: pass / pass_with_risk / fail / blocked / na / missing
sm_gate_result_kind() {
  local kind
  kind="$(_sm_simple_map gate_result_kinds "${1:-}")"
  printf '%s\n' "${kind:-missing}"
}

# ADVANCE / RETURN transition check: action + from + to.
sm_transition_allowed() {
  local action="${1:-}"
  local from="${2:-}"
  local to="${3:-}"
  awk -v action="$action" -v from="$from" -v to="$to" '
    function trim(s) { gsub(/^[[:space:]]+|[[:space:]]+$/, "", s); return s }
    $0 == "transitions:" { in_section = 1; next }
    in_section && /^[^[:space:]]/ && $0 != "transitions:" { exit }
    in_section && $0 ~ /^[[:space:]]*- action:/ {
      cur_action = $0
      sub(/^[[:space:]]*- action:[[:space:]]*/, "", cur_action)
      cur_action = trim(cur_action)
    }
    in_section && $0 ~ /^[[:space:]]*from:/ {
      cur_from = $0
      sub(/^[[:space:]]*from:[[:space:]]*/, "", cur_from)
      cur_from = trim(cur_from)
    }
    in_section && $0 ~ /^[[:space:]]*to: *\[/ {
      line = $0
      sub(/^[[:space:]]*to:[[:space:]]*\[/, "", line)
      sub(/\].*$/, "", line)
      n = split(line, items, ",")
      for (i = 1; i <= n; i += 1) {
        item = trim(items[i])
        if (cur_action == action && cur_from == from && item == to) { found = 1 }
      }
    }
    END { print (found ? "yes" : "no") }
  ' "$SM_YAML"
}

# Required gate names (logical) for a delivery level.
sm_required_gates() {
  local level="${1:-}"
  awk -v level="$level" '
    function trim(s) { gsub(/^[[:space:]]+|[[:space:]]+$/, "", s); return s }
    $0 == "required_gates:" { in_section = 1; next }
    in_section && /^[^[:space:]]/ && $0 != "required_gates:" { exit }
    in_section && $0 ~ "^[[:space:]]*" level ": *\\[" {
      line = $0
      sub("^[[:space:]]*" level ": *\\[", "", line)
      sub("\\].*$", "", line)
      n = split(line, items, ",")
      for (i = 1; i <= n; i += 1) { print trim(items[i]) }
    }
  ' "$SM_YAML"
}

# Default next stage for a raw (possibly non-canonical) status.
# Args: status delivery_level alignment_status type_real_env commit_required
sm_default_next() {
  local status="${1:-}"
  local delivery="${2:-}"
  local alignment="${3:-}"
  local real_env="${4:-}"
  local commit="${5:-}"
  local next
  next="$(
  awk -v status="$status" -v delivery="$delivery" -v alignment="$alignment" \
    -v real_env="$real_env" -v commit="$commit" '
    function trim(s) { gsub(/^[[:space:]]+|[[:space:]]+$/, "", s); return s }
    function match_conditions(  i, j, field, found) {
      for (i = 1; i <= ncond; i += 1) {
        field = cond_key[i]
        found = 0
        for (j = 1; j <= cond_n[i]; j += 1) {
          if (field == "delivery_level" && cond_vals[i, j] == delivery) found = 1
          else if (field == "alignment_status" && cond_vals[i, j] == alignment) found = 1
          else if (field == "type_real_env" && cond_vals[i, j] == real_env) found = 1
          else if (field == "commit_required" && cond_vals[i, j] == commit) found = 1
        }
        if (!found) return 0
      }
      return 1
    }
    $0 == "default_next:" { in_section = 1; next }
    in_section && /^[^[:space:]]/ && $0 != "default_next:" { exit }
    in_section && $0 ~ /^[[:space:]]*- status:/ {
      cur_status = $0
      sub(/^[[:space:]]*- status:[[:space:]]*/, "", cur_status)
      cur_status = trim(cur_status)
      ncond = 0
      cur_next = ""
    }
    in_section && cur_status != "" && $0 ~ /^[[:space:]]*[a-z_]+: *\[/ {
      key = $0
      sub(/^[[:space:]]*/, "", key)
      sub(/:.*$/, "", key)
      vals = $0
      sub(/^[[:space:]]*[a-z_]+:[[:space:]]*\[/, "", vals)
      sub(/\].*$/, "", vals)
      ncond += 1
      cond_key[ncond] = key
      count = split(vals, arr, ",")
      cond_n[ncond] = count
      for (i = 1; i <= count; i += 1) { cond_vals[ncond, i] = trim(arr[i]) }
    }
    in_section && cur_status != "" && $0 ~ /^[[:space:]]*next:/ {
      cur_next = $0
      sub(/^[[:space:]]*next:[[:space:]]*/, "", cur_next)
      cur_next = trim(cur_next)
      if (cur_status == status && match_conditions()) {
        print cur_next
        exit
      }
    }
  ' "$SM_YAML"
  )"
  # Fallback mirrors the legacy default_next_stage `*) echo "analyze"` branch.
  printf '%s\n' "${next:-analyze}"
}

# Vocabulary membership checks (used by task card schema validation).
sm_is_valid_action() { _sm_vocabulary_contains decision_actions "${1:-}"; }
sm_is_valid_gate_result() { _sm_vocabulary_contains gate_results "${1:-}"; }
sm_is_valid_delivery_level() { _sm_vocabulary_contains delivery_levels "${1:-}"; }
sm_is_valid_self_test_level() { _sm_vocabulary_contains self_test_levels "${1:-}"; }
sm_is_valid_task_type() { _sm_vocabulary_contains task_types "${1:-}"; }
sm_is_valid_priority() { _sm_vocabulary_contains priorities "${1:-}"; }

_sm_vocabulary_contains() {
  local list_name="$1"
  local value="$2"
  [ -n "$value" ] || return 1
  local item
  for item in $(_sm_vocabulary "$list_name"); do
    [ "$item" = "$value" ] && return 0
  done
  return 1
}
