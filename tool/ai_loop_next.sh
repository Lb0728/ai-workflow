#!/usr/bin/env bash
# shellcheck disable=SC1111,SC1112  # Chinese curly quotes “” are intentional message text
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

TASKS_DIR="$(resolve_input runtime.tasks)"
CORE_TASK_TYPES="$(resolve_input core.task_types)"
ADAPTER_TASK_TYPES="$(resolve_input adapter.task_types)"
PROJECT_RULES="$(resolve_input project.rules)"
HIGH_RISK_ALIGNMENT_TEMPLATE="$(resolve_input core.template.high_risk_alignment)"

AGENT_ROUTER="$(resolve_input core.agent.router)"
AGENT_REQUIREMENT="$(resolve_input core.agent.requirement_breakdown)"
AGENT_BUGFIX="$(resolve_input core.agent.bugfix)"
AGENT_ARCHITECTURE="$(resolve_input core.agent.architecture_boundary)"
AGENT_CODING="$(resolve_input core.agent.coding)"
AGENT_SELF_TEST="$(resolve_input core.agent.self_test)"
AGENT_REVIEW="$(resolve_input core.agent.pr_review)"
AGENT_I18N="$(resolve_input core.agent.i18n_text_ui_risk)"
AGENT_COMMIT="$(resolve_input core.agent.commit)"

usage() {
  cat <<EOF
Usage: ./ai/tool/ai_loop_next.sh <task-file> [stage]

Stages:
  requirement_breakdown | analyze | impact_map | architecture | capability | alignment_pending | fix_ready | implement | ready_for_self_test | validation_pending | self_test | review | commit_ready | ready_for_qa | i18n | done | commit | blocked

Examples:
  ./ai/tool/ai_loop_next.sh <runtime-task>
  ./ai/tool/ai_loop_next.sh <runtime-task> verify
EOF
}

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

TASK_INPUT="$1"
STAGE_INPUT="$2"

if [ -z "$TASK_INPUT" ]; then
  usage
  exit 1
fi

resolve_task_file() {
  local input="$1"

  if [ -f "$input" ]; then
    echo "$(cd "$(dirname "$input")" && pwd)/$(basename "$input")"
    return 0
  fi

  if [ -f "${AI_ROOT}/${input}" ]; then
    echo "${AI_ROOT}/${input}"
    return 0
  fi

  if [ -f "${TASKS_DIR}/${input}" ]; then
    echo "${TASKS_DIR}/${input}"
    return 0
  fi

  return 1
}

read_frontmatter_value() {
  local key="$1"
  local file="$2"
  awk -F': *' -v key="$key" '
    $0 == "---" { fence += 1; next }
    fence == 1 && $1 == key { print $2; exit }
  ' "$file"
}

first_gate_value() {
  local label="$1"
  local file="$2"
  local line

  line="$(grep -m 1 -E "^[[:space:]]*- ${label}[^:]*:" "$file" || true)"
  if [ -z "$line" ]; then
    echo "MISSING"
    return
  fi

  printf '%s\n' "$line" \
    | awk -F': *' '{ print toupper($2) }' \
    | awk '{ print $1 }'
}

section_content() {
  local heading="$1"
  local file="$2"
  awk -v heading="## ${heading}" '
    $0 == heading { in_section = 1; next }
    in_section && /^## / { exit }
    in_section { print }
  ' "$file"
}

section_field_value() {
  local section="$1"
  local field="$2"
  local file="$3"
  section_content "$section" "$file" | awk -v field="$field" '
    $0 ~ "^[[:space:]]*-[[:space:]]*" field "(:|：)" {
      sub("^[[:space:]]*-[[:space:]]*" field "(:|：)[[:space:]]*", "")
      sub(/[[:space:]]+$/, "")
      print
      exit
    }
  '
}

section_field_item() {
  local section="$1"
  local field="$2"
  local file="$3"
  section_content "$section" "$file" | awk -v field="$field" '
    $0 ~ "^[[:space:]]*-[[:space:]]*" field "(:|：)" {
      value = $0
      sub("^[[:space:]]*-[[:space:]]*" field "(:|：)[[:space:]]*", "", value)
      if (value != "") { print value; exit }
      capture = 1
      next
    }
    capture && /^-[[:space:]]*[^[:space:]]/ { exit }
    capture && /^[[:space:]]+-[[:space:]]+/ {
      value = $0
      sub(/^[[:space:]]+-[[:space:]]+/, "", value)
      if (value != "") { print value; exit }
    }
  '
}

is_substantive() {
  case "$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')" in
    ""|无|n/a|not_run|pending|待填写|未知|unknown)
      return 1
      ;;
    *)
      return 0
      ;;
  esac
}

uses_speculative_language() {
  printf '%s\n' "$1" | grep -E '可能是|看起来像|通常情况下|根据经验|大概率|建议尝试' >/dev/null
}

add_missing_field() {
  local section="$1"
  local field="$2"
  local value
  value="$(section_field_item "$section" "$field" "$TASK_FILE")"
  if ! is_substantive "$value"; then
    decision_errors+=("${section}.${field} 缺失")
  fi
}

add_missing_risk_field() {
  local section="$1"
  local field="$2"
  local value
  value="$(section_field_item "$section" "$field" "$TASK_FILE")"
  if ! is_substantive "$value"; then
    risk_errors+=("${section}.${field} 缺失")
  fi
}

delivery_tier() {
  case "$1" in
    micro_change|light_feature) echo "L1" ;;
    standard_delivery) echo "L2" ;;
    high_risk_delivery) echo "L3" ;;
    *) echo "UNKNOWN" ;;
  esac
}

delivery_rank() {
  case "$1" in
    micro_change|light_feature) echo "1" ;;
    standard_delivery) echo "2" ;;
    high_risk_delivery) echo "3" ;;
    *) echo "0" ;;
  esac
}

contains_word() {
  local needle="$1"
  shift
  for item in "$@"; do
    if [ "$item" = "$needle" ]; then
      return 0
    fi
  done
  return 1
}

print_words() {
  if [ "$#" -eq 0 ]; then
    echo "- 无"
    return
  fi
  for item in "$@"; do
    echo "- ${item}"
  done
}

normalize_stage() {
  case "$1" in
    requirement|requirement-breakdown|requirement_breakdown)
      echo "requirement_breakdown"
      ;;
    analyze|analysis)
      echo "analyze"
      ;;
    impact|impact-map|impact_map|plan)
      echo "impact_map"
      ;;
    architecture|arch|architecture-check|arch-boundary|arch_boundary)
      echo "architecture"
      ;;
    capability|strategy|capability-check)
      echo "capability"
      ;;
    alignment|align|alignment-pending|alignment_pending|confirm|confirmation)
      echo "alignment_pending"
      ;;
    fix-ready|fix_ready|fix)
      echo "fix_ready"
      ;;
    implement|coding|code)
      echo "implement"
      ;;
    ready-for-self-test|ready_for_self_test|ready-self-test)
      echo "ready_for_self_test"
      ;;
    validation|validation-pending|validation_pending)
      echo "validation_pending"
      ;;
    selftest|self-test|self_test|self-test-in-progress|self_test_in_progress)
      echo "self_test_in_progress"
      ;;
    verify|test)
      echo "self_test_in_progress"
      ;;
    review|pr-review|pr_review)
      echo "review"
      ;;
    ready|qa|ready-for-qa|ready_for_qa)
      echo "ready_for_qa"
      ;;
    i18n|ui|ui-check)
      echo "i18n"
      ;;
    done|loop-closeout|loop_closeout)
      echo "done"
      ;;
    commit|commit-ready|commit_ready|generate-commit-message|generate_commit_message)
      echo "commit_ready"
      ;;
    blocked|human)
      echo "blocked"
      ;;
    *)
      echo "$1"
      ;;
  esac
}

decision_stage_to_loop_stage() {
  case "$1" in
    requirement_breakdown) echo "requirement_breakdown" ;;
    bugfix_diagnosis) echo "analyze" ;;
    arch_boundary) echo "architecture" ;;
    coding) echo "implement" ;;
    self_test) echo "self_test_in_progress" ;;
    pr_review) echo "review" ;;
    human) echo "blocked" ;;
    loop_closeout) echo "done" ;;
    *) echo "" ;;
  esac
}

decision_transition_allowed() {
  local action="$1"
  local current="$2"
  local target="$3"
  case "${action}:${current}:${target}" in
    ADVANCE:requirement_breakdown:bugfix_diagnosis|ADVANCE:requirement_breakdown:arch_boundary|ADVANCE:requirement_breakdown:coding|\
    ADVANCE:bugfix_diagnosis:arch_boundary|ADVANCE:bugfix_diagnosis:coding|\
    ADVANCE:arch_boundary:coding|ADVANCE:coding:self_test|ADVANCE:self_test:pr_review|ADVANCE:pr_review:loop_closeout|\
    RETURN:bugfix_diagnosis:requirement_breakdown|\
    RETURN:arch_boundary:bugfix_diagnosis|RETURN:arch_boundary:requirement_breakdown|\
    RETURN:coding:bugfix_diagnosis|RETURN:coding:requirement_breakdown|RETURN:coding:arch_boundary|\
    RETURN:self_test:coding|RETURN:self_test:bugfix_diagnosis|RETURN:self_test:requirement_breakdown|\
    RETURN:pr_review:coding|RETURN:pr_review:bugfix_diagnosis|RETURN:pr_review:requirement_breakdown)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

