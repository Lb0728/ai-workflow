#!/usr/bin/env bash
set -eu
export LC_ALL=C

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/test_helper.sh"

temp_root="$(mktemp -d "${TMPDIR:-/tmp}/workflow-package.XXXXXX")"
trap 'rm -rf "$temp_root"' EXIT
source_root="${temp_root}/source"
output_root="${temp_root}/clean-out"

mkdir -p "$source_root"
tar -C "$WORKFLOW_ROOT" --exclude='.git' -cf - . | tar -C "$source_root" -xf -

"${source_root}/dist/package.sh" --output-dir "$output_root" \
  >"${temp_root}/package.out"
archive_path="$(awk '/^Package:/{print $2}' "${temp_root}/package.out")"
[ -f "$archive_path" ] || fail "clean V2 archive missing"
[ -f "${archive_path}.sha256" ] || fail "clean V2 checksum missing"

tar -tzf "$archive_path" > "${temp_root}/archive.list"
assert_file_contains "${temp_root}/archive.list" "/core/loader/ai_workflow_loader_v2.sh"
assert_file_contains "${temp_root}/archive.list" "/core/router/ai_loop_next_v2.sh"
assert_file_contains "${temp_root}/archive.list" "/core/config/state-machine.yaml"
assert_file_contains "${temp_root}/archive.list" "/core/lib/state_machine.sh"
assert_file_contains "${temp_root}/archive.list" "/core/lib/task_card.sh"
assert_file_contains "${temp_root}/archive.list" "/core/schemas/task-card.schema.yaml"
assert_file_contains "${temp_root}/archive.list" "/hosts/codex/host.yaml"
assert_file_contains "${temp_root}/archive.list" "/hosts/cursor/host.yaml"
for host_manifest in "${source_root}"/hosts/*/host.yaml; do
  [ -f "$host_manifest" ] || continue
  host_id="$(basename "$(dirname "$host_manifest")")"
  assert_file_contains "${temp_root}/archive.list" "/hosts/${host_id}/host.yaml"
done
assert_file_contains "${temp_root}/archive.list" "/policies/company/commit-convention.yaml"
assert_file_contains "${temp_root}/archive.list" "/dist/install.sh"
if grep -Eq '/adapters/|/runtime/tasks/|/migration/|/integrations/' "${temp_root}/archive.list"; then
  fail "V2 archive contains excluded V1 adapter, Runtime or migration content"
fi
if grep -Fq '/core/templates/issue_intake_template.md' "${temp_root}/archive.list"; then
  fail "V2 archive contains the unsanitized legacy Issue intake template"
fi
if grep -E '/skills/[^/]+/agents/openai.yaml' "${temp_root}/archive.list" >/dev/null; then
  fail "V2 archive keeps Host metadata inside canonical Skills"
fi
assert_file_contains "${temp_root}/archive.list" "/docs/ISSUE_TEMPLATE.md"
assert_file_contains "${temp_root}/archive.list" \
  "/hosts/codex/skill-metadata/grill-me/openai.yaml"

extract_root="${temp_root}/extract"
mkdir -p "$extract_root"
tar -C "$extract_root" -xzf "$archive_path"
installed_root="$(find "$extract_root" -mindepth 1 -maxdepth 1 -type d -print -quit)"
[ -n "$installed_root" ] || fail "extracted V2 package root missing"

if grep -R -E -n 'Project Adapter|project_adapter|adapter_inputs|adapter\.' \
  "${installed_root}/core" 2>/dev/null | grep -q .; then
  fail "V2 archive active Core contains residual project Adapter semantics"
fi

install_prefix="${temp_root}/installed-tools"
"${installed_root}/dist/install.sh" --prefix "$install_prefix" >/dev/null
[ -x "${install_prefix}/bin/ai-workflow" ] ||
  fail "machine-level ai-workflow command missing"

installed_project="${temp_root}/installed-project"
copy_fixture go "$installed_project"
git -C "$installed_project" init -q
(
  cd "$installed_project"
  "${install_prefix}/bin/ai-workflow" init --host codex >/dev/null
)
installed_new="$("${install_prefix}/bin/ai-workflow" new \
  --project-root "$installed_project" bugfix PACKAGE-NEW sample P2 light_feature)"
assert_output_contains "$installed_new" "已创建任务卡"
assert_file_contains "${installed_project}/.ai/runtime/tasks/package-new-sample.md" "type: bugfix"

installed_doctor="$("${install_prefix}/bin/ai-workflow" doctor \
  --project-root "$installed_project")"
assert_output_contains "$installed_doctor" "V2 doctor: PASS"

installed_task="${installed_project}/.ai/runtime/tasks/package-smoke.md"
{
  printf '%s\n' "---"
  printf '%s\n' "task_id: PACKAGE-SMOKE"
  printf '%s\n' "type: feature"
  printf '%s\n' "delivery_level: light_feature"
  printf '%s\n' "self_test_level: quick"
  printf '%s\n' "status: analyze"
  printf '%s\n' "legacy: false"
  printf '%s\n' "---"
  printf '%s\n' "## 交付风险信号"
  printf '%s\n' "- core_user_flow: false"
  printf '%s\n' "- api_contract_changed: false"
  printf '%s\n' "- shared_state_changed: false"
  printf '%s\n' "- multiple_modules_affected: false"
  printf '%s\n' "- multiple_repositories_affected: false"
  printf '%s\n' "- similar_defect_happened_before: false"
  printf '%s\n' "- impact_scope_unclear: false"
  printf '%s\n' "- architecture_boundary_involved: false"
  printf '%s\n' "- real_device_or_production_required: false"
} > "$installed_task"
installed_next="$(LC_ALL="$TEST_UTF8_LOCALE" LANG="$TEST_UTF8_LOCALE" \
  "${install_prefix}/bin/ai-workflow" next \
  --project-root "$installed_project" "$installed_task")"
assert_output_contains "$installed_next" "- 交付强度：L1"

packaged_v1_resolution="$(AI_WORKFLOW_V1_ROOT="$WORKFLOW_ROOT" \
  "${installed_root}/compat/legacy/loader.sh" \
  --project-root "${WORKFLOW_ROOT}/examples/demo-project" \
  --adapter demo-project resolve core.router)"
assert_output_contains "$packaged_v1_resolution" "core/agents/00_router_agent.md"

printf '%s\n' "test_package_v2: PASS"
