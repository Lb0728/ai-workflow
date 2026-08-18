#!/usr/bin/env bash
set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WORKFLOW_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
LOADER="${WORKFLOW_ROOT}/core/loader/ai_workflow_loader_v2.sh"
source "${WORKFLOW_ROOT}/core/lib/task_card.sh"
PROJECT_ROOT="$(pwd)"
HOST_ID=""
ROLE_ID="developer"
POSITIONAL=()

usage() {
  cat <<'EOF'
Usage:
  ai-workflow new [--project-root <path>] [--host <id>] <type> <task-id> [slug] [priority] [delivery_level]

Types:
  bugfix | feature | techdebt | device

Delivery levels:
  micro_change | light_feature | standard_delivery | high_risk_delivery

Examples:
  ai-workflow new bugfix DEMO-1234 typo P2 micro_change
  ai-workflow new feature DEMO-4567 help-support P1 light_feature
  ai-workflow new device DEMO-7890 d2-binding P1 high_risk_delivery
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --project-root)
      [ "$#" -ge 2 ] || { usage >&2; exit 2; }
      PROJECT_ROOT="$2"
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
      POSITIONAL+=("$1")
      shift
      ;;
  esac
done

[ "${#POSITIONAL[@]}" -ge 2 ] || { usage >&2; exit 2; }
[ "${#POSITIONAL[@]}" -le 5 ] || { usage >&2; exit 2; }

TYPE="${POSITIONAL[0]}"
TASK_ID="${POSITIONAL[1]}"
SLUG_INPUT="${POSITIONAL[2]:-}"
ARG4="${POSITIONAL[3]:-}"
ARG5="${POSITIONAL[4]:-}"

PROJECT_ROOT="$(cd "$PROJECT_ROOT" && pwd)"

resolve_input() {
  local loader_args=(--project-root "$PROJECT_ROOT" --role "$ROLE_ID")
  if [ -n "$HOST_ID" ]; then
    loader_args+=(--host "$HOST_ID")
  fi
  "$LOADER" "${loader_args[@]}" resolve "$1"
}

TASKS_DIR="$(resolve_input runtime.tasks)"
TASK_CARD_TEMPLATE="$(resolve_input core.template.task_card)"
FAST_BRIEF_TEMPLATE="$(resolve_input core.template.fast_brief)"
MICRO_TEMPLATE="$(resolve_input core.template.micro_change)"
CORE_TASK_TYPES="$(resolve_input core.task_types)"

find_task_type() {
  local file="$1"
  local input="$2"
  awk -v input="$input" '
    /^  [a-zA-Z0-9_-]+:$/ {
      type = $1
      sub(/:$/, "", type)
      next
    }
    /^    aliases:/ {
      line = $0
      sub(/^    aliases:[[:space:]]*\[/, "", line)
      sub(/\][[:space:]]*$/, "", line)
      count = split(line, values, ",")
      for (i = 1; i <= count; i += 1) {
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", values[i])
        if (values[i] == input) {
          print type
          exit
        }
      }
    }
  ' "$file"
}

task_type_field() {
  local file="$1"
  local type="$2"
  local field="$3"
  awk -v type="$type" -v field="$field" '
    $0 == "  " type ":" { in_type = 1; next }
    in_type && /^  [a-zA-Z0-9_-]+:$/ { exit }
    in_type && $1 == field ":" {
      sub(/^[^:]+:[[:space:]]*/, "", $0)
      gsub(/^"|"$/, "", $0)
      print
      exit
    }
  ' "$file"
}

sanitize() {
  printf '%s\n' "$1" \
    | tr '[:upper:]' '[:lower:]' \
    | sed -E 's/[^a-z0-9._-]+/-/g' \
    | sed -E 's/-+/-/g' \
    | sed -E 's/^-+//' \
    | sed -E 's/-+$//'
}

normalize_delivery_level() {
  case "$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')" in
    micro|tiny|micro_change) echo "micro_change" ;;
    light|lite|quick|fast|fast-track|fast_track|light_feature) echo "light_feature" ;;
    standard|normal|controlled|control|standard_delivery) echo "standard_delivery" ;;
    high|heavy|high-risk|high_risk|high_risk_delivery) echo "high_risk_delivery" ;;
    "") echo "" ;;
    *) echo "UNKNOWN" ;;
  esac
}

normalize_priority() {
  case "$(printf '%s' "$1" | tr '[:lower:]' '[:upper:]')" in
    P0|P1|P2) printf '%s\n' "$(printf '%s' "$1" | tr '[:lower:]' '[:upper:]')" ;;
    "") echo "" ;;
    *) echo "UNKNOWN" ;;
  esac
}

TYPE_INPUT="$(printf '%s' "$TYPE" | tr '[:upper:]' '[:lower:]')"
TYPE="$(find_task_type "$CORE_TASK_TYPES" "$TYPE_INPUT")"
if [ -z "$TYPE" ]; then
  printf 'ERROR unknown task type: %s\n' "$TYPE_INPUT" >&2
  usage >&2
  exit 1
fi

TYPE_DEFAULT_DELIVERY="$(task_type_field "$CORE_TASK_TYPES" "$TYPE" default_delivery_level)"

PRIORITY="$(normalize_priority "$ARG4")"
DELIVERY_LEVEL="$(normalize_delivery_level "$ARG5")"

if [ "$PRIORITY" = "UNKNOWN" ]; then
  PRIORITY=""
  DELIVERY_LEVEL="$(normalize_delivery_level "$ARG4")"
fi