loop_stage_to_decision_stage() {
  case "$(normalize_stage "$1")" in
    requirement_breakdown) echo "requirement_breakdown" ;;
    analyze|impact_map|fix_ready) echo "bugfix_diagnosis" ;;
    architecture|capability|alignment_pending) echo "arch_boundary" ;;
    implement|ready_for_self_test) echo "coding" ;;
    validation_pending|self_test_in_progress|ready_for_qa) echo "self_test" ;;
    review|i18n|commit_ready) echo "pr_review" ;;
    blocked) echo "human" ;;
    done) echo "loop_closeout" ;;
    *) echo "" ;;
  esac
}

if ! TASK_FILE="$(resolve_task_file "$TASK_INPUT")"; then
  echo "Task file not found: ${TASK_INPUT}"
  exit 1
fi

TYPE="$(read_frontmatter_value type "$TASK_FILE" | tr '[:upper:]' '[:lower:]')"
PRIORITY="$(read_frontmatter_value priority "$TASK_FILE" | tr '[:lower:]' '[:upper:]')"
DELIVERY_LEVEL="$(read_frontmatter_value delivery_level "$TASK_FILE" | tr '[:upper:]' '[:lower:]')"
SELF_TEST_LEVEL="$(read_frontmatter_value self_test_level "$TASK_FILE" | tr '[:upper:]' '[:lower:]')"
ALIGNMENT_REQUIRED="$(read_frontmatter_value alignment_required "$TASK_FILE" | tr '[:upper:]' '[:lower:]')"
ALIGNMENT_STATUS="$(read_frontmatter_value alignment_status "$TASK_FILE" | tr '[:upper:]' '[:lower:]')"
ALIGNMENT_CONFIRMED_AT="$(read_frontmatter_value alignment_confirmed_at "$TASK_FILE")"
ALIGNMENT_CONFIRMATION_NOTE="$(read_frontmatter_value alignment_confirmation_note "$TASK_FILE")"
RISK="$(read_frontmatter_value risk "$TASK_FILE" | tr '[:upper:]' '[:lower:]')"
MODE="$(read_frontmatter_value mode "$TASK_FILE" | tr '[:upper:]' '[:lower:]')"
STATUS="$(read_frontmatter_value status "$TASK_FILE" | tr '[:upper:]' '[:lower:]')"
QA_STATUS="$(read_frontmatter_value qa_status "$TASK_FILE" | tr '[:upper:]' '[:lower:]')"
ITERATION="$(read_frontmatter_value iteration "$TASK_FILE")"
MAX_ITERATIONS="$(read_frontmatter_value max_iterations "$TASK_FILE")"
LEGACY="$(read_frontmatter_value legacy "$TASK_FILE" | tr '[:upper:]' '[:lower:]')"

if [ -z "$TYPE" ]; then
  TYPE="bugfix"
fi
case "$DELIVERY_LEVEL" in
  micro|tiny|micro_change)
    DELIVERY_LEVEL="micro_change"
    ;;
  light|lite|quick|fast|fast-track|fast_track|light_feature)
    DELIVERY_LEVEL="light_feature"
    ;;
  standard|normal|controlled|control|standard_delivery)
    DELIVERY_LEVEL="standard_delivery"
    ;;
  high|heavy|high-risk|high_risk|high_risk_delivery)
    DELIVERY_LEVEL="high_risk_delivery"
    ;;
  "")
    DELIVERY_LEVEL="missing"
    ;;
  *)
    DELIVERY_LEVEL="missing"
    ;;
esac
if [ -z "$PRIORITY" ]; then PRIORITY="UNKNOWN"; fi
case "$SELF_TEST_LEVEL" in
  quick|standard|specialized)
    ;;
  "")
    case "$DELIVERY_LEVEL" in
      micro_change|light_feature)
        SELF_TEST_LEVEL="quick"
        ;;
      high_risk_delivery)
        SELF_TEST_LEVEL="specialized"
        ;;
      *)
        SELF_TEST_LEVEL="standard"
        ;;
    esac
    ;;
  *)
    SELF_TEST_LEVEL="standard"
    ;;
esac
if [ -z "$RISK" ]; then RISK="normal"; fi
if [ "$DELIVERY_LEVEL" = "high_risk_delivery" ]; then
  if [ -z "$ALIGNMENT_REQUIRED" ]; then ALIGNMENT_REQUIRED="true"; fi
  if [ -z "$ALIGNMENT_STATUS" ]; then ALIGNMENT_STATUS="pending"; fi
else
  if [ -z "$ALIGNMENT_REQUIRED" ]; then ALIGNMENT_REQUIRED="false"; fi
  if [ -z "$ALIGNMENT_STATUS" ]; then ALIGNMENT_STATUS="not_required"; fi
fi
if [ -z "$MODE" ]; then MODE="plan"; fi
if [ -z "$STATUS" ]; then STATUS="analyze"; fi
if [ -z "$QA_STATUS" ]; then QA_STATUS="pending"; fi
if [ -z "$ITERATION" ]; then ITERATION="0"; fi
if [ -z "$MAX_ITERATIONS" ]; then MAX_ITERATIONS="2"; fi
if [ -z "$LEGACY" ]; then
  if grep -q '^## 下一步决策$' "$TASK_FILE"; then
    LEGACY="false"
  else
    LEGACY="true"
  fi
fi

TYPE_INPUT="$(printf '%s' "$TYPE" | tr '[:upper:]' '[:lower:]')"
TYPE="$(find_task_type "$CORE_TASK_TYPES" "$TYPE_INPUT")"
TYPE_CONFIG="$CORE_TASK_TYPES"
if [ -z "$TYPE" ]; then
  TYPE="$(find_task_type "$ADAPTER_TASK_TYPES" "$TYPE_INPUT")"
  TYPE_CONFIG="$ADAPTER_TASK_TYPES"
fi
if [ -z "$TYPE" ]; then
  echo "Unknown task type for Core + Adapter ${ADAPTER_ID} in ${TASK_FILE}: ${TYPE_INPUT}"
  exit 1
fi

WORKFLOW_KEY="$(task_type_field "$TYPE_CONFIG" "$TYPE" workflow_key)"
LOOP_NAME="$(task_type_field "$TYPE_CONFIG" "$TYPE" loop_name)"
TYPE_DEFAULT_DELIVERY="$(task_type_field "$TYPE_CONFIG" "$TYPE" default_delivery_level)"
TYPE_REAL_ENV="$(task_type_field "$TYPE_CONFIG" "$TYPE" real_environment_required)"
WORKFLOW="$(resolve_input "$WORKFLOW_KEY")"

CURRENT_DELIVERY_TIER="$(delivery_tier "$DELIVERY_LEVEL")"
RISK_SIGNALS_PRESENT="false"
RISK_RECOMMENDED_TIER="UNASSESSED"
RISK_MIN_DELIVERY_LEVEL=""
RISK_ESCALATION_REQUIRED="false"
risk_errors=()
high_risk_signals=()
ordinary_risk_signals=()

