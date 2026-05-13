#!/usr/bin/env bash
# create_release.sh — Automates GitHub release creation for cloudflare_temp_email
# Usage: ./create_release.sh <version> [--dry-run]
#
# Requirements:
#   - gh (GitHub CLI) authenticated
#   - git with a clean working tree on main/master
#   - CHANGELOG.md or auto-generated notes from release-template.md

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE_FILE="$SCRIPT_DIR/../references/release-template.md"

# ── helpers ──────────────────────────────────────────────────────────────────

die() { echo "[ERROR] $*" >&2; exit 1; }
info() { echo "[INFO]  $*"; }

usage() {
  cat <<EOF
Usage: $(basename "$0") <version> [--dry-run]

  version    Semantic version tag, e.g. v1.4.2
  --dry-run  Print what would happen without creating the release
EOF
  exit 1
}

# ── argument parsing ─────────────────────────────────────────────────────────

VERSION=""
DRY_RUN=false

for arg in "$@"; do
  case "$arg" in
    v[0-9]*) VERSION="$arg" ;;
    --dry-run) DRY_RUN=true ;;
    *) usage ;;
  esac
done

[[ -z "$VERSION" ]] && usage

# Validate semver-ish format
[[ "$VERSION" =~ ^v[0-9]+\.[0-9]+\.[0-9]+(-[a-zA-Z0-9.]+)?$ ]] \
  || die "Version '$VERSION' does not match expected format vX.Y.Z[-pre]"

# ── pre-flight checks ────────────────────────────────────────────────────────

command -v gh  >/dev/null 2>&1 || die "'gh' CLI not found. Install from https://cli.github.com"
command -v git >/dev/null 2>&1 || die "'git' not found."

# Ensure we are inside a git repo
git rev-parse --git-dir >/dev/null 2>&1 || die "Not inside a git repository."

# Warn on dirty working tree
if ! git diff --quiet || ! git diff --cached --quiet; then
  die "Working tree is dirty. Commit or stash changes before releasing."
fi

CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
info "Current branch: $CURRENT_BRANCH"

# Check tag does not already exist
if git tag --list | grep -qx "$VERSION"; then
  die "Tag '$VERSION' already exists locally."
fi

# ── build release notes ──────────────────────────────────────────────────────

NOTES_FILE=$(mktemp /tmp/release_notes_XXXXXX.md)
trap 'rm -f "$NOTES_FILE"' EXIT

if [[ -f "$TEMPLATE_FILE" ]]; then
  # Substitute placeholders in the template
  PREV_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "")
  COMPARE_URL=""
  if [[ -n "$PREV_TAG" ]]; then
    REPO_URL=$(gh repo view --json url -q .url 2>/dev/null || echo "")
    [[ -n "$REPO_URL" ]] && COMPARE_URL="$REPO_URL/compare/${PREV_TAG}...${VERSION}"
  fi

  sed \
    -e "s/{{VERSION}}/$VERSION/g" \
    -e "s|{{COMPARE_URL}}|$COMPARE_URL|g" \
    -e "s/{{DATE}}/$(date +%Y-%m-%d)/g" \
    "$TEMPLATE_FILE" > "$NOTES_FILE"

  info "Release notes generated from template: $TEMPLATE_FILE"
else
  info "No template found; using auto-generated GitHub release notes."
  echo "" > "$NOTES_FILE"
fi

# ── create the release ───────────────────────────────────────────────────────

if [[ "$DRY_RUN" == true ]]; then
  info "[DRY RUN] Would create GitHub release '$VERSION' from branch '$CURRENT_BRANCH'"
  info "[DRY RUN] Release notes preview:"
  cat "$NOTES_FILE"
  exit 0
fi

info "Creating git tag $VERSION …"
git tag -a "$VERSION" -m "Release $VERSION"
git push origin "$VERSION"

info "Creating GitHub release $VERSION …"
GH_ARGS=("$VERSION" --title "$VERSION" --notes-file "$NOTES_FILE")

# Mark pre-releases automatically
[[ "$VERSION" =~ - ]] && GH_ARGS+=("--prerelease")

gh release create "${GH_ARGS[@]}"

info "Release $VERSION published successfully."
