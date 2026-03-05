#!/usr/bin/env bash
set -euo pipefail

# Usage: ./scripts/bump-version.sh [major|minor|patch]

source "$(dirname "$0")/lib/release-common.sh"

if [ $# -ne 1 ] || [[ ! "$1" =~ ^(major|minor|patch)$ ]]; then
    echo "Usage: $0 [major|minor|patch]"
    exit 1
fi

BUMP_TYPE="$1"

# Read current version
CURRENT_VERSION="$(read_version)"
CURRENT_BUILD="$(read_build_number)"

IFS='.' read -r MAJOR MINOR PATCH <<< "$CURRENT_VERSION"

case "$BUMP_TYPE" in
    major) MAJOR=$((MAJOR + 1)); MINOR=0; PATCH=0 ;;
    minor) MINOR=$((MINOR + 1)); PATCH=0 ;;
    patch) PATCH=$((PATCH + 1)) ;;
esac

NEW_VERSION="${MAJOR}.${MINOR}.${PATCH}"
NEW_BUILD=$((CURRENT_BUILD + 1))

# Update project.yml
sed -i '' "s/MARKETING_VERSION: \"${CURRENT_VERSION}\"/MARKETING_VERSION: \"${NEW_VERSION}\"/" "$PROJECT_YML"
sed -i '' "s/CURRENT_PROJECT_VERSION: \"${CURRENT_BUILD}\"/CURRENT_PROJECT_VERSION: \"${NEW_BUILD}\"/" "$PROJECT_YML"

echo "${CURRENT_VERSION} (${CURRENT_BUILD}) → ${NEW_VERSION} (${NEW_BUILD})"
echo ""
echo "Next steps:"
echo "  xcodegen generate"
echo "  git add project.yml && git commit -m \"Release v${NEW_VERSION}\""
echo "  git tag v${NEW_VERSION}"