if grep -q '^## 交付风险信号$' "$TASK_FILE"; then
  RISK_SIGNALS_PRESENT="true"
  RISK_CORE_USER_FLOW="$(section_field_value "交付风险信号" "core_user_flow" "$TASK_FILE" | tr '[:upper:]' '[:lower:]')"
  RISK_API_CONTRACT="$(section_field_value "交付风险信号" "api_contract_changed" "$TASK_FILE" | tr '[:upper:]' '[:lower:]')"
  RISK_SHARED_STATE="$(section_field_value "交付风险信号" "shared_state_changed" "$TASK_FILE" | tr '[:upper:]' '[:lower:]')"
  RISK_MULTIPLE_MODULES="$(section_field_value "交付风险信号" "multiple_modules_affected" "$TASK_FILE" | tr '[:upper:]' '[:lower:]')"
  RISK_MULTIPLE_REPOS="$(section_field_value "交付风险信号" "multiple_repositories_affected" "$TASK_FILE" | tr '[:upper:]' '[:lower:]')"
  RISK_SIMILAR_DEFECT="$(section_field_value "交付风险信号" "similar_defect_happened_before" "$TASK_FILE" | tr '[:upper:]' '[:lower:]')"
  RISK_IMPACT_UNCLEAR="$(section_field_value "交付风险信号" "impact_scope_unclear" "$TASK_FILE" | tr '[:upper:]' '[:lower:]')"
  RISK_ARCH_BOUNDARY="$(section_field_value "交付风险信号" "architecture_boundary_involved" "$TASK_FILE" | tr '[:upper:]' '[:lower:]')"
  RISK_REAL_ENV="$(section_field_value "交付风险信号" "real_device_or_production_required" "$TASK_FILE" | tr '[:upper:]' '[:lower:]')"

  for signal in \
    "core_user_flow:${RISK_CORE_USER_FLOW}" \
    "api_contract_changed:${RISK_API_CONTRACT}" \
    "shared_state_changed:${RISK_SHARED_STATE}" \
    "multiple_modules_affected:${RISK_MULTIPLE_MODULES}" \
    "multiple_repositories_affected:${RISK_MULTIPLE_REPOS}" \
    "similar_defect_happened_before:${RISK_SIMILAR_DEFECT}" \
    "impact_scope_unclear:${RISK_IMPACT_UNCLEAR}" \
    "architecture_boundary_involved:${RISK_ARCH_BOUNDARY}" \
    "real_device_or_production_required:${RISK_REAL_ENV}"; do
    signal_name="${signal%%:*}"
    signal_value="${signal#*:}"
    case "$signal_value" in
      true)
        if [ "$signal_name" = "multiple_modules_affected" ]; then
          ordinary_risk_signals+=("$signal_name")
        else
          high_risk_signals+=("$signal_name")
        fi
        ;;
      false)
        ;;
      *)
        risk_errors+=("交付风险信号.${signal_name} 必须明确填写 true 或 false")
        ;;
    esac
  done

  if [ "${#high_risk_signals[@]}" -gt 0 ]; then
    RISK_RECOMMENDED_TIER="L3"
    RISK_MIN_DELIVERY_LEVEL="high_risk_delivery"
  elif [ "${#ordinary_risk_signals[@]}" -gt 0 ]; then
    RISK_RECOMMENDED_TIER="L2"
    RISK_MIN_DELIVERY_LEVEL="standard_delivery"
  else
    RISK_RECOMMENDED_TIER="L1"
    RISK_MIN_DELIVERY_LEVEL="light_feature"
  fi

  if [ "${#high_risk_signals[@]}" -gt 0 ] || [ "${#ordinary_risk_signals[@]}" -gt 0 ]; then
    risk_evidence_value="$(section_field_item "交付风险信号" "风险证据" "$TASK_FILE")"
    if ! is_substantive "$risk_evidence_value"; then
      risk_errors+=("交付风险信号.风险证据 缺失")
    fi
  fi

  if [ "$(delivery_rank "$DELIVERY_LEVEL")" -lt "$(delivery_rank "$RISK_MIN_DELIVERY_LEVEL")" ]; then
    RISK_ESCALATION_REQUIRED="true"
  fi
fi

DECISION_ACTION="$(section_field_value "下一步决策" "动作" "$TASK_FILE" | tr '[:lower:]' '[:upper:]')"
DECISION_CURRENT_STAGE="$(section_field_value "下一步决策" "当前阶段" "$TASK_FILE" | tr '[:upper:]' '[:lower:]')"
DECISION_TARGET_STAGE="$(section_field_value "下一步决策" "目标阶段" "$TASK_FILE" | tr '[:upper:]' '[:lower:]')"
DECISION_REASON="$(section_field_item "下一步决策" "决策原因" "$TASK_FILE")"
DECISION_ESCALATE_FROM="$(section_field_value "下一步决策" "升级前 delivery_level" "$TASK_FILE" | tr '[:upper:]' '[:lower:]')"
DECISION_ESCALATE_TO="$(section_field_value "下一步决策" "升级后 delivery_level" "$TASK_FILE" | tr '[:upper:]' '[:lower:]')"
DECISION_TRIGGERED_RISKS="$(section_field_item "下一步决策" "触发风险信号" "$TASK_FILE")"
DECISION_ROUTED_STAGE="$(decision_stage_to_loop_stage "$DECISION_TARGET_STAGE")"
decision_errors=()

