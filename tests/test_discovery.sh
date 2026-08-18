#!/usr/bin/env bash
set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/test_helper.sh"

temp_root="$(mktemp -d "${TMPDIR:-/tmp}/workflow-discovery.XXXXXX")"
trap 'rm -rf "$temp_root"' EXIT

for fixture_name in flutter dart go; do
  fixture_root="${temp_root}/${fixture_name}"
  copy_fixture "$fixture_name" "$fixture_root"
  profile_file="${fixture_root}/project.yaml"
  "${WORKFLOW_ROOT}/discovery/generators/generate_project_profile.sh" \
    --project-root "$fixture_root" --output "$profile_file"

  assert_file_contains "$profile_file" "git_root: '.'"
  assert_file_contains "$profile_file" "architecture:"
  if [ "$fixture_name" != "dart" ]; then
    assert_file_contains "$profile_file" "status: present"
  fi
  assert_file_contains "$profile_file" "business_rules:"
  assert_file_contains "$profile_file" "status: unknown"
  if grep -Eq '/Users/|/Volumes/' "$profile_file"; then
    fail "${fixture_name} profile contains a personal absolute path"
  fi
done

clean_root="${temp_root}/clean-project"
mkdir -p "$clean_root"
printf '%s\n' "module example.com/clean" > "${clean_root}/go.mod"
clean_profile="${temp_root}/clean-project.yaml"
"${WORKFLOW_ROOT}/discovery/generators/generate_project_profile.sh" \
  --project-root "$clean_root" --output "$clean_profile"
assert_file_contains "$clean_profile" "existing_configuration: []"

assert_file_contains "${temp_root}/flutter/project.yaml" "detected_kind: 'flutter'"
assert_file_contains "${temp_root}/flutter/project.yaml" "static_check: ['flutter', 'analyze']"
assert_file_contains "${temp_root}/flutter/project.yaml" "platforms: ['android', 'ios']"
assert_file_contains "${temp_root}/dart/project.yaml" "detected_kind: 'dart'"
assert_file_contains "${temp_root}/dart/project.yaml" "static_check: ['dart', 'analyze']"
assert_file_contains "${temp_root}/dart/project.yaml" "test: ['dart', 'test']"
assert_file_contains "${temp_root}/go/project.yaml" "detected_kind: 'go'"
assert_file_contains "${temp_root}/go/project.yaml" "test: ['go', 'test', './...']"

printf '%s\n' "test_discovery: PASS"
