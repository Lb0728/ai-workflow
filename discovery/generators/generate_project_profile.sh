#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DISCOVERY_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
PROJECT_ROOT=""
OUTPUT=""

usage() {
  printf '%s\n' "Usage: generate_project_profile.sh --project-root <path> --output <file>"
}

yaml_quote() {
  local value="$1"
  value="${value//\'/\'\'}"
  printf "'%s'" "$value"
}

yaml_inline_array() {
  local first=true item
  printf '['
  for item in "$@"; do
    if [ "$first" = false ]; then
      printf ', '
    fi
    first=false
    yaml_quote "$item"
  done
  printf ']'
}

existing_relative_paths() {
  local candidate
  for candidate in "$@"; do
    if [ -e "${PROJECT_ROOT}/${candidate}" ]; then
      printf '%s\n' "$candidate"
    fi
  done
}

knowledge_status() {
  local knowledge_root="$1"
  if [ -d "$knowledge_root" ] &&
    find "$knowledge_root" -type f ! -name '.gitkeep' -print -quit | grep -q .; then
    printf '%s\n' "present"
  else
    printf '%s\n' "missing"
  fi
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --project-root)
      [ "$#" -ge 2 ] || { usage >&2; exit 2; }
      PROJECT_ROOT="$2"
      shift 2
      ;;
    --output)
      [ "$#" -ge 2 ] || { usage >&2; exit 2; }
      OUTPUT="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      printf 'ERROR unknown argument: %s\n' "$1" >&2
      exit 2
      ;;
  esac
done

[ -n "$PROJECT_ROOT" ] && [ -n "$OUTPUT" ] || { usage >&2; exit 2; }
[ -d "$PROJECT_ROOT" ] || { printf '%s\n' "ERROR project root not found" >&2; exit 1; }
PROJECT_ROOT="$(cd "$PROJECT_ROOT" && pwd)"

project_kind="$("${DISCOVERY_ROOT}/detectors/detect_project.sh" --project-root "$PROJECT_ROOT")"
project_name="$(basename "$PROJECT_ROOT")"

languages=()
frameworks=()
source_candidates=()
test_candidates=()
docs_candidates=(docs doc)
platform_candidates=()
build_command=()
static_command=()
test_command=()
zephyr_status=""
zephyr_build_dir=""
zephyr_board=""
zephyr_application=""
zephyr_evidence=()

case "$project_kind" in
  flutter)
    languages=(Dart)
    frameworks=(Flutter)
    source_candidates=(lib)
    test_candidates=(test integration_test)
    platform_candidates=(android ios web macos linux windows)
    static_command=(flutter analyze)
    test_command=(flutter test)
    ;;
  dart)
    languages=(Dart)
    frameworks=()
    source_candidates=(lib bin)
    test_candidates=(test)
    static_command=(dart analyze)
    test_command=(dart test)
    ;;
  go)
    languages=(Go)
    frameworks=()
    source_candidates=(cmd internal pkg)
    test_candidates=(test tests)
    build_command=(go build ./...)
    static_command=(go vet ./...)
    test_command=(go test ./...)
    ;;
  zephyr)
    languages=(C C++)
    frameworks=(Zephyr)
    source_candidates=(src include app boards)
    test_candidates=(test tests)
    while IFS= read -r discovery_line; do
      case "$discovery_line" in
        status=*) zephyr_status="${discovery_line#status=}" ;;
        build_dir=*) zephyr_build_dir="${discovery_line#build_dir=}" ;;
        board=*) zephyr_board="${discovery_line#board=}" ;;
        application=*) zephyr_application="${discovery_line#application=}" ;;
        evidence=*) zephyr_evidence+=("${discovery_line#evidence=}") ;;
      esac
    done < <(
      "${DISCOVERY_ROOT}/generators/discover_zephyr_build.sh" \
        --project-root "$PROJECT_ROOT"
    )
    if [ -n "$zephyr_build_dir" ]; then
      build_command=(west build -d "$zephyr_build_dir")
    elif [ "$zephyr_status" = "confirmed" ]; then
      build_command=(west build -b "$zephyr_board" "$zephyr_application")
    fi
    ;;
  *)
    languages=()
    frameworks=()
    source_candidates=(src lib app)
    test_candidates=(test tests)
    ;;
esac

source_paths=()
while IFS= read -r discovered_path; do
  [ -n "$discovered_path" ] && source_paths+=("$discovered_path")
done < <(existing_relative_paths "${source_candidates[@]}")

test_paths=()
while IFS= read -r discovered_path; do
  [ -n "$discovered_path" ] && test_paths+=("$discovered_path")
done < <(existing_relative_paths "${test_candidates[@]}")

docs_paths=()
while IFS= read -r discovered_path; do
  [ -n "$discovered_path" ] && docs_paths+=("$discovered_path")