if [ "$TYPE" = "bugfix" ] && [ "$LEGACY" != "true" ]; then
  case "$DECISION_ACTION" in
    STAY|ADVANCE|RETURN|STOP|COMPLETE|ESCALATE)
      ;;
    "")
      decision_errors+=("下一步决策.动作 缺失")
      ;;
    *)
      decision_errors+=("下一步决策.动作 只能是 STAY / ADVANCE / RETURN / STOP / COMPLETE / ESCALATE")
      ;;
  esac

  if [ -z "$(decision_stage_to_loop_stage "$DECISION_CURRENT_STAGE")" ]; then
    decision_errors+=("下一步决策.当前阶段 不存在：${DECISION_CURRENT_STAGE:-空}")
  elif [ "$DECISION_CURRENT_STAGE" != "$(loop_stage_to_decision_stage "$STATUS")" ]; then
    decision_errors+=("下一步决策.当前阶段 ${DECISION_CURRENT_STAGE} 与 status=${STATUS} 不一致")
  fi
  if [ -z "$DECISION_REASON" ]; then
    decision_errors+=("下一步决策.决策原因 缺失")
  fi
  add_missing_field "下一步决策" "当前结论"
  add_missing_field "下一步决策" "证据"
  if [ -z "$(section_field_item "下一步决策" "缺少证据" "$TASK_FILE")" ]; then
    decision_errors+=("下一步决策.缺少证据 必须明确填写；没有缺口时写“无”")
  fi

  case "$DECISION_ACTION" in
    STAY)
      if [ "$DECISION_TARGET_STAGE" != "$DECISION_CURRENT_STAGE" ]; then
        decision_errors+=("STAY 的目标阶段必须等于当前阶段")
      fi
      ;;
    ADVANCE|RETURN)
      if [ -z "$DECISION_ROUTED_STAGE" ]; then
        decision_errors+=("${DECISION_ACTION} 必须提供存在的目标阶段")
      elif ! decision_transition_allowed "$DECISION_ACTION" "$DECISION_CURRENT_STAGE" "$DECISION_TARGET_STAGE"; then
        decision_errors+=("不允许的阶段转换：${DECISION_ACTION} ${DECISION_CURRENT_STAGE} -> ${DECISION_TARGET_STAGE}")
      fi
      ;;
    STOP)
      if [ "$DECISION_TARGET_STAGE" != "human" ]; then
        decision_errors+=("STOP 的目标阶段必须是 human")
      fi
      add_missing_field "下一步决策" "阻塞原因"
      add_missing_field "下一步决策" "已完成内容"
      add_missing_field "下一步决策" "缺少信息或资源"
      add_missing_field "下一步决策" "人工下一步"
      add_missing_field "下一步决策" "恢复后返回阶段"
      ;;
    COMPLETE)
      if [ "$DECISION_TARGET_STAGE" != "loop_closeout" ]; then
        decision_errors+=("COMPLETE 的目标阶段必须是 loop_closeout")
      elif [ "$DECISION_CURRENT_STAGE" != "pr_review" ]; then
        decision_errors+=("COMPLETE 只能由 pr_review 进入 loop_closeout")
      fi
      ;;
    ESCALATE)
      if [ "$RISK_SIGNALS_PRESENT" != "true" ]; then
        decision_errors+=("ESCALATE 前必须填写交付风险信号")
      fi
      if [ -z "$DECISION_ROUTED_STAGE" ]; then
        decision_errors+=("ESCALATE 必须提供存在的目标阶段")
      fi
      if [ "$DECISION_TARGET_STAGE" != "bugfix_diagnosis" ] && [ "$DECISION_TARGET_STAGE" != "arch_boundary" ]; then
        decision_errors+=("ESCALATE 目标阶段只能是 bugfix_diagnosis 或 arch_boundary")
      fi
      if [ "$(delivery_rank "$DECISION_ESCALATE_FROM")" -eq 0 ] || [ "$(delivery_rank "$DECISION_ESCALATE_TO")" -eq 0 ]; then
        decision_errors+=("ESCALATE 必须填写有效的升级前 / 升级后 delivery_level")
      elif [ "$(delivery_rank "$DECISION_ESCALATE_TO")" -le "$(delivery_rank "$DECISION_ESCALATE_FROM")" ]; then
        decision_errors+=("ESCALATE 只允许升级，不允许同级或降级")
      fi
      if [ "$DELIVERY_LEVEL" != "$DECISION_ESCALATE_TO" ]; then
        decision_errors+=("ESCALATE 后任务卡 delivery_level 必须更新为 ${DECISION_ESCALATE_TO:-目标等级}")
      fi
      if ! is_substantive "$DECISION_TRIGGERED_RISKS"; then
        decision_errors+=("ESCALATE 必须记录触发风险信号")
      fi
      for risk_error in "${risk_errors[@]}"; do
        decision_errors+=("ESCALATE 风险 Gate：${risk_error}")
      done
      ;;
  esac

  if [ "$DECISION_ACTION" = "ADVANCE" ] && [ "$DECISION_TARGET_STAGE" = "coding" ]; then
    add_missing_field "Bugfix 诊断证据" "实际现象"
    add_missing_field "Bugfix 诊断证据" "触发条件"
    add_missing_field "Bugfix 诊断证据" "预期行为"
    add_missing_field "Bugfix 诊断证据" "根因结论"
    add_missing_field "Bugfix 诊断证据" "根因证据"
    add_missing_field "Bugfix 诊断证据" "最小修改范围"
    add_missing_field "Bugfix 诊断证据" "验证计划"
    root_cause_value="$(section_field_item "Bugfix 诊断证据" "根因结论" "$TASK_FILE")"
    root_evidence_value="$(section_field_item "Bugfix 诊断证据" "根因证据" "$TASK_FILE")"
    if uses_speculative_language "$root_cause_value" || uses_speculative_language "$root_evidence_value"; then
      decision_errors+=("ADVANCE -> coding 的根因结论和根因证据不能只使用推测性措辞")
    fi
    if [ "$RISK_ESCALATION_REQUIRED" = "true" ]; then
      decision_errors+=("风险信号要求先 ESCALATE 到 ${RISK_RECOMMENDED_TIER}，不得进入 Coding")
    fi
  fi

  if [ "$CURRENT_DELIVERY_TIER" = "L3" ] && [ "$DECISION_TARGET_STAGE" = "arch_boundary" ] && \
     { [ "$DECISION_ACTION" = "ADVANCE" ] || [ "$DECISION_ACTION" = "ESCALATE" ]; }; then
    add_missing_field "缺陷 Memory 检索" "检索关键词"
    add_missing_field "缺陷 Memory 检索" "检索命令"
    add_missing_field "缺陷 Memory 检索" "检索结论"
    add_missing_field "Change Impact Analysis" "变化入口"
    add_missing_field "Change Impact Analysis" "受影响业务状态"
    add_missing_field "Change Impact Analysis" "状态 owner / 数据真源"
    add_missing_field "Change Impact Analysis" "写入方与读取方"
    add_missing_field "Change Impact Analysis" "API 成功 / 失败 / 空值 / 超时路径"
    add_missing_field "Change Impact Analysis" "初始化与状态恢复路径"
    add_missing_field "Change Impact Analysis" "相邻业务场景"
    add_missing_field "Change Impact Analysis" "涉及模块 / 仓库"
    add_missing_field "Change Impact Analysis" "明确不受影响范围"
    if [ "$RISK_SIMILAR_DEFECT" = "true" ]; then
      add_missing_field "缺陷 Memory 检索" "命中缺陷卡"
      add_missing_field "缺陷 Memory 检索" "历史根因"
      add_missing_field "缺陷 Memory 检索" "本次重新引入风险"
      add_missing_field "缺陷 Memory 检索" "必须回归的历史场景"
    fi
  fi

  if [ "$DECISION_CURRENT_STAGE" = "self_test" ]; then
    case "$DECISION_ACTION:$DECISION_TARGET_STAGE" in
      RETURN:coding)
        expected_failure_category="IMPLEMENTATION_ERROR"
        ;;
      RETURN:bugfix_diagnosis)
        expected_failure_category="ROOT_CAUSE_ERROR"
        ;;
      RETURN:requirement_breakdown)
        expected_failure_category="REQUIREMENT_ERROR"
        ;;
      STOP:human)
        expected_failure_category="ENVIRONMENT_BLOCKED"
        ;;
      ADVANCE:pr_review)
        expected_failure_category="NONE"
        add_missing_field "Bugfix 自测证据" "测试结果"
        add_missing_field "Bugfix 自测证据" "原问题场景验证"
        add_missing_field "Bugfix 自测证据" "回归检查范围"
        if [ -z "$(section_field_item "Bugfix 自测证据" "未验证项" "$TASK_FILE")" ]; then
          decision_errors+=("Bugfix 自测证据.未验证项 必须明确填写；全部覆盖时写“无”")
        fi
        if [ "$CURRENT_DELIVERY_TIER" = "L3" ]; then
          add_missing_field "Bugfix 自测证据" "相邻业务场景"
          if [ "$RISK_SIMILAR_DEFECT" = "true" ]; then
            add_missing_field "Bugfix 自测证据" "历史缺陷场景"
          fi
          if [ "$RISK_API_CONTRACT" = "true" ]; then
            add_missing_field "Bugfix 自测证据" "接口异常场景"
          fi
          if [ "$RISK_CORE_USER_FLOW" = "true" ] || [ "$RISK_SHARED_STATE" = "true" ]; then
            add_missing_field "Bugfix 自测证据" "状态恢复场景"
          fi
        fi
        ;;
      *)
        expected_failure_category=""
        ;;
    esac
    actual_failure_category="$(section_field_value "下一步决策" "Self Test 失败分类" "$TASK_FILE" | tr '[:lower:]' '[:upper:]')"
    if [ -n "$expected_failure_category" ] && [ "$actual_failure_category" != "$expected_failure_category" ]; then
      decision_errors+=("Self Test 路由需要失败分类 ${expected_failure_category}，当前为 ${actual_failure_category:-空}")
    fi
  fi

  if [ "$DECISION_ACTION" = "COMPLETE" ]; then
    add_missing_field "Bugfix 诊断证据" "根因结论"
    add_missing_field "Bugfix 诊断证据" "根因证据"
    add_missing_field "Implement Summary" "修改文件"
    add_missing_field "Implement Summary" "关键改动"
    add_missing_field "Bugfix 自测证据" "测试结果"
    add_missing_field "Bugfix 自测证据" "原问题场景验证"
    add_missing_field "Bugfix 自测证据" "回归检查范围"
    if [ -z "$(section_field_item "Bugfix 自测证据" "未验证项" "$TASK_FILE")" ]; then
      decision_errors+=("Bugfix 自测证据.未验证项 必须明确填写；全部覆盖时写“无”")
    fi
    add_missing_field "评审证据" "结论"
    if [ "$(first_gate_value "PR Review Gate" "$TASK_FILE")" != "PASS" ]; then
      decision_errors+=("COMPLETE 前 PR Review Gate 必须为 PASS")
    fi
  fi
fi

if [ -n "$STAGE_INPUT" ]; then
  STAGE="$(normalize_stage "$STAGE_INPUT")"
elif [ "$TYPE" = "bugfix" ] && [ "$LEGACY" != "true" ] && [ "${#decision_errors[@]}" -eq 0 ]; then
  STAGE="$DECISION_ROUTED_STAGE"
else
  STAGE="$(normalize_stage "$STATUS")"
fi

if [ -z "$STAGE_INPUT" ] && [ "$STATUS" = "ready_for_self_test" ]; then
  STAGE="self_test_in_progress"
fi

case "$CURRENT_DELIVERY_TIER" in
  L1) EXPECTED_SELF_TEST_LEVEL="quick" ;;
  L2) EXPECTED_SELF_TEST_LEVEL="standard" ;;
  L3) EXPECTED_SELF_TEST_LEVEL="specialized" ;;
  *) EXPECTED_SELF_TEST_LEVEL="" ;;
esac
SELF_TEST_LEVEL_MISMATCH="false"
if [ "$RISK_SIGNALS_PRESENT" = "true" ] && [ -n "$EXPECTED_SELF_TEST_LEVEL" ] && \
   { [ "$STAGE" = "implement" ] || [ "$STAGE" = "self_test_in_progress" ] || [ "$STAGE" = "review" ]; } && \
   [ "$SELF_TEST_LEVEL" != "$EXPECTED_SELF_TEST_LEVEL" ]; then
  SELF_TEST_LEVEL_MISMATCH="true"
  risk_errors+=("${CURRENT_DELIVERY_TIER} 的 self_test_level 必须为 ${EXPECTED_SELF_TEST_LEVEL}")
  if [ "$TYPE" = "bugfix" ] && [ "$DECISION_CURRENT_STAGE" = "self_test" ]; then
    decision_errors+=("Self Test 风险等级与 self_test_level 不一致")
  fi
fi

if [ "$RISK_SIGNALS_PRESENT" = "true" ] && [ "$STAGE" = "implement" ]; then
  if [ "$RISK_ESCALATION_REQUIRED" = "true" ]; then
    risk_errors+=("当前 ${CURRENT_DELIVERY_TIER} 低于风险要求 ${RISK_RECOMMENDED_TIER}，必须先升级 delivery_level")
  fi

  if [ "$CURRENT_DELIVERY_TIER" = "L3" ]; then
    add_missing_risk_field "缺陷 Memory 检索" "检索关键词"
    add_missing_risk_field "缺陷 Memory 检索" "检索命令"
    add_missing_risk_field "缺陷 Memory 检索" "检索结论"
    add_missing_risk_field "Change Impact Analysis" "变化入口"
    add_missing_risk_field "Change Impact Analysis" "受影响业务状态"
    add_missing_risk_field "Change Impact Analysis" "状态 owner / 数据真源"
    add_missing_risk_field "Change Impact Analysis" "写入方与读取方"
    add_missing_risk_field "Change Impact Analysis" "API 成功 / 失败 / 空值 / 超时路径"
    add_missing_risk_field "Change Impact Analysis" "初始化与状态恢复路径"
    add_missing_risk_field "Change Impact Analysis" "相邻业务场景"
    add_missing_risk_field "Change Impact Analysis" "涉及模块 / 仓库"
    add_missing_risk_field "Change Impact Analysis" "明确不受影响范围"
    if [ "$RISK_SIMILAR_DEFECT" = "true" ]; then
      add_missing_risk_field "缺陷 Memory 检索" "命中缺陷卡"
      add_missing_risk_field "缺陷 Memory 检索" "历史根因"
      add_missing_risk_field "缺陷 Memory 检索" "本次重新引入风险"
      add_missing_risk_field "缺陷 Memory 检索" "必须回归的历史场景"
    fi
    if [ "$ALIGNMENT_REQUIRED" != "true" ]; then
      risk_errors+=("L3 必须设置 alignment_required=true")
    fi
  fi
