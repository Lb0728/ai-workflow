#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
AI_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
source "${SCRIPT_DIR}/ai_profile_select.sh"
LOADER="${SCRIPT_DIR}/ai_core_loader.sh"
PROJECT_ROOT="${AI_PROJECT_ROOT:-}"
ADAPTER_ID="${AI_ADAPTER_ID:-}"
ROLE_ID="${AI_ROLE_ID:-}"

if [ -z "$PROJECT_ROOT" ]; then
  if [ -f "$(pwd)/AGENTS.md" ]; then
    PROJECT_ROOT="$(pwd)"
  else
    PROJECT_ROOT="$AI_ROOT"
  fi
fi

PROJECT_ROOT="$(cd "$PROJECT_ROOT" && pwd)"
ADAPTER_ID="$(ai_select_project_adapter_id "${AI_ROOT}/adapters" "$ADAPTER_ID" "$PROJECT_ROOT")" || exit $?
ROLE_ID="$(ai_select_profile_id "${AI_ROOT}/roles" "$ROLE_ID" "Role Adapter")" || exit $?

resolve_input() {
  "$LOADER" \
    --project-root "$PROJECT_ROOT" \
    --adapter "$ADAPTER_ID" \
    --role "$ROLE_ID" \
    resolve "$1"
}

TASKS_DIR="${AI_RUNTIME_TASKS_DIR:-$(resolve_input runtime.tasks)}"
TASK_CARD_TEMPLATE="$(resolve_input core.template.task_card)"
FAST_BRIEF_TEMPLATE="$(resolve_input core.template.fast_brief)"
MICRO_TEMPLATE="$(resolve_input core.template.micro_change)"
CORE_TASK_TYPES="$(resolve_input core.task_types)"
ADAPTER_TASK_TYPES="$(resolve_input adapter.task_types)"

usage() {
  cat <<EOF
Usage: ./ai/tool/ai_loop_new.sh <task-type> <task-id> [slug] [priority] [delivery_level]

delivery_level:
  micro_change | light_feature | standard_delivery | high_risk_delivery

Backward-compatible aliases:
  fast_track -> light_feature
  standard | controlled -> standard_delivery
  high_risk -> high_risk_delivery

Examples:
  ./ai/tool/ai_loop_new.sh bugfix DEMO-1234 typo P2 micro_change
  ./ai/tool/ai_loop_new.sh feature DEMO-4567 help-support P1 light_feature
  ./ai/tool/ai_loop_new.sh feature DEMO-4568 training-entry P1 standard_delivery
可用 task type 由 Core 与当前 Project Adapter 配置共同定义。
EOF
}

TYPE="$1"
TASK_ID="$2"
SLUG_INPUT="$3"
ARG4="$4"
ARG5="$5"

if [ -z "$TYPE" ] || [ -z "$TASK_ID" ]; then
  usage
  exit 1
fi

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

TYPE_INPUT="$(printf '%s' "$TYPE" | tr '[:upper:]' '[:lower:]')"
TYPE="$(find_task_type "$CORE_TASK_TYPES" "$TYPE_INPUT")"
TYPE_CONFIG="$CORE_TASK_TYPES"
if [ -z "$TYPE" ]; then
  TYPE="$(find_task_type "$ADAPTER_TASK_TYPES" "$TYPE_INPUT")"
  TYPE_CONFIG="$ADAPTER_TASK_TYPES"
fi
if [ -z "$TYPE" ]; then
  echo "Unknown type for Core + Adapter ${ADAPTER_ID}: ${TYPE_INPUT}"
  usage
  exit 1
fi

TYPE_DEFAULT_DELIVERY="$(task_type_field "$TYPE_CONFIG" "$TYPE" default_delivery_level)"
TYPE_REAL_ENV="$(task_type_field "$TYPE_CONFIG" "$TYPE" real_environment_required)"

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
    micro|tiny|micro_change)
      echo "micro_change"
      ;;
    light|lite|quick|fast|fast-track|fast_track|light_feature)
      echo "light_feature"
      ;;
    standard|normal|controlled|control|standard_delivery)
      echo "standard_delivery"
      ;;
    high|heavy|high-risk|high_risk|high_risk_delivery)
      echo "high_risk_delivery"
      ;;
    "")
      echo ""
      ;;
    *)
      echo "UNKNOWN"
      ;;
  esac
}

