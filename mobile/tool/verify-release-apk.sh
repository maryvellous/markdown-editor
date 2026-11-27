#!/usr/bin/env bash
set -euo pipefail
apk="$1"
version="$2"
build="$3"
sdk="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-}}"
if [[ -z "$sdk" ]]; then echo "Android SDK not configured" >&2; exit 1; fi
tools="$(find "$sdk/build-tools" -mindepth 1 -maxdepth 1 -type d | sort -V | tail -n 1)"
[[ -x "$tools/apksigner" && -x "$tools/aapt" ]]
if [[ "${GITHUB_REF:-}" == refs/tags/mobile-v* || "${SIGN_RELEASE_APK:-false}" == true ]]; then
  : "${ANDROID_RELEASE_KEYSTORE_B64:?Configure the approved stable signing keystore}"
  : "${ANDROID_RELEASE_STORE_PASSWORD:?Missing signing store password}"
  : "${ANDROID_RELEASE_KEY_PASSWORD:?Missing signing key password}"
  : "${ANDROID_RELEASE_KEY_ALIAS:?Missing signing alias}"
  : "${ANDROID_RELEASE_CERT_SHA256:?Missing approved signing certificate fingerprint}"
  umask 077
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' EXIT
  printf '%s' "$ANDROID_RELEASE_KEYSTORE_B64" | base64 --decode > "$tmp/release.jks"
  "$tools/apksigner" sign --ks "$tmp/release.jks" --ks-key-alias "$ANDROID_RELEASE_KEY_ALIAS" \
    --ks-pass env:ANDROID_RELEASE_STORE_PASSWORD --key-pass env:ANDROID_RELEASE_KEY_PASSWORD \
    --out "$tmp/signed.apk" "$apk"
  mv "$tmp/signed.apk" "$apk"
fi
certs="$("$tools/apksigner" verify --verbose --print-certs "$apk")"
printf '%s\n' "$certs"
if [[ "${GITHUB_REF:-}" == refs/tags/mobile-v* || "${SIGN_RELEASE_APK:-false}" == true ]]; then
  grep -qx 'Number of signers: 1' <<< "$certs" || { echo 'Expected exactly one APK signer' >&2; exit 1; }
  actual="$(printf '%s\n' "$certs" | sed -nE 's/^(Signer #1|V[0-9.]+ Signer): certificate SHA-256 digest: ([0-9a-fA-F]+)$/\2/p' | sort -u | tr '[:upper:]' '[:lower:]')"
  expected="$(printf '%s' "$ANDROID_RELEASE_CERT_SHA256" | tr -d ':' | tr '[:upper:]' '[:lower:]')"
  [[ "$expected" =~ ^[0-9a-f]{64}$ && "$actual" == "$expected" ]] || { echo "Unexpected APK signing certificate" >&2; exit 1; }
fi
badging="$("$tools/aapt" dump badging "$apk")"
metadata="$(printf '%s\n' "$badging" | sed -n '/^package: /p')"
[[ "$metadata" == *"name='dev.diaspro.diaspro_markdown_mobile'"* && "$metadata" == *"versionCode='$build'"* && "$metadata" == *"versionName='$version'"* ]] || { echo "Unexpected APK metadata: $metadata" >&2; exit 1; }
printf '%s\n' "$metadata"
