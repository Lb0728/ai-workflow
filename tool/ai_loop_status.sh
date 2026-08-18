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
NEXT_SCRIPT="${SCRIPT_DIR}/ai_loop_next.sh"

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

TASKS_DIR="$(
  "$LOADER" \
    --project-root "$PROJECT_ROOT" \
    --adapter "$ADAPTER_ID" \
    --role "$ROLE_ID" \
    resolve runtime.tasks
)"

usage() {
  cat <<EOF
Usage: ./ai/tool/ai_loop_status.sh <task-or-brief-path>

Examples:
  ./ai/tool/ai_loop_status.sh <runtime-task>
EOF
}

TASK_INPUT="$1"

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

print_section_preview() {
  local heading="$1"
  local file="$2"
  awk -v heading="## ${heading}" '
    index($0, heading) == 1 && length($0) == length(heading) { in_section = 1; count = 0; next }
    in_section && /^## / { exit }
    in_section && count < 12 {
      print
      count += 1
    }
  ' "$file" | sed '/^[[:space:]]*$/d'
}

section_content() {
  local heading="$1"
  local file="$2"
  awk -v heading="## ${heading}" '
    index($0, heading) == 1 && length($0) == length(heading) { in_section = 1; next }
    in_section && /^## / { exit }
    in_section { print }
  ' "$file"
}

section_field_value() {
  local section="$1"
  local field="$2"
  local file="$3"
  section_content "$section" "$file" | awk -F'：|:' -v field="$field" '
    $1 ~ "^[[:space:]]*-?[[:space:]]*" field "$" {
      sub(/^[[:space:]]+/, "", $2)
      sub(/[[:space:]]+$/, "", $2)
      print $2
      exit
    }
  '
}

print_loop_closeout_warnings() {
  local file="$1"
  local closeout
  local done_value
  local next_action
  local owner_input
  local has_warn=0

  closeout="$(section_content "Loop Closeout" "$file" | sed '/^[[:space:]]*$/d')"
  done_value="$(section_field_value "Loop Closeout" "是否 Done" "$file")"
  next_action="$(section_field_value "Loop Closeout" "唯一下一步" "$file")"
  owner_input="$(section_field_value "Loop Closeout" "是否需要 Owner 输入" "$file")"

  if [ -z "$closeout" ]; then
    echo "- WARN: 缺少 Loop Closeout；Owner 无法判断当前是否真正 Done。"
    return 0
  fi

  if [ -z "$done_value" ]; then
    echo "- WARN: Loop Closeout 缺少“是否 Done”。"
    has_warn=1
  elif [ "$done_value" != "是" ] && [ "$done_value" != "否" ]; then
    echo "- WARN: Loop Closeout 的“是否 Done”只能写“是”或“否”，当前为：${done_value}"
    has_warn=1
  fi

  if [ -z "$next_action" ]; then
    echo "- WARN: Loop Closeout 缺少“唯一下一步”。"
    has_warn=1
  elif [ "$done_value" = "是" ] && [ "$next_action" != "无" ]; then
    echo "- WARN: 已标记 Done 时，“唯一下一步”应为“无”。"
    has_warn=1
  elif [ "$done_value" = "否" ]; then
    case "$next_action" in
      "无"|*"继续下一步"*|*"继续"*|*"待定"*|*"N/A"*|*"n/a"*)
        echo "- WARN: 未 Done 时，“唯一下一步”必须是一个具体可执行动作，当前为：${next_action}"
        has_warn=1
        ;;
    esac
  fi

  if [ -z "$owner_input" ]; then
    echo "- WARN: Loop Closeout 缺少“是否需要 Owner 输入”。"
    has_warn=1
  fi

  if [ "$has_warn" = "0" ]; then
    echo "- OK"
  fi
}

first_non_empty_from_next_section() {
  local heading="$1"
  printf '%s\n' "$NEXT_OUTPUT" | awk -v heading="$heading" '
    index($0, heading) == 1 && length($0) == length(heading) { in_section = 1; next }
    in_section && /^## / { exit }
    in_section && $0 !~ /^[[:space:]]*$/ {
      sub(/^[[:space:]]*-[[:space:]]*/, "", $0)
      print
      exit
    }
  '
}

