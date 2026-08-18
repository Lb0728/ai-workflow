#!/usr/bin/env bash
set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WORKFLOW_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
PROJECT_ROOT="$(pwd)"
HOST_ID=""
POSITIONAL=()
APPLY=false
VERBOSE=false

usage() {
  printf '%s\n' "Usage: ai-workflow next [--apply] [--verbose] [--project-root <path>] [--host <id>] <task-file> [stage]"
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
    --apply)
      APPLY=true
      shift
      ;;
    --verbose)
      VERBOSE=true
      shift
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

[ "${#POSITIONAL[@]}" -ge 1 ] || { usage >&2; exit 2; }
[ "${#POSITIONAL[@]}" -le 2 ] || { usage >&2; exit 2; }

if [ "$APPLY" = true ]; then
  [ "${#POSITIONAL[@]}" -eq 1 ] || { printf '%s\n' "ERROR --apply does not accept an explicit stage" >&2; exit 2; }
  transition_args=(--project-root "$PROJECT_ROOT")
  [ -n "$HOST_ID" ] && transition_args+=(--host "$HOST_ID")
  "${WORKFLOW_ROOT}/cli/commands/transition.sh" "${transition_args[@]}" "${POSITIONAL[0]}"
  exit 0
fi

if [ -n "$HOST_ID" ]; then
  RUN_ARGS=(env AI_PROJECT_ROOT="$PROJECT_ROOT" AI_HOST_ID="$HOST_ID")
else
  RUN_ARGS=(env AI_PROJECT_ROOT="$PROJECT_ROOT")
fi

if [ "$VERBOSE" = true ]; then
  exec "${RUN_ARGS[@]}" "${WORKFLOW_ROOT}/core/router/ai_loop_next_v2.sh" "${POSITIONAL[@]}"
fi

TMP_OUTPUT="$(mktemp "${TMPDIR:-/tmp}/ai-workflow-next.XXXXXX")"
trap 'rm -f "$TMP_OUTPUT"' EXIT

"${RUN_ARGS[@]}" "${WORKFLOW_ROOT}/core/router/ai_loop_next_v2.sh" "${POSITIONAL[@]}" > "$TMP_OUTPUT"

awk '
  index($0, "## 风险自适应路由") == 1 && length($0) == length("## 风险自适应路由") ||
  index($0, "## 门禁快照") == 1 && length($0) == length("## 门禁快照") ||
  index($0, "## Bugfix 下一步决策") == 1 && length($0) == length("## Bugfix 下一步决策") ||
  index($0, "## 决策协议错误") == 1 && length($0) == length("## 决策协议错误") ||
  index($0, "## 缺失门禁") == 1 && length($0) == length("## 缺失门禁") ||
  index($0, "## 失败门禁") == 1 && length($0) == length("## 失败门禁") ||
  index($0, "## 阻塞门禁") == 1 && length($0) == length("## 阻塞门禁") ||
  index($0, "## 带风险门禁") == 1 && length($0) == length("## 带风险门禁") ||
  index($0, "## 当前等级必需门禁缺失") == 1 && length($0) == length("## 当前等级必需门禁缺失") ||
  index($0, "## 当前等级必需门禁失败") == 1 && length($0) == length("## 当前等级必需门禁失败") ||
  index($0, "## 当前等级必需门禁阻塞") == 1 && length($0) == length("## 当前等级必需门禁阻塞") ||
  index($0, "## 当前等级带风险门禁") == 1 && length($0) == length("## 当前等级带风险门禁") ||
  index($0, "## Context Assembly") == 1 && length($0) == length("## Context Assembly") ||
  index($0, "## 可选：完整 Agent 上下文") == 1 && length($0) == length("## 可选：完整 Agent 上下文") {
    skip = 1
    next
  }
  skip && /^## / {
    skip = 0
  }
  !skip { print }
' "$TMP_OUTPUT"
