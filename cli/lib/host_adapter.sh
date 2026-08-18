#!/usr/bin/env bash

host_manifest_scalar() {
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

host_lock_id() {
  local lock_file="$1"
  local section="$2"
  awk -v section="$section" '
    $0 == section ":" { in_section = 1; next }
    in_section && /^[^[:space:]]/ { in_section = 0 }
    in_section && /^[[:space:]]+id:[[:space:]]*/ {
      value = $0
      sub(/^[^:]+:[[:space:]]*/, "", value)
      gsub(/^['\''"]|['\''"]$/, "", value)
      print value
      exit
    }
  ' "$lock_file"
}

host_validate_relative_path() {
  local value="$1"
  [ -n "$value" ] || return 1
  case "$value" in
    /*|*'..'*|*'//'*) return 1 ;;
  esac
}

host_resolve_id() {
  local workflow_root="$1"
  local project_root="$2"
  local explicit_host="$3"
  local resolved_host="$explicit_host"
  local lock_file="${project_root}/.ai/ai.lock"

  if [ -z "$resolved_host" ]; then
    [ -f "$lock_file" ] || {
      printf '%s\n' "ERROR Host is required: pass --host <id> or initialize .ai/ai.lock" >&2
      return 1
    }
    resolved_host="$(host_lock_id "$lock_file" host)"
    [ -n "$resolved_host" ] || {
      printf '%s\n' "ERROR Host id missing from .ai/ai.lock" >&2
      return 1
    }
  fi

  case "$resolved_host" in
    *[!A-Za-z0-9._-]*)
      printf 'ERROR invalid Host id: %s\n' "$resolved_host" >&2
      return 1
      ;;
  esac

  local manifest="${workflow_root}/hosts/${resolved_host}/host.yaml"
  [ -f "$manifest" ] || {
    printf 'ERROR Host Adapter not found: %s\n' "$resolved_host" >&2
    return 1
  }

  local manifest_id
  manifest_id="$(host_manifest_scalar "$manifest" host id)"
  [ "$manifest_id" = "$resolved_host" ] || {
    printf 'ERROR Host manifest id mismatch: %s\n' "$resolved_host" >&2
    return 1
  }

  printf '%s\n' "$resolved_host"
}

host_required_scalar() {
  local manifest="$1"
  local section="$2"
  local key="$3"
  local value
  value="$(host_manifest_scalar "$manifest" "$section" "$key")"
  [ -n "$value" ] || {
    printf 'ERROR Host manifest missing %s.%s\n' "$section" "$key" >&2
    return 1
  }
  printf '%s\n' "$value"
}
