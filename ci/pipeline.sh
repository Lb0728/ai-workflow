#!/usr/bin/env bash
# AI Workflow V2 CI pipeline.
#
# Single entry point that any CI platform (GitHub Actions, GitLab CI, self
# hosted) can call. It validates the Workflow repository itself; it never runs
# project commands and never invokes the AI agent loop (that runs on developer
# machines through the `ai-workflow` CLI).
#
# Gates:
#   1. Bash syntax check on every shell script (always runs, no dependency).
#   2. shellcheck static analysis (runs when available; required with
#      --require-shellcheck, used by CI so the analysis is enforced).
#   3. Full V2 acceptance test suite (tests/run_all.sh).
#   4. Distribution manifest check for the example package.
#   5. Clean-worktree gate: packaging must start from a committed source.
#   6. Artifact freshness: dist/artifacts must contain exactly the current
#      VERSION package and no stale versions.
#
# Usage:
#   ci/pipeline.sh [--require-shellcheck]

set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WORKFLOW_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
REQUIRE_SHELLCHECK=false

usage() {
  printf '%s\n' "Usage: ci/pipeline.sh [--require-shellcheck]"
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --require-shellcheck)
      REQUIRE_SHELLCHECK=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      usage >&2
      exit 2
      ;;
  esac
done

cd "$WORKFLOW_ROOT"

failures=0

pass() { printf 'PASS %s\n' "$1"; }
fail() { printf 'ERROR %s\n' "$1"; failures=$((failures + 1)); }

# --- Gate 1: bash syntax -------------------------------------------------
syntax_errors=0
while IFS= read -r script; do
  if ! bash -n "$script"; then
    fail "bash syntax: $script"
    syntax_errors=$((syntax_errors + 1))
  fi
done < <(find cli core discovery dist tests tool -name '*.sh' -type f | sort)
if [ "$syntax_errors" -eq 0 ]; then
  pass "bash syntax (all .sh scripts)"
fi

# --- Gate 2: shellcheck --------------------------------------------------
if command -v shellcheck >/dev/null 2>&1; then
  shellcheck_failures=0
  while IFS= read -r script; do
    if ! shellcheck -x -S warning "$script"; then
      fail "shellcheck: $script"
      shellcheck_failures=$((shellcheck_failures + 1))
    fi
  done < <(find cli core discovery dist tests tool -name '*.sh' -type f | sort)
  if [ "$shellcheck_failures" -eq 0 ]; then
    pass "shellcheck (all .sh scripts)"
  fi
elif [ "$REQUIRE_SHELLCHECK" = true ]; then
  fail "shellcheck required but not installed"
else
  printf 'SKIP shellcheck (not installed; run ci/pipeline.sh --require-shellcheck in CI)\n'
fi

# --- Gate 3: acceptance test suite ---------------------------------------
if bash tests/run_all.sh >/tmp/ai-workflow-ci-tests.log 2>&1; then
  pass "V2 acceptance suite (tests/run_all.sh)"
else
  tail -n 40 /tmp/ai-workflow-ci-tests.log >&2 || true
  fail "V2 acceptance suite (tests/run_all.sh)"
fi

# --- Gate 4: distribution manifest ---------------------------------------
if bash tool/ai_distribution_check.sh --manifest example --role developer \
  >/tmp/ai-workflow-ci-distribution.log 2>&1; then
  pass "distribution manifest check (example)"
else
  tail -n 20 /tmp/ai-workflow-ci-distribution.log >&2 || true
  fail "distribution manifest check (example)"
fi

# --- Gate 5: clean worktree ----------------------------------------------
if git -C "$WORKFLOW_ROOT" diff --quiet --ignore-submodules -- &&
  git -C "$WORKFLOW_ROOT" diff --cached --quiet --ignore-submodules -- &&
  [ -z "$(git -C "$WORKFLOW_ROOT" ls-files --others --exclude-standard)" ]; then
  pass "clean worktree"
else
  git -C "$WORKFLOW_ROOT" status --short >&2 || true
  fail "clean worktree (uncommitted or untracked changes present)"
fi

# --- Gate 6: artifact freshness ------------------------------------------
# Release artifacts are generated at publish time (gitignored). When none are
# present in the tree, the gate is skipped; when any are present, they must
# match VERSION exactly.
version="$(tr -d '\r\n' < "$WORKFLOW_ROOT/VERSION")"
artifacts_dir="$WORKFLOW_ROOT/dist/artifacts"
expected="universal-workflow-v2-${version}.tar.gz"
if [ ! -d "$artifacts_dir" ] ||
  ! compgen -G "$artifacts_dir/universal-workflow-v2-*.tar.gz" >/dev/null; then
  printf 'SKIP artifact freshness (no release artifacts in tree; run dist/package.sh to publish)\n'
else
  artifact_errors=0
  if [ ! -f "$artifacts_dir/$expected" ]; then
    fail "artifact missing for VERSION ${version}: ${expected}"
    artifact_errors=$((artifact_errors + 1))
  fi
  if [ ! -f "$artifacts_dir/$expected.sha256" ]; then
    fail "artifact checksum missing for VERSION ${version}: ${expected}.sha256"
    artifact_errors=$((artifact_errors + 1))
  fi
  for stale in "$artifacts_dir"/universal-workflow-v2-*.tar.gz; do
    [ -e "$stale" ] || continue
    base="$(basename "$stale")"
    if [ "$base" != "$expected" ]; then
      fail "stale artifact present: ${base} (VERSION is ${version})"
      artifact_errors=$((artifact_errors + 1))
    fi
  done
  if [ "$artifact_errors" -eq 0 ]; then
    pass "artifact freshness (VERSION ${version})"
  fi
fi

# --- Result ---------------------------------------------------------------
if [ "$failures" -gt 0 ]; then
  printf 'RESULT FAIL errors=%d\n' "$failures"
  exit 1
fi
printf '%s\n' "RESULT PASS errors=0"
