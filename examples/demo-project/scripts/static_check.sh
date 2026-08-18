#!/usr/bin/env bash
set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
failures=0

for required in \
  .ai-demo-project \
  AGENTS.md \
  README.md \
  docs/README.md \
  docs/current_status.md \
  docs/target_architecture.md \
  src/greeting.txt; do
  if [ -f "${PROJECT_ROOT}/${required}" ]; then
    printf 'PASS required file %s\n' "$required"
  else
    printf 'ERROR required file missing: %s\n' "$required"
    failures=$((failures + 1))
  fi
done

if grep -F -q "hello from the demo project" "${PROJECT_ROOT}/src/greeting.txt"; then
  printf '%s\n' "PASS greeting content"
else
  printf '%s\n' "ERROR greeting content"
  failures=$((failures + 1))
fi

if [ "$failures" -gt 0 ]; then
  printf 'RESULT FAIL errors=%d\n' "$failures"
  exit 1
fi

printf '%s\n' "RESULT PASS errors=0"
