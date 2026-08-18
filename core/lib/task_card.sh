#!/usr/bin/env bash
# Task Card validation library — enforces core/schemas/task-card.schema.yaml
# against a task file. Enum sources live in core/config/state-machine.yaml.
#
# Consumers source this file and call tc_validate. The library does not set
# -e/-u (option flags belong to the sourcing consumer).
#
# tc_validate <task-file>
#   prints "- <violation>" lines for each violation
#   exits 0 when the card is valid, 1 when violations exist
#   legacy: true cards skip strict validation (Router legacy path)

_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${_LIB_DIR}/state_machine.sh"

# Read one frontmatter key (same parsing contract as finish.sh / transition.sh).
tc_frontmatter() {
  local task_file="$1"
  local key="$2"
  awk -F': *' -v k="$key" '$0=="---"{n++;next} n==1 && $1==k{print $2;exit}' "$task_file" | tr -d "'\""
}

# 1 when the task file contains `## <header>`.
tc_has_section() {
  local task_file="$1"
  local header="$2"
  grep -q "^## ${header}$" "$task_file" && printf 'yes\n' || printf 'no\n'
}

tc_validate() {
  local task_file="$1"
  local violations=()
  local legacy type delivery status self_test_level priority
  local iteration max_iterations alignment_required alignment_status
  local confirmed_at note norm

  [ -f "$task_file" ] || {
    printf -- "- 任务卡文件不存在: %s\n" "$task_file"
    return 1
  }

  # V2 cards must start with a `---` frontmatter block; files without one
  # are legacy-format cards and skip strict validation.
  if [ "$(head -n 1 "$task_file")" != "---" ]; then
    return 0
  fi

  legacy="$(tc_frontmatter "$task_file" legacy | tr '[:upper:]' '[:lower:]')"
  if [ "$legacy" = "true" ]; then
    return 0
  fi

  type="$(tc_frontmatter "$task_file" type | tr '[:upper:]' '[:lower:]')"
  delivery="$(tc_frontmatter "$task_file" delivery_level | tr '[:upper:]' '[:lower:]')"
  status="$(tc_frontmatter "$task_file" status | tr '[:upper:]' '[:lower:]')"
  self_test_level="$(tc_frontmatter "$task_file" self_test_level | tr '[:upper:]' '[:lower:]')"
  priority="$(tc_frontmatter "$task_file" priority | tr '[:lower:]' '[:upper:]')"
  iteration="$(tc_frontmatter "$task_file" iteration)"
  max_iterations="$(tc_frontmatter "$task_file" max_iterations)"
  alignment_required="$(tc_frontmatter "$task_file" alignment_required | tr '[:upper:]' '[:lower:]')"
  alignment_status="$(tc_frontmatter "$task_file" alignment_status | tr '[:upper:]' '[:lower:]')"
  confirmed_at="$(tc_frontmatter "$task_file" alignment_confirmed_at)"
  note="$(tc_frontmatter "$task_file" alignment_confirmation_note)"

  # --- frontmatter enums ------------------------------------------------
  if [ -z "$type" ]; then
    violations+=("type 缺失")
  elif ! sm_is_valid_task_type "$type"; then
    violations+=("type 非法: ${type}")
  fi

  if [ -z "$delivery" ]; then
    violations+=("delivery_level 缺失")
  elif ! sm_is_valid_delivery_level "$delivery"; then
    violations+=("delivery_level 非法: ${delivery}")
  fi

  if [ -n "$status" ]; then
    norm="$(sm_normalize_stage "$status")"
    if ! sm_is_stage "$norm"; then
      violations+=("status 非法: ${status}")
    fi
  fi

  if [ -n "$self_test_level" ] && ! sm_is_valid_self_test_level "$self_test_level"; then
    violations+=("self_test_level 非法: ${self_test_level}")
  fi

  if [ -n "$priority" ] && ! sm_is_valid_priority "$priority"; then
    violations+=("priority 非法: ${priority}")
  fi

  case "$iteration" in
    ''|*[!0-9]*) [ -n "$iteration" ] && violations+=("iteration 必须是非负整数: ${iteration}") ;;
  esac
  case "$max_iterations" in
    ''|*[!0-9]*) [ -n "$max_iterations" ] && violations+=("max_iterations 必须是非负整数: ${max_iterations}") ;;
  esac

  # --- high_risk_delivery rules -----------------------------------------
  if [ "$delivery" = "high_risk_delivery" ]; then
    if [ "$(tc_has_section "$task_file" '交付风险信号')" != "yes" ]; then
      violations+=("high_risk_delivery 必须填写交付风险信号")
    fi
    if [ "$alignment_required" != "true" ]; then
      violations+=("high_risk_delivery 必须设置 alignment_required=true")
    fi
    if [ "$self_test_level" != "specialized" ]; then
      violations+=("high_risk_delivery 的 self_test_level 必须为 specialized")
    fi
    case "$alignment_status" in
      pending|confirmed) ;;
      *) violations+=("alignment_status 只能为 pending / confirmed: ${alignment_status:-空}") ;;
    esac
    norm="$(sm_normalize_stage "$status")"
    if [ "$norm" = "implement" ]; then
      if [ "$alignment_status" != "confirmed" ]; then
        violations+=("status=implement 需要 alignment_status=confirmed")
      fi
      if [ -z "$confirmed_at" ]; then
        violations+=("status=implement 需要 alignment_confirmed_at")
      fi
      if [ -z "$note" ]; then
        violations+=("status=implement 需要 alignment_confirmation_note")
      fi
    fi
  fi

  if [ "${#violations[@]}" -gt 0 ]; then
    for violation in "${violations[@]}"; do
      printf -- "- %s\n" "$violation"
    done
    return 1
  fi
  return 0
}
