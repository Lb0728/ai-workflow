#!/usr/bin/env bash
set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PACKAGE_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
INSTALL_PREFIX="${AI_WORKFLOW_INSTALL_PREFIX:-${HOME}/.local}"

for required_command in bash cp dirname ln mkdir tr; do
  command -v "$required_command" >/dev/null 2>&1 || {
    printf 'ERROR required command missing: %s\n' "$required_command" >&2
    exit 1
  }
done

usage() {
  cat <<'EOF'
Usage: install.sh [--prefix <path>]

Installs this version under <prefix>/lib/ai-workflow and exposes
<prefix>/bin/ai-workflow.

Supported environments:
  macOS with Bash
  Windows through WSL2 with the package and project in the WSL filesystem
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --prefix)
      [ "$#" -ge 2 ] || { usage >&2; exit 2; }
      INSTALL_PREFIX="$2"
      shift 2
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

version="$(tr -d '\r\n' < "${PACKAGE_ROOT}/VERSION")"
install_root="${INSTALL_PREFIX}/lib/ai-workflow/${version}"
bin_root="${INSTALL_PREFIX}/bin"
command_link="${bin_root}/ai-workflow"

case "$install_root" in
  "$PACKAGE_ROOT"|"$PACKAGE_ROOT"/*)
    printf '%s\n' "ERROR install prefix must not be inside the extracted package" >&2
    exit 1
    ;;
esac

if [ -e "$install_root" ]; then
  printf '%s\n' "ERROR this Workflow version is already installed" >&2
  exit 1
fi

if [ -e "$command_link" ] || [ -L "$command_link" ]; then
  printf '%s\n' "ERROR ai-workflow command already exists; nothing was installed" >&2
  exit 1
fi

mkdir -p "$(dirname "$install_root")" "$bin_root"
cp -R "$PACKAGE_ROOT" "$install_root"
ln -s "../lib/ai-workflow/${version}/cli/ai-workflow" "$command_link"

printf 'Installed version: %s\n' "$version"
printf 'Command: %s\n' "$command_link"
printf '%s\n' "Add the prefix bin directory to PATH if it is not already available."
printf '%s\n' "No project was modified."
