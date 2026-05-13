#!/usr/bin/env bash
# send_release_to_telegram.sh
# Wrapper script to invoke the Python release notifier with proper environment setup.
# Usage:
#   ./send_release_to_telegram.sh [--config <path>] [--release <tag>] [--dry-run]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_CONFIG="${SCRIPT_DIR}/../config.json"
PYTHON_SCRIPT="${SCRIPT_DIR}/send_release_to_telegram.py"

# --------------------------------------------------------------------------- #
# Helpers
# --------------------------------------------------------------------------- #
die() {
  echo "[ERROR] $*" >&2
  exit 1
}

usage() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Options:
  --config  <path>   Path to config.json  (default: ../config.json)
  --release <tag>    GitHub release tag to notify about (e.g. v1.2.3)
                     If omitted the script uses the latest release.
  --dry-run          Print the Telegram message without sending it.
  -h, --help         Show this help text.

Environment variables (override config.json values):
  TELEGRAM_BOT_TOKEN   Bot token issued by @BotFather
  TELEGRAM_CHAT_ID     Target chat / channel ID
  GITHUB_REPO          Owner/repo slug, e.g. dreamhunter2333/cloudflare_temp_email
EOF
}

# --------------------------------------------------------------------------- #
# Argument parsing
# --------------------------------------------------------------------------- #
CONFIG_PATH="${DEFAULT_CONFIG}"
RELEASE_TAG=""
DRY_RUN=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --config)
      CONFIG_PATH="$2"
      shift 2
      ;;
    --release)
      RELEASE_TAG="$2"
      shift 2
      ;;
    --dry-run)
      DRY_RUN="--dry-run"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      die "Unknown option: $1"
      ;;
  esac
done

# --------------------------------------------------------------------------- #
# Pre-flight checks
# --------------------------------------------------------------------------- #
command -v python3 >/dev/null 2>&1 || die "python3 is required but not found in PATH."

[[ -f "${PYTHON_SCRIPT}" ]] || die "Python script not found: ${PYTHON_SCRIPT}"

# Config file is optional when env vars are provided; warn if absent.
if [[ ! -f "${CONFIG_PATH}" ]]; then
  echo "[WARN] Config file not found at '${CONFIG_PATH}'. Falling back to environment variables."
  CONFIG_ARGS=()
else
  CONFIG_ARGS=("--config" "${CONFIG_PATH}")
fi

# Build the release argument array.
RELEASE_ARGS=()
if [[ -n "${RELEASE_TAG}" ]]; then
  RELEASE_ARGS=("--release" "${RELEASE_TAG}")
fi

# --------------------------------------------------------------------------- #
# Execute
# --------------------------------------------------------------------------- #
echo "[INFO] Sending release notification via Telegram..."
python3 "${PYTHON_SCRIPT}" \
  "${CONFIG_ARGS[@]+${CONFIG_ARGS[@]}}" \
  "${RELEASE_ARGS[@]+${RELEASE_ARGS[@]}}" \
  ${DRY_RUN}

echo "[INFO] Done."