closeout_warning_count() {
  local file="$1"
  print_loop_closeout_warnings "$file" | grep -c "WARN" || true
}

if ! TASK_FILE="$(resolve_task_file "$TASK_INPUT")"; then
  echo "Task file not found: ${TASK_INPUT}"
  exit 1
fi

TASK_ID="$(read_frontmatter_value task_id "$TASK_FILE")"
TITLE="$(read_frontmatter_value title "$TASK_FILE")"
TYPE="$(read_frontmatter_value type "$TASK_FILE")"
PRIORITY="$(read_frontmatter_value priority "$TASK_FILE")"
DELIVERY_LEVEL="$(read_frontmatter_value delivery_level "$TASK_FILE")"
SELF_TEST_LEVEL="$(read_frontmatter_value self_test_level "$TASK_FILE")"
ALIGNMENT_REQUIRED="$(read_frontmatter_value alignment_required "$TASK_FILE")"
ALIGNMENT_STATUS="$(read_frontmatter_value alignment_status "$TASK_FILE")"
ALIGNMENT_CONFIRMED_AT="$(read_frontmatter_value alignment_confirmed_at "$TASK_FILE")"
ALIGNMENT_CONFIRMATION_NOTE="$(read_frontmatter_value alignment_confirmation_note "$TASK_FILE")"
MODE="$(read_frontmatter_value mode "$TASK_FILE")"
STATUS="$(read_frontmatter_value status "$TASK_FILE")"
QA_STATUS="$(read_frontmatter_value qa_status "$TASK_FILE")"
ITERATION="$(read_frontmatter_value iteration "$TASK_FILE")"
MAX_ITERATIONS="$(read_frontmatter_value max_iterations "$TASK_FILE")"
LEGACY="$(read_frontmatter_value legacy "$TASK_FILE")"

if [ -z "$LEGACY" ]; then
  if grep -q '^## 下一步决策$' "$TASK_FILE"; then
    LEGACY="false"
  else
    LEGACY="true"
  fi
fi

NEXT_OUTPUT="$("$NEXT_SCRIPT" "$TASK_FILE")"

if [ "$DELIVERY_LEVEL" = "high_risk_delivery" ]; then
  if [ -z "$ALIGNMENT_REQUIRED" ]; then ALIGNMENT_REQUIRED="true"; fi
  if [ -z "$ALIGNMENT_STATUS" ]; then ALIGNMENT_STATUS="pending"; fi
else
  if [ -z "$ALIGNMENT_REQUIRED" ]; then ALIGNMENT_REQUIRED="false"; fi
  if [ -z "$ALIGNMENT_STATUS" ]; then ALIGNMENT_STATUS="not_required"; fi
fi

if [ "$ALIGNMENT_REQUIRED" = "true" ] && [ "$ALIGNMENT_STATUS" != "confirmed" ]; then
  ALLOW_IMPLEMENT="否"
else
  ALLOW_IMPLEMENT="是"
fi

CLOSEOUT_STATUS="$(section_field_value "Loop Closeout" "当前状态" "$TASK_FILE")"
CLOSEOUT_DONE="$(section_field_value "Loop Closeout" "是否 Done" "$TASK_FILE")"
CLOSEOUT_NEXT="$(section_field_value "Loop Closeout" "唯一下一步" "$TASK_FILE")"
CLOSEOUT_OWNER="$(section_field_value "Loop Closeout" "是否需要 Owner 输入" "$TASK_FILE")"
CLOSEOUT_WARN_COUNT="$(closeout_warning_count "$TASK_FILE")"
NEXT_STAGE="$(first_non_empty_from_next_section "## 合法下一步")"
FORBIDDEN_REASON="$(first_non_empty_from_next_section "## 禁止进入 / 警告")"
BLOCKED_REASON="$(first_non_empty_from_next_section "## 当前等级必需门禁阻塞")"
MISSING_REASON="$(first_non_empty_from_next_section "## 当前等级必需门禁缺失")"
FAILED_REASON="$(first_non_empty_from_next_section "## 当前等级必需门禁失败")"

