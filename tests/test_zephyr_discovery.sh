#!/usr/bin/env bash
set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/test_helper.sh"

temp_root="$(mktemp -d "${TMPDIR:-/tmp}/workflow-zephyr-discovery.XXXXXX")"
trap 'rm -rf "$temp_root"' EXIT

for fixture_name in flutter dart go; do
  fixture_root="${temp_root}/${fixture_name}"
  copy_fixture "$fixture_name" "$fixture_root"
  profile_file="${temp_root}/${fixture_name}.yaml"
  "${WORKFLOW_ROOT}/discovery/generators/generate_project_profile.sh" \
    --project-root "$fixture_root" --output "$profile_file"
  cmp -s "$profile_file" "${TESTS_ROOT}/expected/${fixture_name}-project.yaml" ||
    fail "${fixture_name} project profile changed from the pre-Zephyr snapshot"
done

assert_file_contains "${temp_root}/flutter.yaml" "detected_kind: 'flutter'"
assert_file_contains "${temp_root}/flutter.yaml" "static_check: ['flutter', 'analyze']"
assert_file_contains "${temp_root}/dart.yaml" "detected_kind: 'dart'"
assert_file_contains "${temp_root}/go.yaml" "detected_kind: 'go'"

if grep -Eiq 'west|board|flash|device_validation|Zephyr' "${temp_root}/flutter.yaml"; then
  fail "Flutter profile contains Zephyr-only semantics"
fi

cmake_root="${temp_root}/cmake"
copy_fixture cmake "$cmake_root"
cmake_profile="${temp_root}/cmake.yaml"
"${WORKFLOW_ROOT}/discovery/generators/generate_project_profile.sh" \
  --project-root "$cmake_root" --output "$cmake_profile"
assert_file_contains "$cmake_profile" "detected_kind: 'unknown'"

for fixture_name in \
  zephyr-existing-build zephyr-app-no-build zephyr-missing-board \
  zephyr-board-alpha zephyr-board-beta; do
  fixture_root="${temp_root}/${fixture_name}"
  copy_fixture "$fixture_name" "$fixture_root"
  profile_file="${temp_root}/${fixture_name}.yaml"
  "${WORKFLOW_ROOT}/discovery/generators/generate_project_profile.sh" \
    --project-root "$fixture_root" --output "$profile_file"
  assert_file_contains "$profile_file" "detected_kind: 'zephyr'"
  assert_file_contains "$profile_file" "frameworks: ['Zephyr']"
  if grep -Eq "flutter analyze|flutter test|'flutter'" "$profile_file"; then
    fail "Zephyr profile contains Flutter commands"
  fi
done

assert_file_contains "${temp_root}/zephyr-existing-build.yaml" \
  "build: ['west', 'build', '-d', 'build']"
assert_file_contains "${temp_root}/zephyr-app-no-build.yaml" \
  "build: ['west', 'build', '-b', 'board_alpha', '.']"
assert_file_contains "${temp_root}/zephyr-missing-board.yaml" "build: []"
assert_file_contains "${temp_root}/zephyr-missing-board.yaml" \
  "discovery_status: 'needs_input'"
assert_file_contains "${temp_root}/zephyr-board-alpha.yaml" "board: 'board_alpha'"
assert_file_contains "${temp_root}/zephyr-board-beta.yaml" "board: 'board_beta'"

weak_root="${temp_root}/weak-markers"
mkdir -p "${weak_root}/boards" "${weak_root}/src" "${weak_root}/include" \
  "${weak_root}/build" "${weak_root}/.west"
printf '%s\n' "manifest:" "  projects: []" >"${weak_root}/west.yml"
printf '%s\n' "[manifest]" "path = ." >"${weak_root}/.west/config"
printf '%s\n' "CONFIG_MAIN_STACK_SIZE=1024" >"${weak_root}/prj.conf"
printf '%s\n' "cmake_minimum_required(VERSION 3.16)" "project(weak)" \
  >"${weak_root}/CMakeLists.txt"
weak_kind="$(ZEPHYR_BASE=/opt/zephyr \
  "${WORKFLOW_ROOT}/discovery/detectors/detect_project.sh" \
  --project-root "$weak_root")"
[ "$weak_kind" = "unknown" ] ||
  fail "weak Zephyr markers misidentified a generic CMake project"

if grep -R -E -i -n \
  'Zephyr|west[[:space:]]+(build|flash|debug|attach)|Device Validation' \
  "${WORKFLOW_ROOT}/core" "${WORKFLOW_ROOT}/skills" \
  "${WORKFLOW_ROOT}/policies/company" >/dev/null; then
  fail "Zephyr semantics leaked into Core, generic Skills or Company Policy"
fi

printf '%s\n' "test_zephyr_discovery: PASS"