fi

L0="$(first_gate_value "L0 Diff Gate" "$TASK_FILE")"
L1="$(first_gate_value "L1 Basic Run Gate" "$TASK_FILE")"
L2="$(first_gate_value "L2 Feature Verification Gate" "$TASK_FILE")"
if [ "$L2" = "MISSING" ]; then
  L2="$(first_gate_value "L2 Page Verification Gate" "$TASK_FILE")"
fi
L3="$(first_gate_value "L3 Direct Regression Gate" "$TASK_FILE")"
HIGH_RISK="$(first_gate_value "High Risk Gate" "$TASK_FILE")"
DIFF_REVIEW_LITE="$(first_gate_value "Diff Review Lite Gate" "$TASK_FILE")"
ARCH_GATE="$(first_gate_value "Architecture Gate" "$TASK_FILE")"
DEVICE_GATE="$(first_gate_value "Platform / Transport Gate" "$TASK_FILE")"
if [ "$DEVICE_GATE" = "MISSING" ]; then
  DEVICE_GATE="$(first_gate_value "Device / BLE / MQTT Gate" "$TASK_FILE")"
fi
HISTORICAL_GATE="$(first_gate_value "Historical Regression Gate" "$TASK_FILE")"

if [ "$RISK_SIGNALS_PRESENT" = "true" ] && [ "$STAGE" = "implement" ] && \
   [ "$CURRENT_DELIVERY_TIER" = "L3" ] && [ "$ARCH_GATE" != "PASS" ]; then
  risk_errors+=("L3 进入 Coding 前 Architecture Gate 必须为 PASS")
fi

missing_gates=()
failed_gates=()
blocked_gates=()
for gate in "L0:${L0}" "L1:${L1}" "L2:${L2}" "L3:${L3}" "HighRisk:${HIGH_RISK}" "Historical:${HISTORICAL_GATE}"; do
  name="${gate%%:*}"
  value="${gate#*:}"
  case "$value" in
    PASS|N/A)
      ;;
    FAIL)
      failed_gates+=("$name")
      ;;
    BLOCKED)
      blocked_gates+=("$name")
      ;;
    MISSING|PENDING|NOT_RUN|"")
      missing_gates+=("$name")
      ;;
  esac
done

required_missing=()
required_failed=()
required_blocked=()

add_required_gate() {
  local name="$1"
  local value="$2"
  case "$value" in
    PASS)
      ;;
    N/A)
      if [ "$name" = "L3" ] && { [ "$DELIVERY_LEVEL" = "light_feature" ] || [ "$DELIVERY_LEVEL" = "micro_change" ]; }; then
        return
      fi
      required_missing+=("$name:N/A 不适用于当前必需门禁")
      ;;
    FAIL)
      required_failed+=("$name")
      ;;
    BLOCKED)
      required_blocked+=("$name")
      ;;
    *)
      required_missing+=("$name")
      ;;
  esac
}

case "$DELIVERY_LEVEL" in
  micro_change)
    add_required_gate "L0" "$L0"
    add_required_gate "L1" "$L1"
    add_required_gate "L2" "$L2"
    add_required_gate "L3" "$L3"
    add_required_gate "DiffReviewLite" "$DIFF_REVIEW_LITE"
    ;;
  light_feature)
    add_required_gate "L0" "$L0"
    add_required_gate "L1" "$L1"
    add_required_gate "L2" "$L2"
    add_required_gate "L3" "$L3"
    add_required_gate "DiffReviewLite" "$DIFF_REVIEW_LITE"
    ;;
  high_risk_delivery)
    add_required_gate "L0" "$L0"
    add_required_gate "L1" "$L1"
    add_required_gate "L2" "$L2"
    add_required_gate "L3" "$L3"
    add_required_gate "HighRisk" "$HIGH_RISK"
    add_required_gate "Architecture" "$ARCH_GATE"
    if [ "$TYPE_REAL_ENV" = "true" ] || [ "$RISK_REAL_ENV" = "true" ]; then
      add_required_gate "Platform / Transport" "$DEVICE_GATE"
    fi
    case "$HISTORICAL_GATE" in
      PASS)
        ;;
      N/A)
        if [ "$RISK_SIMILAR_DEFECT" = "true" ]; then
          required_missing+=("Historical:N/A 不能跳过已命中的历史缺陷")
        fi
        ;;
      FAIL)
        required_failed+=("Historical")
        ;;
      BLOCKED)
        required_blocked+=("Historical")
        ;;
      *)
        required_missing+=("Historical")
        ;;
    esac
    ;;
  standard_delivery)
    add_required_gate "L0" "$L0"
    add_required_gate "L1" "$L1"
    add_required_gate "L2" "$L2"
    add_required_gate "L3" "$L3"
    ;;
  *)
    required_blocked+=("delivery_level")
    ;;
esac

if [ "$SELF_TEST_LEVEL_MISMATCH" = "true" ]; then
  required_blocked+=("self_test_level")
fi

if [ "$TYPE" = "bugfix" ] && [ "$LEGACY" != "true" ] && \
   [ "$DECISION_ACTION" = "ADVANCE" ] && [ "$DECISION_TARGET_STAGE" = "pr_review" ]; then
  if [ "${#required_missing[@]}" -gt 0 ]; then
    decision_errors+=("Self Test -> PR Review 仍有必需门禁缺失：${required_missing[*]}")
  fi
  if [ "${#required_failed[@]}" -gt 0 ]; then
    decision_errors+=("Self Test -> PR Review 仍有失败门禁：${required_failed[*]}")
  fi
  if [ "${#required_blocked[@]}" -gt 0 ]; then
    decision_errors+=("Self Test -> PR Review 仍有阻塞门禁：${required_blocked[*]}")
  fi
fi

if [ "$TYPE" = "bugfix" ] && [ "$LEGACY" != "true" ] && [ "$DECISION_ACTION" = "COMPLETE" ]; then
  if [ "${#required_missing[@]}" -gt 0 ] || [ "${#required_failed[@]}" -gt 0 ] || [ "${#required_blocked[@]}" -gt 0 ]; then
    decision_errors+=("COMPLETE 前所有当前等级必需门禁必须通过")
  fi
fi

allowed=()
forbidden_reasons=()
alignment_blocks_implement="false"

case "$STATUS" in
  requirement_breakdown)
    allowed=("requirement_breakdown" "analyze" "blocked")
    ;;
  analyze)
    allowed=("analyze" "impact_map" "blocked")
    if [ "$DELIVERY_LEVEL" = "micro_change" ]; then
      allowed=("implement" "blocked")
    elif [ "$DELIVERY_LEVEL" = "light_feature" ]; then
      allowed=("analyze" "implement" "impact_map" "blocked")
    fi
    ;;
  impact_map)
    allowed=("impact_map" "architecture" "capability" "implement" "blocked")
    ;;
  architecture|capability)
    allowed=("${STATUS}" "alignment_pending" "implement" "blocked")
    ;;
  alignment_pending)
    allowed=("alignment_pending" "blocked")
    if [ "$ALIGNMENT_STATUS" = "confirmed" ]; then
      allowed=("implement" "alignment_pending" "blocked")
    fi
    ;;
  fix_ready)
    allowed=("implement" "impact_map" "blocked")
    ;;
  implement)
    allowed=("implement" "ready_for_self_test" "blocked")
    ;;
  ready_for_self_test)
    allowed=("self_test_in_progress" "implement" "blocked")
    ;;
  validation_pending)
    allowed=("self_test_in_progress" "implement" "blocked")
    ;;
  self_test_in_progress|verify)
    allowed=("self_test_in_progress" "implement" "review" "blocked")
    if [ "${#required_missing[@]}" -gt 0 ] || [ "${#required_failed[@]}" -gt 0 ] || [ "${#required_blocked[@]}" -gt 0 ]; then
      allowed=("self_test_in_progress" "implement" "blocked")
      forbidden_reasons+=("review：VERIFY 证据不完整或存在失败门禁")
      forbidden_reasons+=("ready_for_qa：提测门禁不完整")
    elif [ "$DELIVERY_LEVEL" = "micro_change" ]; then
      allowed=("ready_for_qa" "self_test_in_progress" "implement" "blocked")
    elif [ "$DELIVERY_LEVEL" = "light_feature" ]; then
      allowed=("self_test_in_progress" "ready_for_qa" "review" "implement" "blocked")
    fi
    ;;
  review)
    allowed=("review" "implement" "ready_for_qa" "blocked")
    if [ "${#required_missing[@]}" -gt 0 ] || [ "${#required_failed[@]}" -gt 0 ] || [ "${#required_blocked[@]}" -gt 0 ]; then
      allowed=("review" "implement" "blocked")
      forbidden_reasons+=("ready_for_qa：提测门禁不完整")
    fi
    ;;
  ready_for_qa)
    allowed=("done" "commit_ready" "review")
    ;;
  done)
    allowed=("commit_ready")
    ;;
  blocked)
    allowed=("blocked" "analyze")
    ;;
  *)
    allowed=("analyze" "blocked")
    ;;
