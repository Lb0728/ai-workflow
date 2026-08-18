#!/usr/bin/env bash
# V1 distribution package test — builds a clean-copy distribution using the
# generic example manifest and validates the archive.
set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WORKFLOW_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
DEMO_ROOT="${1:-${WORKFLOW_ROOT}/examples/demo-project}"
SOURCE_COPY="$(mktemp -d)"
OUTPUT_DIR="$(mktemp -d)"
EXTRACT_DIR="$(mktemp -d)"
trap 'rm -rf "$SOURCE_COPY" "$OUTPUT_DIR" "$EXTRACT_DIR"' EXIT

if [ ! -d "$DEMO_ROOT" ]; then
  printf '%s\n' "Usage: ./tool/test_ai_distribution_package.sh [demo-project-root]" >&2
  exit 2
fi

mkdir -p "$SOURCE_COPY" "$OUTPUT_DIR" "$EXTRACT_DIR"

tar --exclude=.git -cf - -C "$WORKFLOW_ROOT" . |
  tar -xf - -C "$SOURCE_COPY"

git -C "$SOURCE_COPY" init -q
git -C "$SOURCE_COPY" config user.name "AI Distribution Test"
git -C "$SOURCE_COPY" config user.email "ai-distribution-test@example.invalid"
git -C "$SOURCE_COPY" add -A
git -C "$SOURCE_COPY" commit -q -m "test > distribution fixture"

package_output="$(
  LC_ALL="${LC_ALL:-en_US.UTF-8}" LANG="${LANG:-en_US.UTF-8}" \
    "${SOURCE_COPY}/tool/ai_distribution_package.sh" \
      --project-root "$DEMO_ROOT" \
      --distribution example \
      --role developer \
      --output-dir "$OUTPUT_DIR"
)"

archive_path="$(printf '%s\n' "$package_output" | awk -F= '$1 == "PACKAGE_PATH" { print $2; exit }')"
checksum_path="$(printf '%s\n' "$package_output" | awk -F= '$1 == "CHECKSUM_PATH" { print $2; exit }')"

if [ ! -f "$archive_path" ] || [ ! -f "$checksum_path" ]; then
  printf '%s\n' "FAIL distribution archive or checksum missing"
  exit 1
fi

(
  cd "$OUTPUT_DIR"
  shasum -a 256 -c "$(basename "$checksum_path")" >/dev/null
)

tar -xzf "$archive_path" -C "$EXTRACT_DIR"
package_root="$(find "$EXTRACT_DIR" -mindepth 1 -maxdepth 1 -type d -print | head -n 1)"

if [ -z "$package_root" ] || [ ! -f "${package_root}/PACKAGE_METADATA.txt" ]; then
  printf '%s\n' "FAIL package metadata missing"
  exit 1
fi

if find "${package_root}/runtime" -type f -print | grep -q .; then
  printf '%s\n' "FAIL Runtime history leaked into package"
  exit 1
fi

if [ ! -f "${package_root}/adapters/demo-project/project-profile.yaml" ]; then
  printf '%s\n' "FAIL example package is missing the demo-project Adapter"
  exit 1
fi

# The example package must not contain any Adapter other than demo-project.
if find "${package_root}/adapters" -mindepth 1 -maxdepth 1 -type d \
  ! -name demo-project -print | grep -q .; then
  printf '%s\n' "FAIL unexpected Adapter leaked into example package"
  exit 1
fi

for required in \
  core/lib/state_machine.sh \
  core/lib/task_card.sh \
  core/config/state-machine.yaml \
  integrations/codex/integration-profile.yaml \
  integrations/cursor/integration-profile.yaml \
  integrations/claude-code/integration-profile.yaml \
  tool/install_ai_agent.sh; do
  if [ ! -f "${package_root}/${required}" ]; then
    printf 'FAIL example package input missing: %s\n' "$required"
    exit 1
  fi
done

if [ "$(readlink "${package_root}/tasks")" != "runtime/tasks" ]; then
  printf '%s\n' "FAIL legacy Runtime task link is invalid"
  exit 1
fi

if find "$package_root" -name .git -print | grep -q .; then
  printf '%s\n' "FAIL Git metadata leaked into package"
  exit 1
fi

if grep -R -n -E '/(Users|Volumes)/[A-Za-z0-9._-]+' "$package_root" >/dev/null; then
  printf '%s\n' "FAIL personal absolute path leaked into package"
  exit 1
fi

"${package_root}/tool/test_ai_install.sh" "$package_root" >/dev/null

printf '%s\n' "PASS archive and checksum"
printf '%s\n' "PASS empty Runtime layout"
printf '%s\n' "PASS demo-project Adapter boundary"
printf '%s\n' "PASS Core libraries and integrations included"
printf '%s\n' "PASS relative compatibility links"
printf '%s\n' "PASS no Git metadata"
printf '%s\n' "PASS no personal absolute paths"
printf '%s\n' "PASS installer works from the packaged tree"
