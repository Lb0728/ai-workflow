#!/usr/bin/env bash
# dsh bundle integration tests:
#   - package.json declares dsh.bundle.patch and the patch file exists
#   - the patch parses as a YAML insert list
#   - every shipped skill has SKILL.md with name + description (kebab-case)
#   - the plugin JS and the copy script are syntactically valid
#   - the packaged skills mirror the repository canonical skills

set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/test_helper.sh"

DSH_DIR="${WORKFLOW_ROOT}/integrations/dsh"
PACKAGED_SKILLS="${DSH_DIR}/skills"
REPO_SKILLS="${WORKFLOW_ROOT}/skills"

# --- 1. bundle declaration -------------------------------------------------
assert_file_contains "${DSH_DIR}/package.json" '"dsh"'
assert_file_contains "${DSH_DIR}/package.json" '"bundle"'
assert_file_contains "${DSH_DIR}/package.json" '"patch": "./cordis.patch.yml"'
[ -f "${DSH_DIR}/cordis.patch.yml" ] || fail "cordis.patch.yml missing"

# --- 2. patch parses as a YAML insert list ---------------------------------
patch_rows="$(ruby -ryaml -e '
  rows = YAML.safe_load(File.read(ARGV.fetch(0)))
  rows.is_a?(Array) || abort("patch must be a top-level list")
  rows.each do |row|
    row.is_a?(Hash) && row.key?("insert") || abort("patch rows must be insert entries")
  end
  puts rows.first.fetch("insert").map { |r| r.fetch("id") }.join(",")
' "${DSH_DIR}/cordis.patch.yml")"
[ "$patch_rows" = "ai-workflow" ] || fail "patch must insert the ai-workflow row, got: ${patch_rows}"

# --- 3. shipped skills have valid frontmatter ------------------------------
expected_skills="grill-me grill-with-docs to-prd to-task-cards handoff ai-workflow"
for skill in $expected_skills; do
  skill_file="${PACKAGED_SKILLS}/${skill}/SKILL.md"
  [ -f "$skill_file" ] || fail "packaged skill missing: ${skill}/SKILL.md"
  grep -Eq '^name: ' "$skill_file" || fail "${skill}/SKILL.md missing frontmatter name"
  grep -Eq '^description: ' "$skill_file" || fail "${skill}/SKILL.md missing frontmatter description"
  skill_name="$(awk -F': *' '/^name: /{print $2; exit}' "$skill_file")"
  case "$skill_name" in
    *[!a-z0-9-]*|"")
      fail "skill name must be kebab-case: ${skill_name}"
      ;;
  esac
  [ "$skill_name" = "$skill" ] || fail "SKILL.md name ${skill_name} does not match directory ${skill}"
done

# --- 4. canonical skills mirror the repository -----------------------------
for skill in grill-me grill-with-docs to-prd to-task-cards handoff; do
  cmp -s "${REPO_SKILLS}/${skill}/SKILL.md" "${PACKAGED_SKILLS}/${skill}/SKILL.md" ||
    fail "packaged skill ${skill} diverges from the canonical repository skill"
done

# --- 5. JS syntax -----------------------------------------------------------
command -v node >/dev/null 2>&1 || fail "node is required for the dsh integration tests"
node --check "${DSH_DIR}/lib/index.js" || fail "lib/index.js syntax"
node --check "${DSH_DIR}/scripts/copy-skills.mjs" || fail "copy-skills.mjs syntax"

printf '%s\n' "test_dsh_integration: PASS"
