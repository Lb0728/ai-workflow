#!/usr/bin/env bash
set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/test_helper.sh"

temp_root="$(mktemp -d "${TMPDIR:-/tmp}/workflow-loader.XXXXXX")"
trap 'rm -rf "$temp_root"' EXIT
project_root="${temp_root}/project"
copy_fixture flutter "$project_root"
git -C "$project_root" init -q
"${WORKFLOW_ROOT}/cli/ai-workflow" init --project-root "$project_root" --host codex >/dev/null

loader="${WORKFLOW_ROOT}/core/loader/ai_workflow_loader_v2.sh"
validation="$("$loader" --project-root "$project_root" validate)"
assert_output_contains "$validation" "PASS"
explicit_validation="$("$loader" --project-root "$project_root" \
  --host codex validate)"
assert_output_contains "$explicit_validation" "PASS"

resolved="$("$loader" --project-root "$project_root" resolve company.commit)"
[ "$resolved" = "${WORKFLOW_ROOT}/policies/company/commit-convention.yaml" ] ||
  fail "company.commit resolved to an unexpected file"

printf '%s\n' "automatic_push: true" > "${project_root}/.ai/policies/conflict.yaml"
if "$loader" --project-root "$project_root" validate >"${temp_root}/conflict.out" 2>&1; then
  fail "immutable conflict was accepted"
fi
assert_file_contains "${temp_root}/conflict.out" "immutable conflict"
assert_file_contains "${temp_root}/conflict.out" "automatic_push"
assert_file_contains "${temp_root}/conflict.out" "STOP"

missing_host_project="${temp_root}/missing-host"
copy_fixture go "$missing_host_project"
if "$loader" --project-root "$missing_host_project" validate \
  >"${temp_root}/missing-host.out" 2>&1; then
  fail "Loader accepted a missing Host selection"
fi
assert_file_contains "${temp_root}/missing-host.out" "Host is required"

if "$loader" --project-root "$project_root" --host not-installed validate \
  >"${temp_root}/unknown-host.out" 2>&1; then
  fail "Loader accepted an unknown Host Adapter"
fi
assert_file_contains "${temp_root}/unknown-host.out" "Host Adapter not found"

printf '%s\n' "test_loader_v2: PASS"
