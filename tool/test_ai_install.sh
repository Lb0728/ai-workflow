#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WORKFLOW_ROOT="${1:-$(cd "${SCRIPT_DIR}/.." && pwd)}"
TEST_ROOT="$(mktemp -d)"
trap 'rm -rf "$TEST_ROOT"' EXIT

if [ ! -x "${WORKFLOW_ROOT}/tool/install_ai_agent.sh" ]; then
  printf 'FAIL installer missing or not executable: %s\n' "${WORKFLOW_ROOT}/tool/install_ai_agent.sh"
  exit 1
fi

PROJECT_ROOT="${TEST_ROOT}/demo-project"
TEST_HOME="${TEST_ROOT}/home"
mkdir -p \
  "$TEST_HOME" \
  "${PROJECT_ROOT}/scripts" \
  "${PROJECT_ROOT}/lib" \
  "${PROJECT_ROOT}/test" \
  "${PROJECT_ROOT}/docs"

# Demo-project detection markers (see adapters/demo-project/project-profile.yaml)
# and declared project paths (see adapters/demo-project/config/paths.yaml).
: > "${PROJECT_ROOT}/.ai-demo-project"
printf '%s\n' "# Demo fixture" > "${PROJECT_ROOT}/AGENTS.md"
printf '%s\n' '#!/usr/bin/env bash' 'set -e' 'exit 0' \
  > "${PROJECT_ROOT}/scripts/static_check.sh"
chmod +x "${PROJECT_ROOT}/scripts/static_check.sh"
printf '%s\n' 'void main() {}' > "${PROJECT_ROOT}/lib/main.dart"
for doc in README.md target_architecture.md current_status.md progress.md current_deep_dive.md; do
  printf '%s\n' "# ${doc}" > "${PROJECT_ROOT}/docs/${doc}"
done

git -C "$PROJECT_ROOT" init -q
git -C "$PROJECT_ROOT" config user.name "AI Install Test"
git -C "$PROJECT_ROOT" config user.email "ai-install-test@example.invalid"
git -C "$PROJECT_ROOT" add -A
git -C "$PROJECT_ROOT" commit -q -m "test > install fixture"

for client in codex cursor claude-code; do
  output="$(
    cd "$PROJECT_ROOT"
    HOME="$TEST_HOME" LC_ALL="${LC_ALL:-en_US.UTF-8}" LANG="${LANG:-en_US.UTF-8}" \
      "${WORKFLOW_ROOT}/tool/install_ai_agent.sh" \
        --client "$client"
  )"
  if ! printf '%s\n' "$output" | grep -F -q "adapter=demo-project"; then
    printf 'FAIL installer did not auto-detect demo-project for %s\n' "$client"
    exit 1
  fi
done

if [ "$(readlink "${PROJECT_ROOT}/ai")" != "$WORKFLOW_ROOT" ]; then
  printf '%s\n' "FAIL project ai link"
  exit 1
fi

if [ ! -f "${PROJECT_ROOT}/AGENTS.md" ] ||
    [ -L "${PROJECT_ROOT}/AGENTS.md" ]; then
  printf '%s\n' "FAIL existing project AGENTS.md was not preserved"
  exit 1
fi

for skill in grill-me grill-with-docs to-prd to-task-cards handoff; do
  for target in \
    "${TEST_HOME}/.agents/skills/${skill}" \
    "${TEST_HOME}/.cursor/skills/${skill}" \
    "${TEST_HOME}/.claude/skills/${skill}"; do
    if [ ! -L "$target" ] || [ ! -f "${target}/SKILL.md" ]; then
      printf 'FAIL client Skill link: %s\n' "$target"
      exit 1
    fi
  done
done

if [ ! -L "${PROJECT_ROOT}/.cursor/rules/ai-workflow.mdc" ]; then
  printf '%s\n' "FAIL Cursor persistent rule"
  exit 1
fi

if [ ! -L "${PROJECT_ROOT}/.claude/rules/ai-workflow.md" ]; then
  printf '%s\n' "FAIL Claude Code persistent rule"
  exit 1
fi

for runtime_dir in tasks states handoffs closeouts defects; do
  if [ ! -d "${PROJECT_ROOT}/.ai-runtime/${runtime_dir}" ]; then
    printf 'FAIL isolated project Runtime directory: %s\n' "$runtime_dir"
    exit 1
  fi
done

runtime_tasks="$(
  "${PROJECT_ROOT}/ai/tool/ai_core_loader.sh" \
    --project-root "$PROJECT_ROOT" \
    resolve runtime.tasks
)"
if [ "$runtime_tasks" != "${PROJECT_ROOT}/.ai-runtime/tasks" ]; then
  printf 'FAIL project Runtime resolution expected=%s actual=%s\n' \
    "${PROJECT_ROOT}/.ai-runtime/tasks" "$runtime_tasks"
  exit 1
fi

if [ -n "$(git -C "$PROJECT_ROOT" status --porcelain --untracked-files=normal)" ]; then
  printf '%s\n' "FAIL local installation dirtied project worktree"
  git -C "$PROJECT_ROOT" status --short
  exit 1
fi

printf '%s\n' "PASS shared package link"
printf '%s\n' "PASS existing project AGENTS.md preserved"
printf '%s\n' "PASS demo-project auto-detection"
printf '%s\n' "PASS Codex, Cursor and Claude Code Skill installation"
printf '%s\n' "PASS client persistent rules"
printf '%s\n' "PASS isolated project Runtime"
printf '%s\n' "PASS project worktree remains clean"
