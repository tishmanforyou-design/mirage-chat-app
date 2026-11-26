#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Mirage Chat App — Automated Setup, Native Runtime Fetch & Release APK Builder
# Runs on macOS / Linux with Flutter SDK, Android NDK, and curl installed.
# ==============================================================================

CACTUS_RELEASE="${CACTUS_RELEASE:-4.1.1}"
CACTUS_BASE_URL="https://huggingface.co/Cactus-Compute/cactus/resolve/main/releases/${CACTUS_RELEASE}"
MIRAGE_WEIGHTS_URL="https://huggingface.co/Cactus-Compute/mirage/resolve/main/mirage.cact"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "==> [1/6] Checking Flutter & toolchain..."
command -v flutter >/dev/null 2>&1 || { echo "ERROR: flutter not found in PATH."; exit 1; }
command -v curl >/dev/null 2>&1 || { echo "ERROR: curl not found in PATH."; exit 1; }

# Generate platform folders (android/ios/etc.) if not yet scaffolded
if [ ! -f "android/settings.gradle.kts" ] && [ ! -f "android/settings.gradle" ]; then
  echo "==> Scaffolding Flutter platform runners..."
  flutter create --project-name mirage_chat_app --org com.cactuscompute --platforms android,ios .
fi

echo "==> [2/6] Downloading Cactus ${CACTUS_RELEASE} prebuilt Android native libraries..."
for ARCH in android-arm64 android-armv7; do
  DEST="android/app/src/main/cpp/cactus/${ARCH}"
  mkdir -p "$DEST"
  if [ ! -f "${DEST}/libcactus.a" ]; then
    echo "    Fetching ${ARCH}/libcactus.a..."
    curl -fL "${CACTUS_BASE_URL}/${ARCH}/libcactus.a" -o "${DEST}/libcactus.a"
  fi
  if [ ! -f "${DEST}/cactus.h" ]; then
    echo "    Fetching ${ARCH}/cactus.h..."
    curl -fL "${CACTUS_BASE_URL}/${ARCH}/cactus.h" -o "${DEST}/cactus.h"
  fi
done

echo "==> [3/6] Downloading Mirage 2-bit quantized weights (21.6 MB) into assets/models/..."
mkdir -p assets/models
if [ ! -f "assets/models/mirage.cact" ]; then
  curl -fL "${MIRAGE_WEIGHTS_URL}" -o assets/models/mirage.cact
fi
ls -lh assets/models/mirage.cact

echo "==> [4/6] Resolving Flutter packages (flutter pub get)..."
flutter pub get

echo "==> [5/6] Running static analysis (flutter analyze)..."
flutter analyze

echo "==> [6/6] Building Android release APK (arm64-v8a & armeabi-v7a)..."
flutter build apk --release --target-platform android-arm64,android-arm

echo ""
echo "✅ Build complete! Release APK:"
echo "   build/app/outputs/flutter-apk/app-release.apk"
