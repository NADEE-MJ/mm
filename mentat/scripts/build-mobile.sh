#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
MOBILE_DIR="$ROOT_DIR/mobile"

# GitHub repo — used when publishing releases
GH_REPO="NADEE-MJ/mentat"

usage() {
  cat <<EOF
Mentat iOS Build CLI

Usage: $0 [options]

Options:
  -d, --deployment-target  iOS deployment target (default: 26.0)
  -p, --publish-release    Publish to GitHub release (default: true)
  -s, --suffix             Suffix for IPA filename (optional)
  -h, --help              Show this help message

Example:
  $0
  $0 -p false
EOF
  exit "${1:-0}"
}

DEPLOYMENT_TARGET="26.0"
PUBLISH_RELEASE=true
SUFFIX=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    -d|--deployment-target)
      DEPLOYMENT_TARGET="$2"
      shift 2
      ;;
    -p|--publish-release)
      case "$2" in
        true|1|yes) PUBLISH_RELEASE=true ;;
        false|0|no) PUBLISH_RELEASE=false ;;
        *) echo "❌ Invalid value for $1: $2"; exit 1 ;;
      esac
      shift 2
      ;;
    -s|--suffix)
      SUFFIX="$2"
      shift 2
      ;;
    -h|--help)
      usage 0
      ;;
    *)
      echo "❌ Unknown option: $1"
      usage 1
      ;;
  esac
done

echo "📱 Mentat iOS Build"
echo "   Deployment Target: $DEPLOYMENT_TARGET"
echo "   Publish Release: $PUBLISH_RELEASE"
echo ""

cd "$MOBILE_DIR"

echo "🔨 Generating Xcode project..."
xcodegen generate

echo "🏗️  Building iOS app..."
xcodebuild \
  -project Mentat.xcodeproj \
  -scheme Mentat \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -derivedDataPath build \
  IPHONEOS_DEPLOYMENT_TARGET="$DEPLOYMENT_TARGET" \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY="" \
  CODE_SIGN_ENTITLEMENTS="" \
  PROVISIONING_PROFILE_SPECIFIER="" \
  DEVELOPMENT_TEAM="" \
  AD_HOC_CODE_SIGNING_ALLOWED=YES \
  COMPILER_INDEX_STORE_ENABLE=NO \
  build

APP_PATH=$(find build/Build/Products/Release-iphoneos -name "*.app" -type d | head -1)
if [[ -z "$APP_PATH" ]]; then
  echo "❌ No .app bundle produced"
  exit 1
fi

VERSION=$(grep 'MARKETING_VERSION:' project.yml | head -1 | sed 's/.*MARKETING_VERSION:[[:space:]]*//' | tr -d '[:space:]')
VERSION_TAG="v$(echo "$VERSION" | tr '.' '_')"

SUFFIX_CLEAN=$(echo "$SUFFIX" | tr -cd '[:alnum:]._-')
if [[ -n "$SUFFIX_CLEAN" ]]; then
  IPA_NAME="sp-${VERSION_TAG}-${SUFFIX_CLEAN}.ipa"
else
  IPA_NAME="sp-${VERSION_TAG}.ipa"
fi

echo "📦 Packaging IPA: $IPA_NAME..."

rm -rf Payload
mkdir -p Payload
cp -R "$APP_PATH" Payload/
zip -r -9 "$IPA_NAME" Payload/
mv "$IPA_NAME" "$ROOT_DIR/$IPA_NAME"

IPA_PATH="$ROOT_DIR/$IPA_NAME"
echo "✅ Created IPA: $IPA_PATH"

if [[ "$PUBLISH_RELEASE" == "true" ]]; then
  echo "🚀 Publishing to GitHub release..."

  GIT_SHA="$(git -C "$ROOT_DIR" rev-parse HEAD)"
  BUILD_TIME=$(TZ=America/Los_Angeles date '+%Y-%m-%d %I:%M %p %Z')

  RELEASE_TAG="mentat-mobile-v${VERSION}"
  RELEASE_TITLE="Mentat iOS v${VERSION}"
  RELEASE_NOTES="Unsigned iOS build for Mentat v${VERSION}.\n\n**Built:** ${BUILD_TIME}\n**Commit:** ${GIT_SHA}"

  if ! gh api "repos/${GH_REPO}/git/ref/tags/${RELEASE_TAG}" >/dev/null 2>&1; then
    gh api -X POST "repos/${GH_REPO}/git/refs" \
      -f "ref=refs/tags/${RELEASE_TAG}" \
      -f "sha=${GIT_SHA}"
    echo "Created tag ${RELEASE_TAG}"
  fi

  if gh release view "$RELEASE_TAG" --repo "$GH_REPO" >/dev/null 2>&1; then
    gh release edit "$RELEASE_TAG" --repo "$GH_REPO" --title "$RELEASE_TITLE" --notes "$RELEASE_NOTES"
  else
    gh release create "$RELEASE_TAG" --repo "$GH_REPO" --title "$RELEASE_TITLE" --notes "$RELEASE_NOTES"
  fi

  gh release upload "$RELEASE_TAG" --repo "$GH_REPO" "$IPA_PATH#${IPA_NAME}" --clobber

  echo "✅ Published release: https://github.com/${GH_REPO}/releases/tag/${RELEASE_TAG}"
fi

echo ""
echo "✅ Build complete!"
if [[ "$PUBLISH_RELEASE" != "true" ]]; then
  echo "   IPA: $IPA_PATH"
fi