if [ -z "$CLOSEOUT_DONE" ]; then
  SUMMARY_DONE="未知"
else
  SUMMARY_DONE="$CLOSEOUT_DONE"
fi

if [ -n "$CLOSEOUT_NEXT" ]; then
  SUMMARY_NEXT="$CLOSEOUT_NEXT"
elif [ -n "$NEXT_STAGE" ]; then
  SUMMARY_NEXT="进入 ${NEXT_STAGE}"
else
  SUMMARY_NEXT="未计算到合法下一步"
fi

if [ "$CLOSEOUT_WARN_COUNT" != "0" ]; then
  SUMMARY_BLOCKER="Loop Closeout 缺失或不完整"
elif [ "$ALLOW_IMPLEMENT" = "否" ]; then
  SUMMARY_BLOCKER="高风险对齐未确认"
elif [ -n "$BLOCKED_REASON" ]; then
  SUMMARY_BLOCKER="$BLOCKED_REASON"
elif [ -n "$FAILED_REASON" ]; then
  SUMMARY_BLOCKER="$FAILED_REASON"
elif [ -n "$MISSING_REASON" ]; then
  SUMMARY_BLOCKER="$MISSING_REASON"
elif [ -n "$FORBIDDEN_REASON" ]; then
  SUMMARY_BLOCKER="$FORBIDDEN_REASON"
else
  SUMMARY_BLOCKER="无明确阻塞"
fi

if [ -z "$CLOSEOUT_OWNER" ]; then
  SUMMARY_OWNER_INPUT="未知"
else
  SUMMARY_OWNER_INPUT="$CLOSEOUT_OWNER"
fi

echo "# AI Loop 状态检查"
echo
echo "## 顶部摘要"
echo "- 是否 Done：${SUMMARY_DONE}"
echo "- 当前状态：${CLOSEOUT_STATUS:-${STATUS:-unknown}}"
echo "- 当前卡点：${SUMMARY_BLOCKER}"
echo "- 唯一下一步：${SUMMARY_NEXT}"
echo "- 是否需要 Owner 输入：${SUMMARY_OWNER_INPUT}"
echo
echo "## 任务"
echo "- 文件：${TASK_FILE}"
echo "- 任务名称：${TASK_ID:-unknown} ${TITLE:-}"
echo "- 类型：${TYPE:-unknown}"
echo "- 业务优先级：${PRIORITY:-UNKNOWN}"
echo "- 交付等级：${DELIVERY_LEVEL:-MISSING}"
echo "- 自测等级：${SELF_TEST_LEVEL:-MISSING}"
echo "- 是否需要高风险对齐：${ALIGNMENT_REQUIRED:-MISSING}"
echo "- 当前对齐状态：${ALIGNMENT_STATUS:-MISSING}"
echo "- 模式 / 阶段：${MODE:-unknown} / ${STATUS:-unknown}"
echo "- 提测状态：${QA_STATUS:-unknown}"
echo "- 迭代：${ITERATION:-0}/${MAX_ITERATIONS:-unknown}"
echo "- legacy：${LEGACY:-unknown}"
echo
echo "## 评分与强制升级"
grep -E "^- 是否命中强制升级：|^- 评分明细：|^- 原交付等级 / 调整后交付等级 / 调整原因：|^- 选择原因：" "$TASK_FILE" || echo "- 未记录"
echo
echo "## 风险自适应"
print_section_preview "交付风险信号" "$TASK_FILE"
printf '%s\n' "$NEXT_OUTPUT" | awk '
  $0 == "## 风险自适应路由" { in_section = 1; next }
  in_section && /^## / { exit }
  in_section { print }
