#!/usr/bin/env bash

ai_select_profile_id() {
  local root="$1"
  local requested="$2"
  local label="$3"
  local candidate=""
  local selected=""
  local count=0

  if [ -n "$requested" ]; then
    printf '%s\n' "$requested"
    return 0
  fi

  for candidate in "$root"/*; do
    if [ -d "$candidate" ]; then
      selected="$(basename "$candidate")"
      count=$((count + 1))
    fi
  done

  if [ "$count" -eq 1 ]; then
    printf '%s\n' "$selected"
    return 0
  fi

  printf 'ERROR %s must be selected explicitly; found %d candidates under %s\n' "$label" "$count" "$root" >&2
  return 2
}

ai_adapter_matches_project() {
  local profile="$1"
  local project_root="$2"
  local marker=""
  local marker_count=0

  if [ ! -f "$profile" ] || [ ! -d "$project_root" ]; then
    return 1
  fi

  while IFS= read -r marker; do
    if [ -z "$marker" ]; then
      continue
    fi
    marker_count=$((marker_count + 1))
    if [ ! -e "${project_root}/${marker}" ] && [ ! -L "${project_root}/${marker}" ]; then
      return 1
    fi
  done <<EOF
$(awk '
  /^detection:$/ { in_detection = 1; next }
  in_detection && /^[^[:space:]]/ { exit }
  in_detection && /^  required_paths:$/ { in_paths = 1; next }
  in_paths && /^    - / {
    value = $0
    sub(/^    - /, "", value)
    gsub(/^"|"$/, "", value)
    print value
    next
  }
  in_paths && !/^    - / { exit }
' "$profile")
EOF

  [ "$marker_count" -gt 0 ]
}

ai_select_project_adapter_id() {
  local root="$1"
  local requested="$2"
  local project_root="$3"
  local candidate=""
  local selected=""
  local match_count=0

  if [ -n "$requested" ]; then
    printf '%s\n' "$requested"
    return 0
  fi

  for candidate in "$root"/*; do
    if [ ! -d "$candidate" ]; then
      continue
    fi
    if ai_adapter_matches_project "${candidate}/project-profile.yaml" "$project_root"; then
      selected="$(basename "$candidate")"
      match_count=$((match_count + 1))
    fi
  done

  if [ "$match_count" -eq 1 ]; then
    printf '%s\n' "$selected"
    return 0
  fi

  if [ "$match_count" -eq 0 ]; then
    ai_select_profile_id "$root" "" "Project Adapter"
    return $?
  fi

  printf 'ERROR Project Adapter detection is ambiguous; matched %d candidates for %s\n' "$match_count" "$project_root" >&2
  return 2
}
