#!/usr/bin/env bash
set -euo pipefail
apk="$1"
version="$2"
build="$3"
root="$(cd "$(dirname "$0")" && pwd)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
umask 077
# This key is disposable, never used for distribution, and never uploaded.
export ANDROID_RELEASE_KEY_ALIAS=ci-test
export ANDROID_RELEASE_STORE_PASSWORD=ci-test-only
export ANDROID_RELEASE_KEY_PASSWORD=ci-test-only
keytool -genkeypair -keystore "$work/test.p12" -storetype PKCS12 \
  -storepass "$ANDROID_RELEASE_STORE_PASSWORD" -keypass "$ANDROID_RELEASE_KEY_PASSWORD" \
  -alias "$ANDROID_RELEASE_KEY_ALIAS" -dname "CN=CI Test Only" -keyalg RSA -keysize 2048 -validity 1
export ANDROID_RELEASE_KEYSTORE_B64="$(base64 -w0 "$work/test.p12")"
export ANDROID_RELEASE_CERT_SHA256="$(keytool -exportcert -alias "$ANDROID_RELEASE_KEY_ALIAS" \
  -keystore "$work/test.p12" -storepass "$ANDROID_RELEASE_STORE_PASSWORD" | sha256sum | cut -d' ' -f1)"
export SIGN_RELEASE_APK=true
cp "$apk" "$work/signed.apk"
bash "$root/verify-release-apk.sh" "$work/signed.apk" "$version" "$build"
# Reject a mismatched expected certificate, even when signing itself succeeds.
if ANDROID_RELEASE_CERT_SHA256="$(printf '%064d' 0)" \
  bash "$root/verify-release-apk.sh" "$work/signed.apk" "$version" "$build"; then
  echo "Wrong fingerprint unexpectedly accepted" >&2; exit 1
fi
# Reject missing key material before any publication.
if ANDROID_RELEASE_KEYSTORE_B64="" \
  bash "$root/verify-release-apk.sh" "$work/signed.apk" "$version" "$build"; then
  echo "Missing keystore unexpectedly accepted" >&2; exit 1
fi
echo "Disposable signing and negative checks passed."