'
echo
echo "## 高风险对齐"
echo "- 是否需要人工对齐：${ALIGNMENT_REQUIRED:-MISSING}"
echo "- 当前对齐状态：${ALIGNMENT_STATUS:-MISSING}"
echo "- 用户确认时间：${ALIGNMENT_CONFIRMED_AT:-无}"
echo "- 用户确认记录：${ALIGNMENT_CONFIRMATION_NOTE:-无}"
echo "- 是否允许 IMPLEMENT：${ALLOW_IMPLEMENT}"
print_section_preview "高风险对齐" "$TASK_FILE"
echo
echo "## 已完成 Gate"
grep -E "^[[:space:]]*- .*Gate[^:]*:[[:space:]]*PASS" "$TASK_FILE" || echo "- 无"
echo
echo "## 缺失 Gate"
grep -E "^[[:space:]]*- .*Gate[^:]*:[[:space:]]*(NOT_RUN|PENDING|MISSING)" "$TASK_FILE" || echo "- 无"
echo
echo "## 失败 / 阻塞 Gate"
grep -E "^[[:space:]]*- .*Gate[^:]*:[[:space:]]*(FAIL|BLOCKED)" "$TASK_FILE" || echo "- 无"
echo
echo "## 未测风险"
print_section_preview "已知风险 / 未测项" "$TASK_FILE"
print_section_preview "提测结论" "$TASK_FILE"
echo
echo "## Self Test"
print_section_preview "Self Test" "$TASK_FILE"
print_section_preview "Self Test Result" "$TASK_FILE"
print_section_preview "Bugfix 自测证据" "$TASK_FILE"
echo
echo "## Bugfix 动态路由"
print_section_preview "Bugfix 诊断证据" "$TASK_FILE"
print_section_preview "下一步决策" "$TASK_FILE"
printf '%s\n' "$NEXT_OUTPUT" | awk '
  $0 == "## 决策协议错误" { in_section = 1; next }
  in_section && /^## / { exit }
  in_section { print }
'
echo
echo "## 缺陷 Memory / Change Impact"
print_section_preview "缺陷 Memory 检索" "$TASK_FILE"
print_section_preview "Change Impact Analysis" "$TASK_FILE"
echo
echo "## 流程成本"
print_section_preview "流程成本记录" "$TASK_FILE"
echo
echo "## Loop Closeout"
print_section_preview "Loop Closeout" "$TASK_FILE"
echo
echo "## Loop Closeout 检查"
print_loop_closeout_warnings "$TASK_FILE"
echo
echo "## 自动检查 / 人工验证"
grep -E "automatic_checks:|manual_checks:|evidence:|gate_status:|untested_items:|known_risks:|release_result:" "$TASK_FILE" || echo "- 未记录"
echo
echo "## 阻塞提测原因"
printf '%s\n' "$NEXT_OUTPUT" | awk '
  $0 == "## 当前等级必需门禁缺失" { section = "missing"; next }
  $0 == "## 当前等级必需门禁失败" { section = "failed"; next }
  $0 == "## 当前等级必需门禁阻塞" { section = "blocked"; next }
  /^## / { section = "" }
  section != "" { print }
' | sed '/^- 无$/d' || true
echo
echo "## 合法下一步"
printf '%s\n' "$NEXT_OUTPUT" | awk '
  $0 == "## 合法下一步" { in_section = 1; next }
  in_section && /^## / { exit }
  in_section { print }
'
echo
echo "## 禁止进入的阶段及原因"
printf '%s\n' "$NEXT_OUTPUT" | awk '
  $0 == "## 禁止进入 / 警告" { in_section = 1; next }
  in_section && /^## / { exit }
  in_section { print }
'
echo
echo "## 是否需要升级"
printf '%s\n' "$NEXT_OUTPUT" | awk '
  $0 == "升级条件：" { in_section = 1; print; next }
  in_section && /^## / { exit }
  in_section && $0 == "收尾要求：" { exit }
  in_section { print }
'
echo
echo "## 新会话恢复优先读取"
echo "- AGENTS.md"
echo "- ${TASK_FILE}"
echo "- 当前检查点 / 下一步动作 / Gate 结果"
echo "- 必要时再读取 ai/workflows 或 ai/agents 中本阶段对应文件"
