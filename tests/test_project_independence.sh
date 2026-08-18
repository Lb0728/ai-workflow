#!/usr/bin/env bash
set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/test_helper.sh"

temp_root="$(mktemp -d "${TMPDIR:-/tmp}/workflow-project-independence.XXXXXX")"
trap 'rm -rf "$temp_root"' EXIT

package_output="${temp_root}/package"
"${WORKFLOW_ROOT}/dist/package.sh" --allow-dirty --output-dir "$package_output" \
  >"${temp_root}/package.out"
archive_path="$(awk '/^Package:/{print $2}' "${temp_root}/package.out")"
[ -f "$archive_path" ] || fail "V2 package was not created"

extract_root="${temp_root}/extract"
mkdir -p "$extract_root"
tar -C "$extract_root" -xzf "$archive_path"
package_root="$(find "$extract_root" -mindepth 1 -maxdepth 1 -type d -print -quit)"
[ -n "$package_root" ] || fail "extracted V2 package root missing"

archive_list="${temp_root}/archive.list"
tar -tzf "$archive_path" >"$archive_list"
if grep -E '/adapters/|/runtime/(tasks|states|handoffs|closeouts|defects)/[^./][^/]*$' \
  "$archive_list" >/dev/null; then
  fail "V2 package contains a fixed Project Adapter or Runtime instance"
fi

if grep -R -E -i -n \
  '/Users/[A-Za-z0-9._-]+/|/Volumes/[A-Za-z0-9._-]+/|[A-Za-z]:\\Users\\[^\\]+\\' \
  "$package_root" 2>/dev/null >"${temp_root}/binding.out"; then
  sed -n '1,80p' "${temp_root}/binding.out" >&2
  fail "V2 package contains a fixed project name or personal path"
fi

install_prefix="${temp_root}/installed"
"${package_root}/dist/install.sh" --prefix "$install_prefix" >/dev/null

go_project="${temp_root}/fixture-one"
flutter_project="${temp_root}/fixture-two"
copy_fixture go "$go_project"
copy_fixture flutter "$flutter_project"

for project_root in "$go_project" "$flutter_project"; do
  "${install_prefix}/bin/ai-workflow" init \
    --project-root "$project_root" --host codex --no-doctor >/dev/null
  [ -f "${project_root}/.ai/project.yaml" ] || fail "project profile missing"
  [ -f "${project_root}/.ai/ai.lock" ] || fail "project lock missing"
  [ -L "${project_root}/.ai/workflow" ] || fail "workflow link missing"
done

assert_file_contains "${go_project}/.ai/project.yaml" "detected_kind: 'go'"
assert_file_contains "${flutter_project}/.ai/project.yaml" "detected_kind: 'flutter'"

go_workflow="$(readlink "${go_project}/.ai/workflow")"
flutter_workflow="$(readlink "${flutter_project}/.ai/workflow")"
[ "$go_workflow" = "$flutter_workflow" ] ||
  fail "two fixtures did not install the same Workflow package"

printf '%s\n' "test_project_independence: PASS"