normalize_priority() {
  case "$(printf '%s' "$1" | tr '[:lower:]' '[:upper:]')" in
    P0|P1|P2)
      printf '%s\n' "$(printf '%s' "$1" | tr '[:lower:]' '[:upper:]')"
      ;;
    "")
      echo ""
      ;;
    *)
      echo "UNKNOWN"
      ;;
  esac
}

read_score() {
  local prompt="$1"
  local value=""
  while true; do
    printf "%s (0/1/2)> " "$prompt" >&2
    IFS= read -r value
    case "$value" in
      0|1|2)
        echo "$value"
        return
        ;;
      *)
        echo "请输入 0、1 或 2。" >&2
        ;;
    esac
  done
}

read_multiline_optional() {
  local prompt="$1"
  local line=""
  local tmp

  tmp="$(mktemp)"
  echo >&2
  echo "${prompt}" >&2
  echo "逐行输入内容；单独输入 EOP 结束。无需填写时直接输入 EOP。" >&2

  while IFS= read -r line; do
    if [ "$line" = "EOP" ]; then
      break
    fi
    printf '%s\n' "$line" >> "$tmp"
  done

  if [ -s "$tmp" ]; then
    cat "$tmp"
  fi

  rm -f "$tmp"
}

replace_section() {
  local file="$1"
  local heading="$2"
  local content="$3"
  local tmp
  local content_file

  if [ -z "$content" ]; then
    return 0
  fi

  tmp="$(mktemp)"
  content_file="$(mktemp)"
  printf '%s\n' "$content" > "$content_file"

  awk -v heading="$heading" -v content_file="$content_file" '
    function print_content() {
      while ((getline line < content_file) > 0) {
        print line
      }
      close(content_file)
    }
    $0 == "## " heading {
      print
      print ""
      print_content()
      print ""
      in_section = 1
      next
    }
    in_section && /^## / {
      in_section = 0
    }
    !in_section {
      print
    }
  ' "$file" > "$tmp"

  mv "$tmp" "$file"
  rm -f "$content_file"
}

run_initial_intake() {
  echo >&2
  echo "开始填写任务载体。只填确定事实；不需要的项输入 EOP 跳过。" >&2
  echo "当前交付等级：${DELIVERY_LEVEL}。如需调整，必须记录原等级、调整后等级和原因。" >&2

  case "$DELIVERY_LEVEL" in
    micro_change)
      replace_section "$FILE" "目标" "$(read_multiline_optional "## 目标")"
      replace_section "$FILE" "范围" "$(read_multiline_optional "## 范围")"
      ;;
    light_feature)
      replace_section "$FILE" "目标" "$(read_multiline_optional "## 目标")"
      replace_section "$FILE" "范围" "$(read_multiline_optional "## 范围")"
      replace_section "$FILE" "不做" "$(read_multiline_optional "## 不做")"
      replace_section "$FILE" "关键规则" "$(read_multiline_optional "## 关键规则")"
      replace_section "$FILE" "验收" "$(read_multiline_optional "## 验收")"
      ;;
    *)
      replace_section "$FILE" "目标" "$(read_multiline_optional "## 目标")"
      replace_section "$FILE" "已确认事实" "$(read_multiline_optional "## 已确认事实")"
      replace_section "$FILE" "范围" "$(read_multiline_optional "## 范围")"
      replace_section "$FILE" "不做范围" "$(read_multiline_optional "## 不做范围")"
      replace_section "$FILE" "验收标准" "$(read_multiline_optional "## 验收标准")"
      ;;
  esac
}

SAFE_ID="$(sanitize "$TASK_ID")"
if [ -n "$SLUG_INPUT" ]; then
  SAFE_SLUG="$(sanitize "$SLUG_INPUT")"
else
  SAFE_SLUG="$TYPE"
fi

