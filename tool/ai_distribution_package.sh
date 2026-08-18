#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WORKFLOW_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

PROJECT_ROOT=""
ADAPTER_ID="${AI_ADAPTER_ID:-}"
ROLE_ID="${AI_ROLE_ID:-developer}"
DISTRIBUTION_ID=""
OUTPUT_DIR=""
SOURCE_REF="HEAD"

usage() {
  cat <<'EOF'
Usage:
  ./tool/ai_distribution_package.sh \
    --project-root <path> \
    (--distribution <id> | --adapter <id>) \
    [--role <id>] \
    --output-dir <path> \
    [--source-ref <git-ref>]

The source repository must be clean. The package is built only from the
selected committed Git ref and the selected distribution manifest.
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --project-root)
      PROJECT_ROOT="${2:-}"
      shift 2
      ;;
    --adapter)
      ADAPTER_ID="${2:-}"
      shift 2
      ;;
    --distribution)
      DISTRIBUTION_ID="${2:-}"
      shift 2
      ;;
    --role)
      ROLE_ID="${2:-}"
      shift 2
      ;;
    --output-dir)
      OUTPUT_DIR="${2:-}"
      shift 2
      ;;
    --source-ref)
      SOURCE_REF="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      printf 'ERROR unknown argument: %s\n' "$1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [ -z "$PROJECT_ROOT" ] || [ ! -d "$PROJECT_ROOT" ]; then
  printf '%s\n' "ERROR --project-root must point to an existing project" >&2
  exit 2
fi

if [ -z "$DISTRIBUTION_ID" ] && [ -z "$ADAPTER_ID" ]; then
  printf '%s\n' "ERROR --distribution or --adapter is required" >&2
  exit 2
fi

if [ -n "$DISTRIBUTION_ID" ] && ! printf '%s' "$DISTRIBUTION_ID" | grep -Eq '^[a-zA-Z0-9_-]+$'; then
  printf '%s\n' "ERROR --distribution must be a safe identifier" >&2
  exit 2
fi

if [ -n "$ADAPTER_ID" ] && ! printf '%s' "$ADAPTER_ID" | grep -Eq '^[a-zA-Z0-9_-]+$'; then
  printf '%s\n' "ERROR --adapter must be a safe identifier" >&2
  exit 2
fi

if [ -z "$ROLE_ID" ] || ! printf '%s' "$ROLE_ID" | grep -Eq '^[a-zA-Z0-9_-]+$'; then
  printf '%s\n' "ERROR --role must be a safe identifier" >&2
  exit 2
fi

if [ -z "$OUTPUT_DIR" ]; then
  printf '%s\n' "ERROR --output-dir is required" >&2
  exit 2
fi

if ! git -C "$WORKFLOW_ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  printf 'ERROR workflow root is not a Git work tree: %s\n' "$WORKFLOW_ROOT" >&2
  exit 1
fi

if [ -n "$(git -C "$WORKFLOW_ROOT" status --porcelain --untracked-files=normal)" ]; then
  printf '%s\n' "ERROR source repository must be clean before packaging" >&2
  exit 1
fi

SOURCE_COMMIT="$(git -C "$WORKFLOW_ROOT" rev-parse "${SOURCE_REF}^{commit}")"
SHORT_COMMIT="$(git -C "$WORKFLOW_ROOT" rev-parse --short=12 "$SOURCE_COMMIT")"
if [ -n "$DISTRIBUTION_ID" ]; then
  MANIFEST_RELATIVE="distribution/${DISTRIBUTION_ID}.yaml"
else
  MANIFEST_RELATIVE="distribution/${ADAPTER_ID}-colleague.yaml"
fi

if ! git -C "$WORKFLOW_ROOT" cat-file -e "${SOURCE_COMMIT}:${MANIFEST_RELATIVE}" 2>/dev/null; then
  printf 'ERROR distribution manifest missing at %s: %s\n' "$SOURCE_REF" "$MANIFEST_RELATIVE" >&2
  exit 1
fi

