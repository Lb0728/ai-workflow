#!/usr/bin/env bash
set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/test_helper.sh"

temp_root="$(mktemp -d "${TMPDIR:-/tmp}/workflow-zephyr-build.XXXXXX")"
trap 'rm -rf "$temp_root"' EXIT

fake_west="${temp_root}/west"
cat >"$fake_west" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >"${WEST_TEST_LOG:?}"
exit "${WEST_TEST_EXIT:-0}"
EOF
chmod +x "$fake_west"

existing_root="${temp_root}/wsl home/existing build"
copy_fixture zephyr-existing-build "$existing_root"
existing_log="${temp_root}/existing.log"
existing_output="$(
  WEST_TEST_LOG="$existing_log" WEST_TEST_EXIT=0 AI_WORKFLOW_WEST="$fake_west" \
    "${WORKFLOW_ROOT}/cli/ai-workflow" build --project-root "$existing_root"
)"
assert_output_contains "$existing_output" "Build: PASS"
assert_output_contains "$existing_output" "Flash: NOT_RUN"
assert_output_contains "$existing_output" "Device Validation: NOT_RUN"
assert_file_contains "$existing_log" "build -d build"

new_root="${temp_root}/new application"
copy_fixture zephyr-app-no-build "$new_root"
new_log="${temp_root}/new.log"
new_output="$(
  WEST_TEST_LOG="$new_log" WEST_TEST_EXIT=0 AI_WORKFLOW_WEST="$fake_west" \
    "${WORKFLOW_ROOT}/cli/ai-workflow" build --project-root "$new_root"
)"
assert_output_contains "$new_output" "Build: PASS"
assert_file_contains "$new_log" "build -b board_alpha ."

set +e
WEST_TEST_LOG="${temp_root}/failure.log" WEST_TEST_EXIT=7 \
  AI_WORKFLOW_WEST="$fake_west" \
  "${WORKFLOW_ROOT}/cli/ai-workflow" build --project-root "$new_root" \
  >"${temp_root}/failure.out" 2>&1
failure_exit=$?
set -e
[ "$failure_exit" -eq 7 ] || fail "west build failure exit code was not preserved"
assert_file_contains "${temp_root}/failure.out" "Build: FAIL"
assert_file_contains "${temp_root}/failure.out" "Build Exit Code: 7"

missing_root="${temp_root}/missing board"
copy_fixture zephyr-missing-board "$missing_root"
set +e
AI_WORKFLOW_WEST="$fake_west" \
  "${WORKFLOW_ROOT}/cli/ai-workflow" build --project-root "$missing_root" \
  >"${temp_root}/missing.out" 2>&1
missing_exit=$?
set -e
[ "$missing_exit" -eq 2 ] || fail "missing board/application did not STOP"
assert_file_contains "${temp_root}/missing.out" "Build: NOT_RUN"
assert_file_contains "${temp_root}/missing.out" "Action: STOP"
assert_file_contains "${temp_root}/missing.out" \
  "Required input: target board and application directory"

set +e
AI_WORKFLOW_WEST="${temp_root}/not-installed-west" \
  "${WORKFLOW_ROOT}/cli/ai-workflow" build --project-root "$new_root" \
  >"${temp_root}/west-missing.out" 2>&1
west_missing_exit=$?
set -e
[ "$west_missing_exit" -eq 2 ] || fail "missing west did not STOP"
assert_file_contains "${temp_root}/west-missing.out" "Build: NOT_RUN"
assert_file_contains "${temp_root}/west-missing.out" "Action: STOP"

codex_root="${temp_root}/wsl home/codex zephyr"
copy_fixture zephyr-app-no-build "$codex_root"
git -C "$codex_root" init -q
"${WORKFLOW_ROOT}/cli/ai-workflow" init \
  --project-root "$codex_root" --host codex >/dev/null
assert_file_contains "${codex_root}/.ai/project.yaml" "detected_kind: 'zephyr'"
"${WORKFLOW_ROOT}/cli/ai-workflow" doctor --project-root "$codex_root" >/dev/null

printf '%s\n' "test_zephyr_build: PASS"