if [ -z "$SAFE_ID" ]; then
  echo "Invalid task id: ${TASK_ID}"
  exit 1
fi

if [ -z "$SAFE_SLUG" ]; then
  SAFE_SLUG="$TYPE"
fi

PRIORITY="$(normalize_priority "$ARG4")"
DELIVERY_LEVEL="$(normalize_delivery_level "$ARG5")"

if [ "$PRIORITY" = "UNKNOWN" ]; then
  PRIORITY=""
  DELIVERY_LEVEL="$(normalize_delivery_level "$ARG4")"
fi

if [ "$DELIVERY_LEVEL" = "UNKNOWN" ]; then
  echo "Unknown delivery level: ${ARG5:-$ARG4}"
  usage
  exit 1
fi

if [ -z "$PRIORITY" ]; then
  PRIORITY="P2"
fi

if [ -z "$DELIVERY_LEVEL" ]; then
  if [ -n "$TYPE_DEFAULT_DELIVERY" ]; then
    DELIVERY_LEVEL="$TYPE_DEFAULT_DELIVERY"
    DELIVERY_REASON="命中 Project Adapter task type ${TYPE} 的默认交付等级。"
  elif [ -t 0 ]; then
    echo "未提供 delivery_level，进入交互分流。" >&2
    echo "是否命中 Project Adapter 声明的高风险领域、核心链路、契约、共享状态、并发或兼容性强制升级？" >&2
    printf "high_risk? (y/N)> " >&2
    IFS= read -r FORCE_HIGH
    case "$(printf '%s' "$FORCE_HIGH" | tr '[:upper:]' '[:lower:]')" in
      y|yes)
        DELIVERY_LEVEL="high_risk_delivery"
        DELIVERY_REASON="命中高风险强制升级。"
        ;;
      *)
        echo "是否命中至少标准需求：新接口/接口契约、多页面共享状态、新依赖/权限/构建配置、关键验证无法完成、公共基础组件影响范围未知？" >&2
        printf "standard_or_above? (y/N)> " >&2
        IFS= read -r FORCE_STANDARD
        case "$(printf '%s' "$FORCE_STANDARD" | tr '[:upper:]' '[:lower:]')" in
          y|yes)
            DELIVERY_LEVEL="standard_delivery"
            DELIVERY_REASON="命中至少标准需求强制升级。"
            ;;
          *)
            SCORE_RANGE="$(read_score "改动范围")"
            SCORE_LOGIC="$(read_score "业务逻辑")"
            SCORE_DEP="$(read_score "依赖影响")"
            SCORE_REGRESSION="$(read_score "回归范围")"
            SCORE_UNCERTAINTY="$(read_score "不确定性")"
            TOTAL_SCORE=$((SCORE_RANGE + SCORE_LOGIC + SCORE_DEP + SCORE_REGRESSION + SCORE_UNCERTAINTY))
            if [ "$TOTAL_SCORE" -le 1 ]; then
              DELIVERY_LEVEL="micro_change"
            elif [ "$TOTAL_SCORE" -le 4 ]; then
              DELIVERY_LEVEL="light_feature"
            elif [ "$TOTAL_SCORE" -le 7 ]; then
              DELIVERY_LEVEL="standard_delivery"
            else
              DELIVERY_LEVEL="high_risk_delivery"
            fi
            DELIVERY_REASON="普通评分 ${TOTAL_SCORE} 分：改动范围=${SCORE_RANGE}, 业务逻辑=${SCORE_LOGIC}, 依赖影响=${SCORE_DEP}, 回归范围=${SCORE_REGRESSION}, 不确定性=${SCORE_UNCERTAINTY}。"
            ;;
        esac
        ;;
    esac
  else
    echo "delivery_level is required when the selected task type has no configured default."
    echo "Use one of: micro_change | light_feature | standard_delivery | high_risk_delivery"
    exit 1
  fi
fi

if [ "$DELIVERY_LEVEL" = "UNKNOWN" ] || [ -z "$DELIVERY_LEVEL" ]; then
  echo "Invalid delivery level."
  usage
  exit 1
fi