MANIFEST_CONTENT="$(git -C "$WORKFLOW_ROOT" show "${SOURCE_COMMIT}:${MANIFEST_RELATIVE}")"
PACKAGE_ID="$(
  printf '%s\n' "$MANIFEST_CONTENT" |
    ruby -ryaml -e 'data = YAML.safe_load(STDIN.read); puts data.fetch("package_id")'
)"

if [ -z "$PACKAGE_ID" ] || ! printf '%s' "$PACKAGE_ID" | grep -Eq '^[a-zA-Z0-9_-]+$'; then
  printf 'ERROR invalid package_id in %s\n' "$MANIFEST_RELATIVE" >&2
  exit 1
fi

INCLUDE_PATHS="$(
  printf '%s\n' "$MANIFEST_CONTENT" |
    ruby -ryaml -e '
      data = YAML.safe_load(STDIN.read)
      include_data = data.fetch("include")
      include_data.each do |group, paths|
        next if group == "runtime_layout_only"
        Array(paths).each { |path| puts path }
      end
    '
)"

RUNTIME_PATHS="$(
  printf '%s\n' "$MANIFEST_CONTENT" |
    ruby -ryaml -e '
      data = YAML.safe_load(STDIN.read)
      Array(data.fetch("include").fetch("runtime_layout_only")).each { |path| puts path }
    '
)"

ARCHIVE_PATHS=()
while IFS= read -r include_path; do
  if [ -z "$include_path" ]; then
    continue
  fi
  include_path="${include_path%/}"
  case "$include_path" in
    /*|../*|*/../*|*/..)
      printf 'ERROR unsafe include path in manifest: %s\n' "$include_path" >&2
      exit 1
      ;;
  esac
  if ! git -C "$WORKFLOW_ROOT" cat-file -e "${SOURCE_COMMIT}:${include_path}" 2>/dev/null; then
    printf 'ERROR manifest include missing at %s: %s\n' "$SOURCE_REF" "$include_path" >&2
    exit 1
  fi
  ARCHIVE_PATHS+=("$include_path")
done <<EOF
$INCLUDE_PATHS
EOF

if [ "${#ARCHIVE_PATHS[@]}" -eq 0 ]; then
  printf 'ERROR manifest contains no distributable paths: %s\n' "$MANIFEST_RELATIVE" >&2
  exit 1
fi

PROJECT_ROOT="$(cd "$PROJECT_ROOT" && pwd)"
mkdir -p "$OUTPUT_DIR"
OUTPUT_DIR="$(cd "$OUTPUT_DIR" && pwd)"