if [ "$DELIVERY_LEVEL" = "UNKNOWN" ]; then
  printf 'ERROR unknown delivery level: %s\n' "${ARG5:-$ARG4}" >&2
  usage >&2
  exit 1
fi

if [ -z "$PRIORITY" ]; then
  PRIORITY="P2"
fi

if [ -z "$DELIVERY_LEVEL" ]; then
  if [ -n "$TYPE_DEFAULT_DELIVERY" ]; then
    DELIVERY_LEVEL="$TYPE_DEFAULT_DELIVERY"
  else
    printf '%s\n' "ERROR delivery_level is required for type ${TYPE}" >&2
    usage >&2
    exit 1
  fi
fi

if [ -n "$TYPE_DEFAULT_DELIVERY" ] && [ "$DELIVERY_LEVEL" != "$TYPE_DEFAULT_DELIVERY" ]; then
  printf 'ERROR %s tasks must use delivery_level %s\n' "$TYPE" "$TYPE_DEFAULT_DELIVERY" >&2
  exit 1
fi

case "$DELIVERY_LEVEL" in
  micro_change)
    TEMPLATE="$MICRO_TEMPLATE"
    DELIVERY_TIER="L1"
    RISK_VALUE="low"
    SELF_TEST_LEVEL="quick"
    ALIGNMENT_REQUIRED="false"
    ALIGNMENT_STATUS="not_required"
    ;;
  light_feature)
    TEMPLATE="$FAST_BRIEF_TEMPLATE"
    DELIVERY_TIER="L1"
    RISK_VALUE="low"
    SELF_TEST_LEVEL="quick"
    ALIGNMENT_REQUIRED="false"
    ALIGNMENT_STATUS="not_required"
    ;;
  standard_delivery)
    TEMPLATE="$TASK_CARD_TEMPLATE"
    DELIVERY_TIER="L2"
    RISK_VALUE="normal"
    SELF_TEST_LEVEL="standard"
    ALIGNMENT_REQUIRED="false"
    ALIGNMENT_STATUS="not_required"
    ;;
  high_risk_delivery)
    TEMPLATE="$TASK_CARD_TEMPLATE"
    DELIVERY_TIER="L3"
    RISK_VALUE="high"
    SELF_TEST_LEVEL="specialized"
    ALIGNMENT_REQUIRED="true"
    ALIGNMENT_STATUS="pending"
    ;;
esac

SAFE_ID="$(sanitize "$TASK_ID")"
if [ -n "$SLUG_INPUT" ]; then
  SAFE_SLUG="$(sanitize "$SLUG_INPUT")"
else
  SAFE_SLUG="$TYPE"
fi

if [ -z "$SAFE_ID" ]; then
  printf 'ERROR invalid task id: %s\n' "$TASK_ID" >&2
  exit 1
fi

if [ "$DELIVERY_LEVEL" = "micro_change" ] && [ "$TYPE" != "bugfix" ]; then
  MODE_VALUE="execute"
  STATUS_VALUE="implement"
else
  MODE_VALUE="plan"
  STATUS_VALUE="analyze"
fi

mkdir -p "$TASKS_DIR"
FILE_BASE="${TASKS_DIR}/${SAFE_ID}-${SAFE_SLUG}"
FILE="${FILE_BASE}.md"

if [ -f "$FILE" ]; then
  index=2
  while [ -f "${FILE_BASE}-${index}.md" ]; do
    index=$((index + 1))
  done
  FILE="${FILE_BASE}-${index}.md"
fi

today="$(date +%Y-%m-%d)"

sed \
  -e "s/^task_id:.*/task_id: ${TASK_ID}/" \
  -e "s/^title:.*/title: ${SAFE_SLUG}/" \
  -e "s/^type:.*/type: ${TYPE}/" \
  -e "s/^priority:.*/priority: ${PRIORITY}/" \
  -e "s/^delivery_level:.*/delivery_level: ${DELIVERY_LEVEL}/" \
  -e "s/^self_test_level:.*/self_test_level: ${SELF_TEST_LEVEL}/" \
  -e "s/^alignment_required:.*/alignment_required: ${ALIGNMENT_REQUIRED}/" \
  -e "s/^alignment_status:.*/alignment_status: ${ALIGNMENT_STATUS}/" \
  -e "s/^- 当前等级：.*/- 当前等级：${DELIVERY_LEVEL}/" \
  -e "s/^- 建议交付强度：.*/- 建议交付强度：${DELIVERY_TIER}/" \
  -e "s/^- 最终 delivery_level：.*/- 最终 delivery_level：${DELIVERY_LEVEL}/" \
  -e "s/^risk:.*/risk: ${RISK_VALUE}/" \
  -e "s/^mode:.*/mode: ${MODE_VALUE}/" \
  -e "s/^status:.*/status: ${STATUS_VALUE}/" \
  -e "s/^qa_status:.*/qa_status: pending/" \
  -e "s/^iteration:.*/iteration: 0/" \
  -e "s/^max_iterations:.*/max_iterations: 2/" \
  -e "s/^created_at:.*/created_at: ${today}/" \
  -e "s/^updated_at:.*/updated_at: ${today}/" \
  "$TEMPLATE" > "$FILE"

schema_violations="$(tc_validate "$FILE")" || {
  printf 'ERROR 生成的任务卡未通过 Schema 校验：%s\n' "$FILE" >&2
  printf '%s\n' "$schema_violations" >&2
  rm -f "$FILE"
  exit 1
}

cat <<EOF
已创建任务卡：
${FILE}

下一步：
  ai-workflow next --project-root ${PROJECT_ROOT} ${FILE}
EOF
