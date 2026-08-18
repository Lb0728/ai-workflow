#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MEMORY_DIR="$(cd "${SCRIPT_DIR}/../defect_memory" && pwd)"

usage() {
  cat <<EOF
Usage: ./tool/ai_defect_memory_search.sh <keyword> [keyword ...]

Searches only verified defect memory cards and returns at most 5 matching paths.
Use feature, module, state, API, or symptom keywords from the current task.
EOF
}

if [ "$#" -eq 0 ]; then
  usage
  exit 1
fi

if command -v rg >/dev/null 2>&1; then
  search_impl() {
    rg -i -l -F --glob '*.md' --glob '!README.md' --glob '!template.md' -- "$1" "$MEMORY_DIR" || true
  }
else
  # Portable fallback: ripgrep may be absent on fresh macOS / WSL2 / CI images.
  search_impl() {
    grep -r -i -l -F --exclude=README.md --exclude=template.md -- "$1" "$MEMORY_DIR" || true
  }
fi

for keyword in "$@"; do
  if [ -n "$keyword" ]; then
    search_impl "$keyword"
  fi
done | awk '!seen[$0]++' | head -n 5