esac

if [ "$TYPE" = "bugfix" ] && [ "$LEGACY" != "true" ]; then
  if [ "${#decision_errors[@]}" -gt 0 ]; then
    allowed=("$(normalize_stage "$STATUS")")
    STAGE="$(normalize_stage "$STATUS")"
    for error in "${decision_errors[@]}"; do
      forbidden_reasons+=("decision gate：${error}")
    done
  else
    allowed=("$DECISION_ROUTED_STAGE")
    if [ -n "$STAGE_INPUT" ] && [ "$STAGE" != "$DECISION_ROUTED_STAGE" ]; then
      forbidden_reasons+=("${STAGE}：与 next_action_decision 路由 ${DECISION_ACTION} -> ${DECISION_TARGET_STAGE} 不一致")
      STAGE="$DECISION_ROUTED_STAGE"
    fi
  fi
fi

if [ "$STAGE" = "implement" ] && [ "${#risk_errors[@]}" -gt 0 ]; then
  allowed=("analyze")
  STAGE="analyze"
  for risk_error in "${risk_errors[@]}"; do
    forbidden_reasons+=("risk gate：${risk_error}")
  done
fi

if [ "$TYPE_REAL_ENV" = "true" ] && [ "$STATUS" = "impact_map" ]; then
  allowed=("capability" "architecture" "alignment_pending" "blocked")
fi

if [ "$DELIVERY_LEVEL" = "high_risk_delivery" ]; then
  case "$STATUS" in
    impact_map)
      allowed=("impact_map" "architecture" "capability" "alignment_pending" "blocked")
      ;;
    architecture|capability)
      allowed=("${STATUS}" "alignment_pending" "blocked")
      ;;
  esac
fi

if [ "$DELIVERY_LEVEL" = "missing" ]; then
  allowed=("blocked")
  forbidden_reasons+=("delivery_level：新任务必须显式填写 micro_change / light_feature / standard_delivery / high_risk_delivery，旧任务需标记 legacy 或补齐字段")
fi

if [ -n "$TYPE_DEFAULT_DELIVERY" ] && [ "$DELIVERY_LEVEL" != "$TYPE_DEFAULT_DELIVERY" ] && [ "$DELIVERY_LEVEL" != "missing" ]; then
  forbidden_reasons+=("delivery_level：${TYPE} 任务必须使用 Adapter 配置的 ${TYPE_DEFAULT_DELIVERY}")
fi

if [ "$DELIVERY_LEVEL" = "high_risk_delivery" ] && [ "$STAGE" = "implement" ] && [ "$ALIGNMENT_STATUS" != "confirmed" ]; then
  forbidden_reasons+=("implement：high_risk_delivery 必须先进入 ALIGNMENT_PENDING，并记录用户明确确认后才能实施")
  alignment_blocks_implement="true"
fi

if ! contains_word "$STAGE" "${allowed[@]}"; then
  forbidden_reasons+=("${STAGE}：不是当前阶段 status=${STATUS} 的合法下一步")
fi

if [ "$STAGE" = "commit_ready" ] && [ "$STATUS" != "review" ] && [ "$STATUS" != "done" ] && [ "$STATUS" != "ready_for_qa" ]; then
  forbidden_reasons+=("commit_ready：通常只在 PR Review 完成、READY_FOR_QA 或 DONE 后进入；本阶段只生成提交信息，等待人工提交")
fi