case "$OUTPUT_DIR" in
  "$WORKFLOW_ROOT"|"$WORKFLOW_ROOT"/*)
    printf '%s\n' "ERROR --output-dir must be outside the source repository" >&2
    exit 1
    ;;
esac

PACKAGE_NAME="${PACKAGE_ID}-${ROLE_ID}-${SHORT_COMMIT}"
ARCHIVE_NAME="${PACKAGE_NAME}.tar.gz"
ARCHIVE_PATH="${OUTPUT_DIR}/${ARCHIVE_NAME}"
CHECKSUM_PATH="${ARCHIVE_PATH}.sha256"

if [ -e "$ARCHIVE_PATH" ] || [ -e "$CHECKSUM_PATH" ]; then
  printf 'ERROR package output already exists: %s\n' "$ARCHIVE_PATH" >&2
  exit 1
fi

BUILD_ROOT="$(mktemp -d)"
trap 'rm -rf "$BUILD_ROOT"' EXIT
PACKAGE_ROOT="${BUILD_ROOT}/${PACKAGE_NAME}"

git -C "$WORKFLOW_ROOT" archive \
  --format=tar \
  --prefix="${PACKAGE_NAME}/" \
  "$SOURCE_COMMIT" \
  -- "${ARCHIVE_PATHS[@]}" |
  tar -xf - -C "$BUILD_ROOT"

while IFS= read -r runtime_path; do
  if [ -z "$runtime_path" ]; then
    continue
  fi
  runtime_path="${runtime_path%/}"
  case "$runtime_path" in
    runtime/*)
      mkdir -p "${PACKAGE_ROOT}/${runtime_path}"
      ;;
    *)
      printf 'ERROR runtime layout path must stay under runtime/: %s\n' "$runtime_path" >&2
      exit 1
      ;;
  esac
done <<EOF
$RUNTIME_PATHS
EOF

source "${PACKAGE_ROOT}/tool/ai_profile_select.sh"
VALIDATED_ADAPTER_ID="$(
  ai_select_project_adapter_id \
    "${PACKAGE_ROOT}/adapters" \
    "$ADAPTER_ID" \
    "$PROJECT_ROOT"
)" || exit $?

printf '%s\n' \
  "package_id=${PACKAGE_ID}" \
  "distribution=${DISTRIBUTION_ID:-legacy-adapter-package}" \
  "validated_adapter=${VALIDATED_ADAPTER_ID}" \
  "role=${ROLE_ID}" \
  "source_commit=${SOURCE_COMMIT}" \
  "source_ref=${SOURCE_REF}" \
  "manifest=${MANIFEST_RELATIVE}" \
  > "${PACKAGE_ROOT}/PACKAGE_METADATA.txt"

if find "${PACKAGE_ROOT}/runtime" -type f -print | grep -q .; then
  printf '%s\n' "ERROR Runtime history found in generated package" >&2
  exit 1
fi

if find "$PACKAGE_ROOT" -name .git -print | grep -q .; then
  printf '%s\n' "ERROR Git metadata found in generated package" >&2
  exit 1
fi

if find "$PACKAGE_ROOT" -name .DS_Store -print | grep -q .; then
  printf '%s\n' "ERROR .DS_Store found in generated package" >&2
  exit 1
fi

if grep -R -n -E '/(Users|Volumes)/[A-Za-z0-9._-]+' "$PACKAGE_ROOT" >/dev/null; then
  printf '%s\n' "ERROR personal absolute path found in generated package" >&2
  exit 1
fi

if grep -R -n -E 'BEGIN (RSA|OPENSSH|EC) PRIVATE KEY|(^|[^A-Za-z])(api[_-]?key|access[_-]?token|client[_-]?secret)[[:space:]]*[:=][[:space:]]*[^<[:space:]]+' \
  "$PACKAGE_ROOT" >/dev/null; then
  printf '%s\n' "ERROR credential-like value found in generated package" >&2
  exit 1
fi

LC_ALL="${LC_ALL:-en_US.UTF-8}" LANG="${LANG:-en_US.UTF-8}" \
  "${PACKAGE_ROOT}/tool/ai_core_doctor.sh" \
    --project-root "$PROJECT_ROOT" \
    --adapter "$VALIDATED_ADAPTER_ID" \
    --role "$ROLE_ID" >/dev/null

LC_ALL="${LC_ALL:-en_US.UTF-8}" LANG="${LANG:-en_US.UTF-8}" \
  "${PACKAGE_ROOT}/tool/ai_core_compat_check.sh" \
    --project-root "$PROJECT_ROOT" \
    --adapter "$VALIDATED_ADAPTER_ID" \
    --role "$ROLE_ID" >/dev/null

"${PACKAGE_ROOT}/tool/ai_distribution_check.sh" \
  --manifest "$MANIFEST_RELATIVE" \
  --role "$ROLE_ID" >/dev/null

LC_ALL="${LC_ALL:-en_US.UTF-8}" LANG="${LANG:-en_US.UTF-8}" \
  "${PACKAGE_ROOT}/tool/ai_developer_pilot_check.sh" \
    --project-root "$PROJECT_ROOT" \
    --adapter "$VALIDATED_ADAPTER_ID" \
    --manifest "$MANIFEST_RELATIVE" >/dev/null

tar -czf "$ARCHIVE_PATH" -C "$BUILD_ROOT" "$PACKAGE_NAME"
(
  cd "$OUTPUT_DIR"
  shasum -a 256 "$ARCHIVE_NAME" > "${ARCHIVE_NAME}.sha256"
)

printf '%s\n' "RESULT PASS errors=0"
printf 'PACKAGE_PATH=%s\n' "$ARCHIVE_PATH"
printf 'CHECKSUM_PATH=%s\n' "$CHECKSUM_PATH"
printf 'SOURCE_COMMIT=%s\n' "$SOURCE_COMMIT"
