#!/usr/bin/env bash
set -eu
export LC_ALL=C

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WORKFLOW_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
OUTPUT_DIR="${WORKFLOW_ROOT}/dist/artifacts"
ALLOW_DIRTY=false

usage() {
  printf '%s\n' "Usage: package.sh [--output-dir <path>] [--allow-dirty]"
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --output-dir)
      [ "$#" -ge 2 ] || { usage >&2; exit 2; }
      OUTPUT_DIR="$2"
      shift 2
      ;;
    --allow-dirty)
      ALLOW_DIRTY=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      printf 'ERROR unknown argument: %s\n' "$1" >&2
      exit 2
      ;;
  esac
done

if git -C "$WORKFLOW_ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1 &&
  [ "$ALLOW_DIRTY" = false ]; then
  if ! git -C "$WORKFLOW_ROOT" diff --quiet --ignore-submodules -- ||
    ! git -C "$WORKFLOW_ROOT" diff --cached --quiet --ignore-submodules -- ||
    [ -n "$(git -C "$WORKFLOW_ROOT" ls-files --others --exclude-standard)" ]; then
    printf '%s\n' "ERROR source worktree is dirty; use --allow-dirty only for local validation" >&2
    exit 1
  fi
fi

version="$(tr -d '\r\n' < "${WORKFLOW_ROOT}/VERSION")"
package_name="universal-workflow-v2-${version}"
staging_parent="$(mktemp -d "${TMPDIR:-/tmp}/ai-workflow-v2-package.XXXXXX")"
staging_root="${staging_parent}/${package_name}"
trap 'rm -rf "$staging_parent"' EXIT
mkdir -p "$staging_root" "$OUTPUT_DIR"

copy_path() {
  local source_path="$1"
  local destination_path="${staging_root}/${source_path}"
  [ -e "${WORKFLOW_ROOT}/${source_path}" ] || {
    printf 'ERROR package input missing: %s\n' "$source_path" >&2
    exit 1
  }
  mkdir -p "$(dirname "$destination_path")"
  cp -R "${WORKFLOW_ROOT}/${source_path}" "$destination_path"
}

copy_path VERSION
copy_path core/LOADER_CONTRACT_V2.md
copy_path core/agents.yaml
copy_path core/agents
copy_path core/config
copy_path core/lib
copy_path core/loader
copy_path core/router
copy_path core/schemas
copy_path core/templates
rm "${staging_root}/core/templates/issue_intake_template.md"
copy_path core/workflows
copy_path hosts
copy_path policies/company
copy_path roles/developer
copy_path skills
copy_path discovery
copy_path runtime-template
copy_path cli
copy_path compat/legacy
copy_path docs
copy_path dist/universal-workflow-v2.yaml
copy_path dist/install.sh

if grep -R -E -n \
  '/Users/[A-Za-z0-9._-]+/|/Volumes/[A-Za-z0-9._-]+/|-----BEGIN [A-Z ]*PRIVATE KEY-----|AKIA[0-9A-Z]{16}|ghp_[A-Za-z0-9]{20,}|sk-[A-Za-z0-9]{20,}' \
  "$staging_root" 2>/dev/null | grep -q .; then
  printf '%s\n' "ERROR package contains a personal absolute path or credential pattern" >&2
  exit 1
fi

metadata_file="${staging_root}/PACKAGE-METADATA.yaml"
source_commit="package"
if git -C "$WORKFLOW_ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  source_commit="$(git -C "$WORKFLOW_ROOT" rev-parse HEAD 2>/dev/null || printf '%s' unknown)"
  [ "$ALLOW_DIRTY" = false ] || source_commit="${source_commit}-local-validation"
fi
{
  printf '%s\n' "schema_version: 1"
  printf "package: '%s'\n" "$package_name"
  printf "workflow_version: '%s'\n" "$version"
  printf "source_commit: '%s'\n" "$source_commit"
  printf '%s\n' "release_state: internal_developer_trial"
  printf '%s\n' "contains_runtime_evidence: false"
  printf '%s\n' "contains_project_adapters: false"
} > "$metadata_file"

archive_path="${OUTPUT_DIR}/${package_name}.tar.gz"
tar -C "$staging_parent" -czf "$archive_path" "$package_name"
# Generate the checksum with a relative filename so the .sha256 file never
# embeds a personal absolute path (PACKAGE_ARCHIVE_NAME only).
(
  cd "$OUTPUT_DIR"
  shasum -a 256 "$(basename "$archive_path")"
) > "${archive_path}.sha256"

printf 'Package: %s\n' "$archive_path"
printf 'Checksum: %s\n' "${archive_path}.sha256"
printf '%s\n' "Publish: NOT PERFORMED"