done < <(existing_relative_paths "${docs_candidates[@]}")

platform_paths=()
while IFS= read -r discovered_path; do
  [ -n "$discovered_path" ] && platform_paths+=("$discovered_path")
done < <(existing_relative_paths "${platform_candidates[@]}")

existing_ai=()
[ -f "${PROJECT_ROOT}/AGENTS.md" ] && existing_ai+=(AGENTS.md)
[ -f "${PROJECT_ROOT}/CLAUDE.md" ] && existing_ai+=(CLAUDE.md)
[ -d "${PROJECT_ROOT}/.cursor/rules" ] && existing_ai+=(.cursor/rules)
[ -d "${PROJECT_ROOT}/.ai" ] && existing_ai+=(.ai)

architecture_docs=()
while IFS= read -r architecture_file; do
  [ -n "$architecture_file" ] || continue
  architecture_docs+=("${architecture_file#"${PROJECT_ROOT}/"}")
done < <(
  find "$PROJECT_ROOT" -maxdepth 3 -type f \
    \( -iname '*architecture*.md' -o -iname 'adr*.md' -o -iname '*architecture*.yaml' \) \
    ! -path "${PROJECT_ROOT}/.git/*" ! -path "${PROJECT_ROOT}/.ai/*" \
    -print 2>/dev/null | LC_ALL=C sort
)

output_parent="$(dirname "$OUTPUT")"
mkdir -p "$output_parent"
temp_output="${OUTPUT}.tmp.$$"

{
  printf '%s\n' "schema_version: 1"
  printf '%s\n' "profile:"
  printf '%s\n' "  version: 1"
  printf '%s\n' "  generated: true"
  printf '%s\n' "  evidence_only: true"
  printf '%s\n' "project:"
  printf '  name: '; yaml_quote "$project_name"; printf '\n'
  printf '%s\n' "  git_root: '.'"
  printf '  detected_kind: '; yaml_quote "$project_kind"; printf '\n'
  printf '%s\n' "stack:"
  printf '  languages: '; yaml_inline_array "${languages[@]}"; printf '\n'
  printf '  frameworks: '; yaml_inline_array "${frameworks[@]}"; printf '\n'
  printf '%s\n' "paths:"
  printf '  source: '; yaml_inline_array "${source_paths[@]}"; printf '\n'
  printf '  tests: '; yaml_inline_array "${test_paths[@]}"; printf '\n'
  printf '  docs: '; yaml_inline_array "${docs_paths[@]}"; printf '\n'
  printf '  platforms: '; yaml_inline_array "${platform_paths[@]}"; printf '\n'
  printf '%s\n' "commands:"
  printf '  build: '; yaml_inline_array "${build_command[@]}"; printf '\n'
  printf '  static_check: '; yaml_inline_array "${static_command[@]}"; printf '\n'
  printf '  test: '; yaml_inline_array "${test_command[@]}"; printf '\n'
  if [ "$project_kind" = "zephyr" ]; then
    printf '%s\n' "zephyr:"
    printf '  discovery_status: '; yaml_quote "$zephyr_status"; printf '\n'
    printf '  evidence: '; yaml_inline_array "${zephyr_evidence[@]}"; printf '\n'
    printf '%s\n' "  build:"
    printf '    directory: '; yaml_quote "${zephyr_build_dir:-unknown}"; printf '\n'
    printf '    board: '; yaml_quote "${zephyr_board:-unknown}"; printf '\n'
    printf '    application: '; yaml_quote "${zephyr_application:-unknown}"; printf '\n'
    printf '%s\n' "  safety:"
    printf '%s\n' "    flash: forbidden"
    printf '%s\n' "    debug: forbidden"
    printf '%s\n' "    device_validation: manual"
  fi
  printf '%s\n' "ai:"
  printf '  existing_configuration: '; yaml_inline_array "${existing_ai[@]}"; printf '\n'
  printf '%s\n' "knowledge:"
  if [ "${#architecture_docs[@]}" -gt 0 ]; then
    printf '%s\n' "  architecture:"
    printf '%s\n' "    status: present"
    printf '    sources: '; yaml_inline_array "${architecture_docs[@]}"; printf '\n'
  else
    printf '%s\n' "  architecture:"
    printf '%s\n' "    status: missing"
    printf '%s\n' "    sources: []"
  fi
  printf '%s\n' "  risks:"
  printf '    status: %s\n' "$(knowledge_status "${PROJECT_ROOT}/.ai/risks")"
  printf '%s\n' "  defects:"
  printf '    status: %s\n' "$(knowledge_status "${PROJECT_ROOT}/.ai/defects")"
  printf '%s\n' "  business_rules:"
  printf '%s\n' "    status: unknown"
} > "$temp_output"

mv "$temp_output" "$OUTPUT"