case "$STAGE" in
  requirement_breakdown)
    AGENT="requirement"
    AGENT_FILE="$AGENT_REQUIREMENT"
    MODE_NEXT="plan"
    ACTION="返回需求拆解阶段，只解决影响 Bug 预期行为、边界或验收的最高优先级歧义；必要时触发 \$grill-me，不得编码。"
    PASS_CONDITION="预期行为和验收边界明确，并形成新的 next_action_decision。"
    ;;
  analyze)
    case "$TYPE" in
      bugfix) AGENT="bugfix"; AGENT_FILE="$AGENT_BUGFIX"; ACTION="只基于任务卡中的确定事实分析真实调用链和根因候选，不改代码，并把分析结果回填到影响地图、证据记录、当前检查点和下一步动作。" ;;
      feature) AGENT="requirement"; AGENT_FILE="$AGENT_REQUIREMENT"; ACTION="只基于任务卡“已确认事实”和当前代码分析需求边界、影响链、验收口径和必要门禁，不改代码，并回填任务卡。PRD/任务编号/设计稿链接、Scope、Non-goals、Acceptance Criteria 为空不是阻塞；title、slug、当前打开文件和关键词搜索结果不能作为需求事实。" ;;
      techdebt) AGENT="architecture"; AGENT_FILE="$AGENT_ARCHITECTURE"; ACTION="确认是否影响真实业务链路和架构蓝图，明确旧依赖减少点、新接线点和不做范围，不改代码，并回填任务卡。" ;;
      *) AGENT="requirement"; AGENT_FILE="$AGENT_REQUIREMENT"; ACTION="按 Project Adapter 对 ${TYPE} 的定义分析真实链路、能力差异、回归范围和需要确认的问题，不改代码，并回填任务卡。" ;;
    esac
    MODE_NEXT="plan"
    PASS_CONDITION="影响地图有源码证据；未知项不被写成事实；能判断是否进入 implement / architecture / capability / blocked。"
    if [ "$DELIVERY_LEVEL" = "micro_change" ]; then
      AGENT="coding"
      AGENT_FILE="$AGENT_CODING"
      ACTION="微小改动不做完整分析；只确认目标、范围和不改变业务行为，必要时最多读取 3 个关键文件，然后进入实现。"
      PASS_CONDITION="目标、范围和验证方式足够明确；未命中强制升级条件。"
    elif [ "$DELIVERY_LEVEL" = "light_feature" ]; then
      ACTION="基于 Fast Brief 做 Quick Impact Map 和 Minimal Plan；最多聚焦当前页面、直接依赖、必要文案/跳转/时间工具，不做完整架构扫描。"
      PASS_CONDITION="Quick Impact Map 不超过 5 条；Minimal Plan 足以限制实现范围；未命中升级条件。"
    fi
    ;;
  impact_map)
    AGENT="requirement"
    AGENT_FILE="$AGENT_REQUIREMENT"
    MODE_NEXT="plan"
    ACTION="进入影响地图阶段，输出入口、真实调用链、数据流、允许改动范围、直接影响、回归范围和本次最少必须测试，不改代码。"
    PASS_CONDITION="影响地图和最小实现计划足以限制编码范围。"
    ;;
  architecture)
    AGENT="architecture"
    AGENT_FILE="$AGENT_ARCHITECTURE"
    MODE_NEXT="plan"
    ACTION="进入架构检查阶段，检查架构边界、状态真源、跨模块影响和 blocking issue，并回填任务卡。"
    PASS_CONDITION="blocking / non-blocking 结论明确；blocking issue 未解决前不得进入 IMPLEMENT。"
    ;;
  capability)
    AGENT="architecture"
    AGENT_FILE="$AGENT_ARCHITECTURE"
    MODE_NEXT="plan"
    ACTION="进入能力 / 策略检查阶段，确认 capability、strategy、profile 的 source of truth 和 blocking issue，并回填任务卡。"
    PASS_CONDITION="设备差异表达方式明确；协议 / 产品 / capability 不清时进入 BLOCKED。"
    ;;
  alignment_pending)
    AGENT="architecture"
    AGENT_FILE="$AGENT_ARCHITECTURE"
    MODE_NEXT="plan"
    ACTION="进入高风险对齐阶段。只基于任务卡、源码证据、Impact Map、Architecture / Capability 结论输出或修正高风险对齐包，记录当前状态为 ALIGNMENT_PENDING，等待用户明确确认；未确认前不得修改业务代码。"
    PASS_CONDITION="对齐包覆盖目标、已确认事实、真实调用链、拟修改范围、不修改范围、关键风险、需要人工确认的问题、最小实现方案和专项验证；用户明确回复“按方案实施 / 确认进入实现 / 对齐完成，开始改代码 / 方案确认，继续执行”后，才能把 alignment_status 更新为 confirmed 并进入 IMPLEMENT。"
    ;;
  fix_ready)
    AGENT="bugfix"
    AGENT_FILE="$AGENT_BUGFIX"
    MODE_NEXT="plan"
    ACTION="进入 FIX_READY 判定阶段。确认 Bugfix Agent 已选择唯一主路径，根因证据等级明确，最小修复方案、回归范围和验证方式足够约束 Coding Agent；若仍缺反馈闭环或关键证据，回到 DIAGNOSTIC_LOOP 或 NEEDS_CLARIFICATION，不生成 Coding Prompt。"
    PASS_CONDITION="当前状态可明确进入 IMPLEMENT；FAST_FIX / STANDARD_FIX / DIAGNOSTIC_LOOP 的输出要求已满足；没有把假设写成已确认根因。"
    ;;
  implement)
    if [ "$alignment_blocks_implement" = "true" ]; then
      AGENT="architecture"
      AGENT_FILE="$AGENT_ARCHITECTURE"
      MODE_NEXT="plan"
      ACTION="禁止进入实现阶段。当前 high_risk_delivery 尚未记录 alignment_status=confirmed，只能补充或修正高风险对齐包，并等待用户明确确认；不得修改业务代码。"
      PASS_CONDITION="任务卡进入 ALIGNMENT_PENDING；对齐包已生成；用户明确确认后记录 alignment_confirmed_at / alignment_confirmation_note，再重新请求 IMPLEMENT。"
    else
      AGENT="coding"
      AGENT_FILE="$AGENT_CODING"
      MODE_NEXT="execute"
      ACTION="进入实现阶段，只按任务卡中已确认的最小方案改代码，不扩大范围，并回填改动文件和原因。实现完成后只能写入 Implement Summary，并把当前状态更新为 READY_FOR_SELF_TEST。"
      PASS_CONDITION="代码改动完成；无无关 diff；Implement Summary 已记录；下一步只能进入 READY_FOR_SELF_TEST / SELF_TEST_IN_PROGRESS，不能直接输出提测结论。"
    fi
    ;;
  ready_for_self_test)
    AGENT="coding"
    AGENT_FILE="$AGENT_CODING"
    MODE_NEXT="execute"
    ACTION="确认 Coding Agent 已完成 Implement Summary，状态更新为 READY_FOR_SELF_TEST；不得输出 READY_FOR_QA / READY_FOR_QA_WITH_RISK / NOT_READY_FOR_QA。"
    PASS_CONDITION="任务载体包含 Implement Summary；当前状态可交给 Self Test Agent。"
    ;;
  validation_pending)
    AGENT="selftest"
    AGENT_FILE="$AGENT_SELF_TEST"
    MODE_NEXT="verify"
    ACTION="进入 VALIDATION_PENDING。根据 Bugfix Agent 定义的针对性验证或反馈闭环，执行可自动检查项，生成最小人工验证清单，并等待真实验证回填；不得把 NOT_RUN 当 PASS。"
    PASS_CONDITION="修复前后验证证据明确；DIAGNOSTIC_LOOP 必须用同一反馈闭环证明问题消失；未覆盖项和风险已记录。"
    ;;
  self_test_in_progress|verify)
    AGENT="selftest"
    AGENT_FILE="$AGENT_SELF_TEST"
    MODE_NEXT="verify"
    ACTION="进入真实自测阶段。读取当前任务载体、git diff、Impact Map / Quick Impact Map、验收标准、Implement Summary 和项目已有检查能力；判断 self_test_level=${SELF_TEST_LEVEL}，执行可自动执行的检查，生成最小人工验证清单，等待并接收人工验证回填，更新 Self Test / Evidence 后再输出最终提测结论。"
    PASS_CONDITION="必需自动检查和人工验证已有真实证据；NOT_RUN 不当作 PASS；可由 Self Test Agent 判断 READY_FOR_QA / READY_FOR_QA_WITH_RISK / NOT_READY_FOR_QA。"
    ;;
  review)
    AGENT="review"
    AGENT_FILE="$AGENT_REVIEW"
    MODE_NEXT="review"
    ACTION="进入评审阶段，检查本次改动是否扩大范围、是否存在 blocking issue、验证证据是否足够，并回填任务卡。"
    PASS_CONDITION="无 blocking issue；若有风险，能判断是否 READY_FOR_QA_WITH_RISK 或 NOT_READY_FOR_QA。"
    if [ "$DELIVERY_LEVEL" = "light_feature" ] || [ "$DELIVERY_LEVEL" = "micro_change" ]; then
      ACTION="进入 Diff Review Lite，只检查 diff 是否超出 Brief、是否有无关改动、临时日志、Mock 数据或明显回归风险。"
      PASS_CONDITION="Diff Review Lite PASS；如发现范围扩大，必须升级交付等级或回到 IMPLEMENT。"
    fi
    ;;
  i18n)
    AGENT="i18n"
    AGENT_FILE="$AGENT_I18N"
    MODE_NEXT="review"
    ACTION="进入 i18n / UI 检查阶段，只检查文案、本地化资源、UI 展示和第三方 UI 风险，并回填任务卡。"
    PASS_CONDITION="文案和 UI 风险结论明确；涉及用户可见文案时不能跳过。"
    ;;
  ready_for_qa)
    AGENT="selftest"
    AGENT_FILE="$AGENT_SELF_TEST"
    MODE_NEXT="verify"
    ACTION="进入提测判定阶段，基于 L0/L1/L2/L3/高风险专项门禁和评审证据输出提测结论：READY_FOR_QA / READY_FOR_QA_WITH_RISK / NOT_READY_FOR_QA。"
    PASS_CONDITION="提测结论只能三选一；禁止用理论可用代替真实证据。"
    ;;
  done)
    AGENT="review"
    AGENT_FILE="$AGENT_REVIEW"
    MODE_NEXT="review"
    ACTION="进入完成阶段，确认任务卡证据完整，将状态更新为 done，并输出改动文件、原因、验证结果和剩余风险。"
    PASS_CONDITION="任务卡已形成可恢复闭环；如需提交信息，进入 COMMIT_READY，由 Commit Agent 生成可复制 Commit 信息。"
    ;;
  commit_ready)
    AGENT="commit"
    AGENT_FILE="$AGENT_COMMIT"
    MODE_NEXT="review"
    ACTION="进入 COMMIT_READY。Commit Agent 只基于当前 diff、task card、自测结果、PR Review 结论和 Project Adapter commit 规则生成可复制 Commit 信息；不得执行 git add / git commit / git push，不得修改暂存内容，等待人工手动提交。"
    PASS_CONDITION="Commit 信息与实际 diff、QA 结论和 Project Adapter commit 规则一致，并明确是否满足提交前置条件。"
    ;;
  blocked)
    AGENT="router"
    AGENT_FILE="$AGENT_ROUTER"
    MODE_NEXT="discuss"
    ACTION="当前任务处于 blocked。读取阻塞项、证据记录、当前检查点，给出最小解除阻塞问题，不改代码。"
    PASS_CONDITION="阻塞项明确到一个最小人工决策问题。"
    ;;
  *)
    echo "Unknown stage: ${STAGE}"
    usage
    exit 1
    ;;
esac

case "$DELIVERY_LEVEL" in
  micro_change)
    DELIVERY_GUIDANCE="L1 快速路径：不创建完整 Impact Map，不跑 Architecture 和正式 Review；只验证修改目标、一个主要相邻场景和 Diff Review Lite。发现接口、共享状态、多模块、历史缺陷或范围不清时必须 ESCALATE。"
    ;;
  light_feature)
    DELIVERY_GUIDANCE="L1 快速路径：使用 Fast Brief、Quick Impact Map、Minimal Plan、Targeted Self Test 和 Diff Review Lite；不默认读取完整架构文档或缺陷 Memory。必须验证修改目标和一个主要相邻场景。"
    ;;
  high_risk_delivery)
    DELIVERY_GUIDANCE="L3 稳健路径：定向检索相关缺陷 Memory，完成 Change Impact Analysis、Architecture、Regression Self Test 和正式 Review；只加载命中的缺陷卡，不加载全部历史。IMPLEMENT 前必须完成高风险对齐。"
    ;;
  standard_delivery)
    DELIVERY_GUIDANCE="L2 标准路径：复用根因和影响地图，执行原问题、主要相邻场景、静态检查和正式 Review；仅有同类缺陷线索时定向检索 Memory。"
    ;;
  *)
    DELIVERY_GUIDANCE="delivery_level 缺失：新任务不得静默按标准需求执行，必须补齐交付等级或标记 legacy 后再继续。"
    ;;
esac

case "$CURRENT_DELIVERY_TIER" in
  L1)
    CONTEXT_BUDGET="极简：只读任务摘要、目标文件、直接依赖和上游决策；Owner 摘要最多 5 条，不重复读取完整架构文档。"
    ;;
  L2)
    CONTEXT_BUDGET="标准：读取任务卡、上游证据、目标调用链和必要架构片段；复用已确认根因，不从零重复调查。"
    ;;
  L3)
    CONTEXT_BUDGET="完整证据但定向加载：任务卡、相关架构片段、最多 5 张命中缺陷卡和目标代码；禁止加载全部缺陷 Memory、全部 ADR 或全部 handoff。"
    ;;
  *)
    CONTEXT_BUDGET="未知：先补齐 delivery_level，不开始扩大上下文。"
    ;;
esac

if [ "$DELIVERY_LEVEL" = "micro_change" ] || [ "$DELIVERY_LEVEL" = "light_feature" ]; then
  PROMPT_INTRO="按 ${TASK_FILE} 的轻量任务载体推进，不默认加载完整 Workflow 或完整 Agent 大文档。"
  REQUIRED_DOCS="- ${PROJECT_RULES}
