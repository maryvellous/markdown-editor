#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BUILD_DIR="$ROOT/.mobile-build"

rm -rf "$BUILD_DIR"
flutter create \
  --platforms=android \
  --org dev.diaspro \
  --project-name diaspro_markdown_mobile \
  "$BUILD_DIR"

rm -rf "$BUILD_DIR/lib" "$BUILD_DIR/test"
rm -f "$BUILD_DIR/analysis_options.yaml"
cp -R "$ROOT/mobile/lib" "$BUILD_DIR/lib"
cp "$ROOT/mobile/pubspec.yaml" "$BUILD_DIR/pubspec.yaml"

mkdir -p "$BUILD_DIR/android/app/src/main/kotlin/dev/diaspro/diaspro_markdown_mobile"
cp "$ROOT/mobile/android/MainActivity.kt" \
  "$BUILD_DIR/android/app/src/main/kotlin/dev/diaspro/diaspro_markdown_mobile/MainActivity.kt"
cp "$ROOT/mobile/android/AndroidManifest.xml" \
  "$BUILD_DIR/android/app/src/main/AndroidManifest.xml"

# Sovrascrive le risorse launcher generate da Flutter con l'identità Diaspro.
# anydpi mantiene l'icona vettoriale nitida su tutte le densità, mentre le
# varianti v26/v33 abilitano adaptive icon e themed icon sui telefoni recenti.
if [[ -d "$ROOT/mobile/android/res" ]]; then
  cp -R "$ROOT/mobile/android/res/." "$BUILD_DIR/android/app/src/main/res/"
fi

printf 'Android bootstrap completato in %s\n' "$BUILD_DIR"
