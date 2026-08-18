#!/usr/bin/env bash
set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WORKFLOW_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
LOADER="${WORKFLOW_ROOT}/core/loader/ai_workflow_loader_v2.sh"
PROJECT_ROOT=""
ROLE_ID="developer"
HOST_ID=""
AGENT_ID=""
TASK_FILE=""

usage() {
  cat <<'EOF'
Usage:
  ai-workflow assemble --project-root <path> [--host <id>] [--role <id>] <agent-id> <task-file>
EOF
}

loader_command() {
  local loader_args=(--project-root "$PROJECT_ROOT" --role "$ROLE_ID")
  if [ -n "$HOST_ID" ]; then
    loader_args+=(--host "$HOST_ID")
  fi
  "$LOADER" "${loader_args[@]}" "$@"
}

read_frontmatter_scalar() {
  local key="$1"
  awk -F':[[:space:]]*' -v key="$key" '
    $0 == "---" { fence += 1; next }
    fence == 1 && $1 == key {
      value = $0
      sub(/^[^:]+:[[:space:]]*/, "", value)
      gsub(/^['\''"]|['\''"]$/, "", value)
      print value
      exit
    }
  ' "$TASK_FILE"
}

read_required_context() {
  awk '
    $0 == "---" { fence += 1; if (fence == 2) exit; next }
    fence != 1 { next }
    /^required_context:[[:space:]]*/ {
      value = $0
      sub(/^required_context:[[:space:]]*/, "", value)
      if (value ~ /^\[/) {
        sub(/^\[[[:space:]]*/, "", value)
        sub(/[[:space:]]*\]$/, "", value)
        count = split(value, items, ",")
        for (i = 1; i <= count; i += 1) {
          gsub(/^[[:space:]'\''"]+|[[:space:]'\''"]+$/, "", items[i])
          if (items[i] != "") print items[i]
        }
        exit
      }
      capture = 1
      next
    }
    capture && /^[[:space:]]+-[[:space:]]+/ {
      value = $0
      sub(/^[[:space:]]+-[[:space:]]+/, "", value)
      gsub(/^[[:space:]'\''"]+|[[:space:]'\''"]+$/, "", value)
      if (value != "") print value
      next
    }
    capture { exit }
  ' "$TASK_FILE"
}

knowledge_file_count() {
  local root="$1"
  find "$root" -type f ! -name '.gitkeep' -print 2>/dev/null |
    wc -l | tr -d ' '
}

emit_project_knowledge_index() {
  local knowledge_area knowledge_root count
  printf '\n%s\n\n' "## Project Local Knowledge Index"
  for knowledge_area in architecture risks defects policies; do
    knowledge_root="${PROJECT_ROOT}/.ai/${knowledge_area}"
    count="$(knowledge_file_count "$knowledge_root")"
    printf -- '- .ai/%s/: %s file(s)\n' "$knowledge_area" "$count"
  done
  printf '%s\n' "Use repository search to identify exact relevant files; the index does not inline their contents."
}

emit_selected_project_context() {
  local request context_file defect_count=0 loaded_count=0
  printf '\n%s\n\n' "## Selected Project Local Knowledge"

  if [ "$ASSEMBLY_BUDGET" = "L1" ]; then
    printf '%s\n' "(none: L1 keeps project knowledge bodies out of the assembled context)"
    return
  fi

  while IFS= read -r request; do
    [ -n "$request" ] || continue
    case "$request" in
      project.profile|project.knowledge.index|runtime.task)
        continue
        ;;
      .ai/architecture/*|.ai/risks/*|.ai/defects/*|.ai/policies/*)
        ;;
      *)
        continue
        ;;
    esac
    case "/${request}/" in
      *'/../'*|*'/./'*|*'//'*)
        printf -- '- rejected unsafe context path: %s\n' "$request"
        continue
        ;;
    esac
    context_file="${PROJECT_ROOT}/${request}"
    [ -f "$context_file" ] || {
      printf -- '- requested context missing: %s\n' "$request"
      continue
    }
    case "$request" in
      .ai/defects/*)
        if [ "$defect_count" -ge 5 ]; then
          continue
        fi
        defect_count=$((defect_count + 1))
        ;;
    esac
    loaded_count=$((loaded_count + 1))
    printf '%s\n\n' "### ${request}"
    sed -n '1,$p' "$context_file"
    printf '\n'
  done < <(read_required_context)

  if [ "$loaded_count" -eq 0 ]; then
    printf '%s\n' "(none selected by Router required_context)"
  fi
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --project-root)
      [ "$#" -ge 2 ] || { usage >&2; exit 2; }
      PROJECT_ROOT="$2"
      shift 2
      ;;
    --role)
      [ "$#" -ge 2 ] || { usage >&2; exit 2; }
      ROLE_ID="$2"
      shift 2
      ;;
    --host)
      [ "$#" -ge 2 ] || { usage >&2; exit 2; }
      HOST_ID="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      if [ -z "$AGENT_ID" ]; then
        AGENT_ID="$1"
      elif [ -z "$TASK_FILE" ]; then
        TASK_FILE="$1"
      else
        printf 'ERROR unexpected argument: %s\n' "$1" >&2
        exit 2
      fi
      shift
      ;;
  esac
done

[ -n "$PROJECT_ROOT" ] && [ -n "$AGENT_ID" ] && [ -n "$TASK_FILE" ] || {
  usage >&2
  exit 2
}
[ -f "$TASK_FILE" ] || { printf '%s\n' "ERROR task file not found" >&2; exit 1; }

loader_command validate >/dev/null

AGENT_FILE="$(loader_command resolve "core.agent.${AGENT_ID}")"
HOST_INSTRUCTIONS="$(loader_command resolve host.instructions)"
ROLE_PROFILE="$(loader_command resolve role.profile)"
PROJECT_PROFILE="$(loader_command resolve project.profile)"

ASSEMBLY_BUDGET="$(read_frontmatter_scalar context_budget)"
if [ "$AGENT_ID" = "router" ]; then
  ASSEMBLY_BUDGET="L1"
else
  case "$ASSEMBLY_BUDGET" in
    L1|L2|L3) ;;
    *)
      case "$(read_frontmatter_scalar delivery_level)" in
        micro_change|light_feature) ASSEMBLY_BUDGET="L1" ;;
        high_risk_delivery) ASSEMBLY_BUDGET="L3" ;;
        *) ASSEMBLY_BUDGET="L2" ;;
      esac
      ;;
  esac
fi

printf '%s\n\n' "# Resolved Agent Context"
printf '%s\n\n' "## Core Agent"
sed -n '1,$p' "$AGENT_FILE"

printf '\n%s\n\n' "## Company Policy"
case "$AGENT_ID" in
  commit) company_keys=(commit) ;;
  pr_review) company_keys=(review) ;;
  coding|self_test|architecture_boundary|i18n_text_ui_risk) company_keys=(delivery security) ;;
  *) company_keys=(commit review security delivery) ;;
esac
for company_key in "${company_keys[@]}"; do
  company_file="$(loader_command resolve "company.${company_key}")"
  printf '%s\n\n' "### ${company_key}"
  sed -n '1,$p' "$company_file"
  printf '\n'
done

printf '%s\n\n' "## Role"
sed -n '1,$p' "$ROLE_PROFILE"
printf '\n%s\n\n' "## Host Instructions"
sed -n '1,$p' "$HOST_INSTRUCTIONS"
printf '\n%s\n\n' "## Generated Project Profile"
sed -n '1,$p' "$PROJECT_PROFILE"
printf '\n%s\n' "Context budget: ${ASSEMBLY_BUDGET}"
emit_project_knowledge_index
emit_selected_project_context

printf '\n%s\n\n' "## Current Task"
sed -n '1,$p' "$TASK_FILE"