- ${TASK_FILE}"
else
  PROMPT_INTRO="按 ${WORKFLOW} 和 ${TASK_FILE} 跑 ${LOOP_NAME}。
使用 ${AGENT_FILE}。"
  REQUIRED_DOCS="- ${PROJECT_RULES}
- ${WORKFLOW}
- ${TASK_FILE}
- ${AGENT_FILE}"
fi

if [ "$STAGE" = "alignment_pending" ] || [ "$alignment_blocks_implement" = "true" ]; then
  REQUIRED_DOCS="${REQUIRED_DOCS}
- ${HIGH_RISK_ALIGNMENT_TEMPLATE}"
fi

if [ "$CURRENT_DELIVERY_TIER" = "L3" ]; then
  REQUIRED_DOCS="${REQUIRED_DOCS}
- ${AI_ROOT}/defect_memory/README.md
- 仅 ai_defect_memory_search.sh 命中的缺陷卡（最多 5 张）"
fi

DISPLAY_STAGE="$STAGE"
if [ "$alignment_blocks_implement" = "true" ]; then
  DISPLAY_STAGE="alignment_pending"
fi

cat <<EOF
# AI Loop 下一步

## 当前状态
- 任务卡：${TASK_FILE}
- 类型：${TYPE}
- 业务优先级：${PRIORITY}
- 交付等级：${DELIVERY_LEVEL}
- 交付强度：${CURRENT_DELIVERY_TIER}
- 自测等级：${SELF_TEST_LEVEL}
- 是否需要高风险对齐：${ALIGNMENT_REQUIRED}
- 当前对齐状态：${ALIGNMENT_STATUS}
- 对齐确认时间：${ALIGNMENT_CONFIRMED_AT:-无}
- 对齐确认记录：${ALIGNMENT_CONFIRMATION_NOTE:-无}
- 风险：${RISK}
- 模式：${MODE}
- 阶段：${STATUS:-unknown}
- 提测状态：${QA_STATUS}
- 迭代：${ITERATION}/${MAX_ITERATIONS}
- 旧格式任务卡：${LEGACY}

## 风险自适应路由
- 风险信号是否已填写：${RISK_SIGNALS_PRESENT}
- 建议交付强度：${RISK_RECOMMENDED_TIER}
- 当前是否需要升级：${RISK_ESCALATION_REQUIRED}
- L3 风险信号：${high_risk_signals[*]:-无}
- L2 风险信号：${ordinary_risk_signals[*]:-无}
- 风险 Gate 错误：
$(print_words "${risk_errors[@]}")

## 门禁快照
- L0 变更范围检查：${L0}
- L1 基础可运行检查：${L1}
- L2 本功能验证：${L2}
- L3 直接影响回归：${L3}
- 高风险专项：${HIGH_RISK}
- Diff Review Lite：${DIFF_REVIEW_LITE}
- Architecture Gate：${ARCH_GATE}
- Platform / Transport Gate：${DEVICE_GATE}
- Historical Regression Gate：${HISTORICAL_GATE}

## Bugfix 下一步决策
- 当前阶段：${DECISION_CURRENT_STAGE:-MISSING}
- 动作：${DECISION_ACTION:-MISSING}
- 目标阶段：${DECISION_TARGET_STAGE:-MISSING}
- 脚本路由阶段：${DECISION_ROUTED_STAGE:-MISSING}
- 决策原因：${DECISION_REASON:-MISSING}
- 升级前 delivery_level：${DECISION_ESCALATE_FROM:-N/A}
- 升级后 delivery_level：${DECISION_ESCALATE_TO:-N/A}
- 触发风险信号：${DECISION_TRIGGERED_RISKS:-N/A}

## 决策协议错误
$(print_words "${decision_errors[@]}")

## 缺失门禁
$(print_words "${missing_gates[@]}")

## 失败门禁
$(print_words "${failed_gates[@]}")

## 阻塞门禁
$(print_words "${blocked_gates[@]}")

## 当前等级必需门禁缺失
$(print_words "${required_missing[@]}")

## 当前等级必需门禁失败
$(print_words "${required_failed[@]}")

## 当前等级必需门禁阻塞
$(print_words "${required_blocked[@]}")

## 合法下一步
$(print_words "${allowed[@]}")

## 流程成本规则
${DELIVERY_GUIDANCE}

## 上下文预算
${CONTEXT_BUDGET}

## 禁止进入 / 警告
$(print_words "${forbidden_reasons[@]}")

## 本次选择阶段
- 阶段：${DISPLAY_STAGE}
- 模式：${MODE_NEXT}
- Workflow：${WORKFLOW}
- Agent：${AGENT}
- Agent 文件：${AGENT_FILE}

## 可复制 Prompt

${PROMPT_INTRO}
当前模式：${MODE_NEXT}。
当前阶段：${DISPLAY_STAGE}。
当前业务优先级：${PRIORITY}。
当前交付等级：${DELIVERY_LEVEL}。
当前交付强度：${CURRENT_DELIVERY_TIER}。
当前自测等级：${SELF_TEST_LEVEL}。
流程成本规则：${DELIVERY_GUIDANCE}
上下文预算：${CONTEXT_BUDGET}
本阶段目标：${ACTION}

必读资料：
${REQUIRED_DOCS}

禁止事项：
- 不把任务卡之外的聊天猜测当作确定事实。
- 不把 title、slug、当前打开文件、关键词搜索结果当作需求事实。
- 不因为 Scope、Non-goals、Acceptance Criteria 或 PRD/设计稿链接为空就判定任务卡不可分析。
- 不把轻量路径理解成跳过质量；轻量路径只是让小任务只承担它应有的流程成本。
- 不重复加载完整 PRD、全部 ADR、全部 handoff 或全部缺陷 Memory。
- 优先复用上游已确认的根因、真源、修改范围和验证目标。
- 不把 NOT_RUN 当作 PASS。
- 不跳过失败或缺失的 Gate。
- 不扩大 Impact Map 和 Minimal Implementation Plan 之外的改动范围。
- 不修改无关业务代码。
- high_risk_delivery 在 alignment_status 不是 confirmed 前，不得进入 IMPLEMENT，不得修改业务代码。
- Coding Agent 完成实现后不得直接输出提测结论，必须进入 READY_FOR_SELF_TEST。
- Self Test Agent 必须读取真实 git diff，不能只根据需求文案猜测测试范围。
- 需要人工验证时，必须输出最小人工验证清单并等待回填。

需要更新的任务卡字段：
- status / mode / qa_status，如阶段推进需要
- alignment_required / alignment_status / alignment_confirmed_at / alignment_confirmation_note，如涉及高风险对齐
- 影响地图（Impact Map）/ 最小实现计划（Minimal Implementation Plan），如本阶段产生新结论
- 高风险对齐包（High Risk Alignment Package），如 delivery_level=high_risk_delivery
- 必要门禁（Required Gates）/ 提测门禁结果（QA Gate Results）
- Implement Summary / Self Test Result，如本阶段涉及
- Bugfix 诊断证据 / Bugfix 自测证据 / 下一步决策，如 type=bugfix
- 交付风险信号；L3 还需更新缺陷 Memory 检索和 Change Impact Analysis
- 证据记录（Evidence）
- 已知风险 / 未测项（Known Risks / Untested Items）
- 当前检查点（Current Checkpoint）
- 下一步动作（Next Action）
- Loop Closeout（当前状态、是否 Done、Done 依据、唯一下一步、是否需要 Owner 输入）
- 流程成本记录（最终强度、实际 Agent、跳过阶段、Memory 卡数量、证据复用、ESCALATE）
- Loop 记录（Loop Log）

进入下一阶段判定条件：
${PASS_CONDITION}

升级条件：
- 发现跨模块共享状态。
- 需要修改接口、存储、全局状态。
- 修改范围明显超过 Brief / Task Card。
- 需求规则无法确认。
- 无法完成关键验证。
- 影响 Project Adapter 声明的高风险平台能力、transport、升级或数据链路。
- 影响公共基础组件且回归范围扩大。

收尾要求：
- 最终回复末尾必须输出 "## Loop Closeout"。
- "当前状态" 必须写本阶段结束后的真实状态。
- "是否 Done" 只能写“是”或“否”。
- 如果 "是否 Done=是"，"唯一下一步" 必须写“无”，并写清 Done 依据。
- 如果 "是否 Done=否"，"唯一下一步" 必须只写一个可执行动作，不能写“继续下一步”。
- "是否需要 Owner 输入" 必须明确写“是 / 否”和原因。
- "READY_FOR_SELF_TEST"、"READY_FOR_QA"、"COMMIT_READY"、"BLOCKED" 默认都不是 DONE；只有本轮目标已经闭环，或用户明确本轮到此结束，才可写 "DONE"。

## 可选：完整 Agent 上下文

如果你想把完整 agent 文件和 task card 一起复制给 AI，可以运行：

./ai/tool/ai_agent.sh ${AGENT} ${TASK_FILE}
EOF
