#!/usr/bin/env bash
set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WORKFLOW_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
source "${SCRIPT_DIR}/ai_profile_select.sh"

ADAPTER_ID="${AI_ADAPTER_ID:-}"
ROLE_ID="${AI_ROLE_ID:-}"
MANIFEST_ARG=""
failures=0

while [ "$#" -gt 0 ]; do
  case "$1" in
    --adapter)
      ADAPTER_ID="${2:-}"
      shift 2
      ;;
    --manifest)
      MANIFEST_ARG="${2:-}"
      shift 2
      ;;
    --role)
      ROLE_ID="${2:-}"
      shift 2
      ;;
    -h|--help)
      printf '%s\n' "Usage: ./tool/ai_distribution_check.sh [--manifest <id-or-path> | --adapter <id>] [--role <id>]"
      exit 0
      ;;
    *)
      printf 'ERROR unknown argument: %s\n' "$1" >&2
      exit 2
      ;;
  esac
done

ROLE_ID="$(ai_select_profile_id "${WORKFLOW_ROOT}/roles" "$ROLE_ID" "Role Adapter")" || exit $?

if [ -n "$MANIFEST_ARG" ]; then
  case "$MANIFEST_ARG" in
    distribution/*.yaml)
      MANIFEST_RELATIVE="$MANIFEST_ARG"
      ;;
    *.yaml)
      MANIFEST_RELATIVE="distribution/${MANIFEST_ARG}"
      ;;
    *)
      MANIFEST_RELATIVE="distribution/${MANIFEST_ARG}.yaml"
      ;;
  esac
else
  if [ -z "$ADAPTER_ID" ]; then
    printf '%s\n' "ERROR --manifest or --adapter is required when multiple distributions exist" >&2
    exit 2
  fi
  if [ -f "${WORKFLOW_ROOT}/distribution/${ADAPTER_ID}-colleague.yaml" ]; then
    MANIFEST_RELATIVE="distribution/${ADAPTER_ID}-colleague.yaml"
  elif [ -f "${WORKFLOW_ROOT}/distribution/example.yaml" ] &&
      grep -F -q -- "- adapters/${ADAPTER_ID}/" "${WORKFLOW_ROOT}/distribution/example.yaml"; then
    MANIFEST_RELATIVE="distribution/example.yaml"
  else
    printf 'ERROR no distribution manifest contains adapter: %s\n' "$ADAPTER_ID" >&2
    exit 1
  fi
fi

case "$MANIFEST_RELATIVE" in
  distribution/*.yaml)
    ;;
  *)
    printf 'ERROR unsafe distribution manifest path: %s\n' "$MANIFEST_RELATIVE" >&2
    exit 2
    ;;
esac

MANIFEST_PATH="${WORKFLOW_ROOT}/${MANIFEST_RELATIVE}"
if [ ! -f "$MANIFEST_PATH" ]; then
  printf 'ERROR distribution manifest missing: %s\n' "$MANIFEST_RELATIVE" >&2
  exit 1
fi

if [ -n "$ADAPTER_ID" ] &&
    ! grep -F -q "adapters/${ADAPTER_ID}/" "$MANIFEST_PATH"; then
  printf 'ERROR adapter %s is not included by %s\n' "$ADAPTER_ID" "$MANIFEST_RELATIVE" >&2
  exit 1
fi

pass() {
  printf 'PASS %s\n' "$1"
}

fail() {
  printf 'ERROR %s\n' "$1"
  failures=$((failures + 1))
}

INCLUDE_PATHS="$(
  ruby -ryaml -e '
    data = YAML.safe_load(File.read(ARGV.fetch(0)))
    data.fetch("include").each do |group, paths|
      next if group == "runtime_layout_only"
      Array(paths).each { |path| puts path }
    end
  ' "$MANIFEST_PATH"
)"

SCAN_PATHS=()
while IFS= read -r include_path; do
  if [ -z "$include_path" ]; then
    continue
  fi
  include_path="${include_path%/}"
  case "$include_path" in
    /*|../*|*/../*|*/..)
      fail "unsafe include path: ${include_path}"
      continue
      ;;
  esac
  if [ -e "${WORKFLOW_ROOT}/${include_path}" ] || [ -L "${WORKFLOW_ROOT}/${include_path}" ]; then
    pass "distribution input ${include_path}"
    if [ "$include_path" != "tasks" ]; then
      SCAN_PATHS+=("${WORKFLOW_ROOT}/${include_path}")
    fi
  else
    fail "distribution input missing: ${include_path}"
  fi
done <<EOF
$INCLUDE_PATHS
EOF

if [ ! -d "${WORKFLOW_ROOT}/roles/${ROLE_ID}" ]; then
  fail "Role Adapter missing: roles/${ROLE_ID}"
fi

if [ -x "${WORKFLOW_ROOT}/tool/ai_distribution_package.sh" ]; then
  pass "distribution packager executable"
else
  fail "distribution packager missing or not executable"
fi

if grep -F -q 'distribution_metadata:' "$MANIFEST_PATH"; then
  pass "distribution metadata declared"
else
  fail "distribution metadata missing"
fi

if [ "${#SCAN_PATHS[@]}" -gt 0 ] &&
    grep -R -n -E '/Users/[A-Za-z0-9._-]+|/Volumes/[A-Za-z0-9._-]+' "${SCAN_PATHS[@]}" >/dev/null; then
  fail "personal absolute path found in distributable policy assets"
else
  pass "no personal absolute path in distributable policy assets"
fi

if [ "${#SCAN_PATHS[@]}" -gt 0 ] &&
    grep -R -n -E 'BEGIN (RSA|OPENSSH|EC) PRIVATE KEY|(^|[^A-Za-z])(api[_-]?key|access[_-]?token|client[_-]?secret)[[:space:]]*[:=][[:space:]]*[^<[:space:]]+' \
      "${SCAN_PATHS[@]}" >/dev/null; then
  fail "credential-like value found in distributable policy assets"
else
  pass "no credential-like value in distributable policy assets"
fi

if grep -F -q 'runtime/tasks/*.md' "$MANIFEST_PATH"; then
  pass "runtime task history excluded"
else
  fail "runtime task history exclusion missing"
fi

if [ "$failures" -gt 0 ]; then
  printf 'RESULT FAIL errors=%d\n' "$failures"
  exit 1
fi

printf '%s\n' "RESULT PASS errors=0"
