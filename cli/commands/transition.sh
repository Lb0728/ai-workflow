#!/usr/bin/env bash
set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WORKFLOW_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
# Stage / transition tables are owned by core/config/state-machine.yaml.
source "${WORKFLOW_ROOT}/core/lib/state_machine.sh"
source "${WORKFLOW_ROOT}/core/lib/task_card.sh"
PROJECT_ROOT="$(pwd)"
# HOST_ID is part of the CLI contract (--host accepted for symmetry) but
# transition resolves everything from the project root (the per-line SC2034 directive sits on the --host case).
HOST_ID=""
DRY_RUN=false
TASK_INPUT=""

usage() {
  printf '%s\n' "Usage: ai-workflow transition [--dry-run] [--project-root <path>] [--host <id>] <task-file>"
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --project-root) PROJECT_ROOT="$2"; shift 2 ;;
    --host)
      # shellcheck disable=SC2034
      HOST_ID="$2"
      shift 2
      ;;
    --dry-run) DRY_RUN=true; shift ;;
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

front() { awk -F': *' -v k="$1" '$0=="---"{n++;next} n==1 && $1==k{print $2;exit}' "$TASK_FILE" | tr -d "'\""; }
section() { awk -v h="$1" -v k="$2" 'index($0, "## " h) == 1 && length($0) == length("## " h) {on=1;next} on && /^## /{exit} on && $0 ~ "^- " k "[：:]" {sub("^- " k "[：:][[:space:]]*", ""); print; exit}' "$TASK_FILE"; }
# to_loop / to_decision / allowed are provided by core/lib/state_machine.sh:
#   to_loop    -> sm_decision_to_loop
#   to_decision -> sm_loop_to_decision
#   allowed    -> sm_transition_allowed

status="$(front status)"; action="$(section '下一步决策' '动作' | tr '[:lower:]' '[:upper:]')"; current="$(section '下一步决策' '当前阶段' | tr '[:upper:]' '[:lower:]')"; target="$(section '下一步决策' '目标阶段' | tr '[:upper:]' '[:lower:]')"
static="$(front validation_static | tr '[:lower:]' '[:upper:]')"; runtime="$(front validation_runtime | tr '[:lower:]' '[:upper:]')"; acceptance="$(front validation_acceptance | tr '[:lower:]' '[:upper:]')"
[ -n "$static" ] || static=NOT_RUN; [ -n "$runtime" ] || runtime=NOT_RUN; [ -n "$acceptance" ] || acceptance=NOT_RUN
schema_violations="$(tc_validate "$TASK_FILE")" || {
  printf '%s\n' 'ERROR 任务卡 Schema 校验失败：' >&2
  printf '%s\n' "$schema_violations" >&2
  exit 1
}
[ -n "$action" ] && [ -n "$current" ] && [ -n "$target" ] || { printf '%s\n' 'ERROR transition requires 下一步决策: 当前阶段, 动作, 目标阶段' >&2; exit 1; }
[ "$current" = "$(sm_loop_to_decision "$status")" ] || { printf 'ERROR transition current stage %s does not match status %s\n' "$current" "$status" >&2; exit 1; }
case "$action" in STAY) [ "$target" = "$current" ] || { echo 'ERROR STAY target must equal current' >&2; exit 1; };; STOP) [ "$target" = human ] || { echo 'ERROR STOP target must be human' >&2; exit 1; };; COMPLETE) [ "$current" = pr_review ] && [ "$target" = loop_closeout ] || { echo 'ERROR COMPLETE only permits pr_review -> loop_closeout' >&2; exit 1; }; [ "$static" = PASS ] && [ "$runtime" = PASS ] && [ "$acceptance" = PASS ] || { echo 'ERROR COMPLETE requires validation_static/runtime/acceptance all PASS' >&2; exit 1; };; ADVANCE|RETURN) [ "$(sm_transition_allowed "$action" "$current" "$target")" = yes ] || { echo 'ERROR illegal transition' >&2; exit 1; };; ESCALATE) [ "$target" = bugfix_diagnosis ] || [ "$target" = arch_boundary ] || { echo 'ERROR ESCALATE target invalid' >&2; exit 1; };; *) echo 'ERROR unsupported transition action' >&2; exit 1;; esac
if [ "$action" = ADVANCE ] && [ "$target" = pr_review ] && { [ "$static" != PASS ] || [ "$runtime" != PASS ]; }; then echo 'ERROR ADVANCE to pr_review requires validation_static and validation_runtime PASS' >&2; exit 1; fi
next="$(sm_decision_to_loop "$target")"; [ -n "$next" ] || { echo 'ERROR target stage invalid' >&2; exit 1; }
if [ "$DRY_RUN" = true ]; then printf 'Transition: VALID %s -> %s\n' "$status" "$next"; exit 0; fi
tmp="${TASK_FILE}.transition.$$"
awk -v target_status="$next" -v complete="$([ "$action" = COMPLETE ] && printf true || printf false)" '
  $0=="---" {n++; print; next}
  n==1 && $1=="status:" {print "status: " target_status; next}
  n==1 && $1=="fix_status:" && complete=="true" {print "fix_status: fixed"; next}
  {print}
' "$TASK_FILE" > "$tmp"
mv "$tmp" "$TASK_FILE"
printf 'Transition: APPLIED %s -> %s (static=%s runtime=%s acceptance=%s)\n' "$status" "$next" "$static" "$runtime" "$acceptance"
