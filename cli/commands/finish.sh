#!/usr/bin/env bash
# shellcheck disable=SC1111,SC1112  # Chinese curly quotes “” are intentional message text
set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WORKFLOW_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
# Stage normalization is owned by core/config/state-machine.yaml.
source "${WORKFLOW_ROOT}/core/lib/state_machine.sh"
PROJECT_ROOT="$(pwd)"
# HOST_ID is part of the CLI contract (accepted for symmetry with other
# commands) but finish does not need it (the per-line SC2034 directive sits on the --host case).
HOST_ID=""
TASK_INPUT=""

usage() {
  printf '%s\n' "Usage: ai-workflow finish [--project-root <path>] [--host <id>] <task-file>"
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --project-root) [ "$#" -ge 2 ] || { usage >&2; exit 2; }; PROJECT_ROOT="$2"; shift 2 ;;
    --host)
      if [ "$#" -lt 2 ]; then
        usage >&2
        exit 2
      fi
      # shellcheck disable=SC2034
      HOST_ID="$2"
      shift 2
      ;;
    -h|--help) usage; exit 0 ;;
    *) [ -z "$TASK_INPUT" ] || { usage >&2; exit 2; }; TASK_INPUT="$1"; shift ;;
  esac
done

[ -n "$TASK_INPUT" ] || { usage >&2; exit 2; }
PROJECT_ROOT="$(cd "$PROJECT_ROOT" && pwd)"

if [ -f "$TASK_INPUT" ]; then
  TASK_FILE="$(cd "$(dirname "$TASK_INPUT")" && pwd)/$(basename "$TASK_INPUT")"
elif [ -f "${PROJECT_ROOT}/.ai/runtime/tasks/${TASK_INPUT}" ]; then
  TASK_FILE="${PROJECT_ROOT}/.ai/runtime/tasks/${TASK_INPUT}"
else
  printf 'ERROR task file not found: %s\n' "$TASK_INPUT" >&2
  exit 1
fi

front() {
  awk -F': *' -v k="$1" '$0=="---"{n++;next} n==1 && $1==k{print $2;exit}' "$TASK_FILE" | tr -d "'\""
}

section() {
  awk -v h="$1" -v k="$2" '
    index($0, "## " h) == 1 && length($0) == length("## " h) {on=1;next}
    on && /^## / {exit}
    on && $0 ~ "^- " k "[：:]" {
      sub("^- " k "[：:][[:space:]]*", "", $0)
      print
      exit
    }
  ' "$TASK_FILE"
}

section_content() {
  awk -v h="$1" '
    index($0, "## " h) == 1 && length($0) == length("## " h) {on=1;next}
    on && /^## / {exit}
    on {print}
  ' "$2"
}

STATUS="$(front status | tr '[:upper:]' '[:lower:]')"
DONE_VALUE="$(section "Loop Closeout" "是否 Done")"
NEXT_ACTION="$(section "Loop Closeout" "唯一下一步")"
NEXT_STAGE="$(section "Loop Closeout" "下一阶段" | tr '[:upper:]' '[:lower:]')"
ITERATION="$(front iteration)"
MAX_ITERATIONS="$(front max_iterations)"

case "$ITERATION" in ''|*[!0-9]*) ITERATION=0;; esac
case "$MAX_ITERATIONS" in ''|*[!0-9]*) MAX_ITERATIONS=2;; esac

[ -n "$DONE_VALUE" ] || { printf '%s\n' "ERROR Loop Closeout 缺少“是否 Done”" >&2; exit 1; }
[ -n "$NEXT_ACTION" ] || { printf '%s\n' "ERROR Loop Closeout 缺少“唯一下一步”" >&2; exit 1; }

if [ "$DONE_VALUE" = "是" ]; then
  TARGET="done"
  if [ "$NEXT_ACTION" != "无" ]; then
    printf '%s\n' "ERROR 已标记 Done 时，唯一下一步必须为“无”" >&2
    exit 1
  fi
else
  [ -n "$NEXT_STAGE" ] || { printf '%s\n' "ERROR 未 Done 时，Loop Closeout 必须填写“下一阶段”" >&2; exit 1; }
  TARGET="$(sm_normalize_stage "$NEXT_STAGE")"
  sm_is_stage "$TARGET" || { printf 'ERROR invalid next stage: %s\n' "$NEXT_STAGE" >&2; exit 1; }
fi

# --- P4 quality gate: entering ready_for_qa requires real evidence -------
if [ "$TARGET" = "ready_for_qa" ]; then
  quality_errors=()
  traffic_light="$(section_content "Self Test 红绿灯" "$TASK_FILE")"
  if [ -z "$traffic_light" ]; then
    quality_errors+=("缺少 Self Test 红绿灯证据")
  fi
  has_evidence=false
  for evidence_section in "证据记录" "Bugfix 自测证据" "Self Test Result"; do
    content="$(section_content "$evidence_section" "$TASK_FILE")"
    if [ -n "$content" ]; then
      substantive="$(printf '%s\n' "$content" | awk -F'[：:]' '
        /^-/ {
          value = $2
          gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
          if (value != "" && value !~ /^(待填写|待补充|未知|unknown|n\/a|pending|todo|tbd)$/) { print }
        }')"
      if [ -n "$substantive" ]; then
        has_evidence=true
      fi
    fi
  done
  if [ "$has_evidence" != "true" ]; then
    quality_errors+=("缺少真实证据（证据记录 / Bugfix 自测证据 / Self Test Result 均无实质内容）")
  fi
  if [ "${#quality_errors[@]}" -gt 0 ]; then
    printf '%s\n' "ERROR 证据不足，不能进入 READY_FOR_QA：" >&2
    for quality_error in "${quality_errors[@]}"; do
      printf -- "- %s\n" "$quality_error" >&2
    done
    exit 1
  fi
fi

if [ "$TARGET" = "$(sm_normalize_stage "$STATUS")" ]; then
  NEW_ITERATION="$ITERATION"
else
  NEW_ITERATION=$((ITERATION + 1))
fi

TMP="${TASK_FILE}.finish.$$"
awk -v target_status="$TARGET" -v new_iteration="$NEW_ITERATION" -v complete="$([ "$TARGET" = "done" ] && printf true || printf false)" '
  $0=="---" {n++; print; next}
  n==1 && $1=="status:" {print "status: " target_status; next}
  n==1 && $1=="iteration:" {print "iteration: " new_iteration; next}
  n==1 && $1=="fix_status:" && complete=="true" {print "fix_status: fixed"; next}
  {print}
' "$TASK_FILE" > "$TMP"
mv "$TMP" "$TASK_FILE"

printf 'Finish: APPLIED %s -> %s (done=%s)\n' "$STATUS" "$TARGET" "$DONE_VALUE"
