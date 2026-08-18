#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LOOP_NEW="${SCRIPT_DIR}/ai_loop_new.sh"

usage() {
  cat <<'EOF'
Usage: ./tool/ai_task_new.sh <task-type> [task-id] [slug] [priority] [delivery_level]

This is a compatibility entry. New tasks are created by ai_loop_new.sh from
Core task types plus the selected Project Adapter extensions.
EOF
}

TYPE="${1:-}"
TASK_ID="${2:-}"
SLUG="${3:-}"
PRIORITY="${4:-}"
DELIVERY_LEVEL="${5:-}"

if [ -z "$TYPE" ]; then
  usage
  exit 1
fi

if [ -z "$TASK_ID" ]; then
  printf '%s' "Task reference / ID: " >&2
  IFS= read -r TASK_ID
fi

if [ -z "$SLUG" ]; then
  printf '%s' "Short slug: " >&2
  IFS= read -r SLUG
fi

if [ -z "$TASK_ID" ]; then
  printf '%s\n' "ERROR task reference / ID is required" >&2
  exit 1
fi

exec "$LOOP_NEW" "$TYPE" "$TASK_ID" "$SLUG" "$PRIORITY" "$DELIVERY_LEVEL"