case "$DELIVERY_LEVEL" in
  micro_change)
    TEMPLATE="$MICRO_TEMPLATE"
    DELIVERY_TIER="L1"
    ;;
  light_feature)
    TEMPLATE="$FAST_BRIEF_TEMPLATE"
    DELIVERY_TIER="L1"
    ;;
  standard_delivery)
    TEMPLATE="$TASK_CARD_TEMPLATE"
    DELIVERY_TIER="L2"
    ;;
  high_risk_delivery)
    TEMPLATE="$TASK_CARD_TEMPLATE"
    DELIVERY_TIER="L3"
    ;;
  *)
    echo "Unsupported delivery level: ${DELIVERY_LEVEL}"
    exit 1
    ;;
esac

if [ ! -f "$TEMPLATE" ]; then
  echo "Template not found: ${TEMPLATE}"
  exit 1
fi

if [ -n "$TYPE_DEFAULT_DELIVERY" ] && [ "$DELIVERY_LEVEL" != "$TYPE_DEFAULT_DELIVERY" ]; then
  echo "${TYPE} tasks must use configured delivery level ${TYPE_DEFAULT_DELIVERY}."
  exit 1
fi

if [ "$DELIVERY_LEVEL" = "micro_change" ] && [ "$TYPE_DEFAULT_DELIVERY" = "high_risk_delivery" ]; then
  echo "${TYPE} tasks cannot use micro_change."
  exit 1
fi

if [ "$DELIVERY_LEVEL" = "high_risk_delivery" ]; then
  RISK_VALUE="high"
  SELF_TEST_LEVEL="specialized"
  ALIGNMENT_REQUIRED="true"
  ALIGNMENT_STATUS="pending"
elif [ "$DELIVERY_LEVEL" = "micro_change" ] || [ "$DELIVERY_LEVEL" = "light_feature" ]; then
  RISK_VALUE="low"
  SELF_TEST_LEVEL="quick"
  ALIGNMENT_REQUIRED="false"
  ALIGNMENT_STATUS="not_required"
else
  RISK_VALUE="normal"
  SELF_TEST_LEVEL="standard"
  ALIGNMENT_REQUIRED="false"
  ALIGNMENT_STATUS="not_required"
fi

if [ "$TYPE_REAL_ENV" = "true" ]; then
  REAL_ENV_RISK_VALUE="true"
  RISK_EVIDENCE_VALUE="${TYPE} 类型由 Project Adapter 声明为需要真实环境。"
else
  REAL_ENV_RISK_VALUE="false"
  RISK_EVIDENCE_VALUE=""
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
  -e "s/^- real_device_or_production_required:.*/- real_device_or_production_required: ${REAL_ENV_RISK_VALUE}/" \
  -e "s/^- 风险证据：.*/- 风险证据：${RISK_EVIDENCE_VALUE}/" \
  -e "s/^- 选择原因：.*/- 选择原因：${DELIVERY_REASON:-待补充强制升级或评分依据}/" \
  -e "s/^risk:.*/risk: ${RISK_VALUE}/" \
  -e "s/^mode:.*/mode: ${MODE_VALUE}/" \
  -e "s/^status:.*/status: ${STATUS_VALUE}/" \
  -e "s/^qa_status:.*/qa_status: pending/" \
  -e "s/^iteration:.*/iteration: 0/" \
  -e "s/^max_iterations:.*/max_iterations: 2/" \
  -e "s/^created_at:.*/created_at: ${today}/" \
  -e "s/^updated_at:.*/updated_at: ${today}/" \
  "$TEMPLATE" > "$FILE"

run_initial_intake

cat <<EOF
已创建任务载体：
${FILE}

当前分类：
- priority: ${PRIORITY}
- delivery_level: ${DELIVERY_LEVEL}
- self_test_level: ${SELF_TEST_LEVEL}

下一步：
1. 只填写确定事实，不写猜测。
2. 检查状态与合法下一步：
   ./ai/tool/ai_loop_status.sh ${FILE}
3. 生成下一阶段 Prompt：
   ./ai/tool/ai_loop_next.sh ${FILE}
EOF
