# Release engineering

Desktop and Android have independent version numbers and tags. Current published baselines: Windows 0.4.1 and Android 1.1.1+4. Candidate source versions: Windows 0.4.2 and Android 1.1.2+5. No candidate is a published release until explicit approval and version tags.

## Windows
- One workflow builds and tests the same installer for PR, main and explicit `v<version>` tags. The publish job runs only for tags after build success, downloads the exact checked artifact, and verifies SHA-256 again.
- Desktop version must match package.json, npm lock root, Cargo manifest/lock, Tauri and installer config.
- CI smoke test performs silent installation on a disposable runner, checks installed executable checksum and both HKCU associations, uninstalls and verifies removal and an external document sentinel.
- The vendored Inno generator now supports opt-in ShellNew for .md, OpenWith registration and preservation of existing defaults. Smoke checks inspect registry values and cleanup. This is not an upgrade test or a visual test: verify Explorer's actual New menu and legacy installer upgrades separately.
- Windows Authenticode signing is not configured by this change. SHA-256 verifies integrity, not publisher identity.

## Android
- PR/main builds remain test APKs; verify package ID, version name/code and APK signature. Do not confuse them with upgrade-compatible release artifacts.
- Tags require a stable, approved keystore, alias and passwords configured as GitHub secrets: ANDROID_RELEASE_KEYSTORE_B64, ANDROID_RELEASE_STORE_PASSWORD, ANDROID_RELEASE_KEY_PASSWORD, ANDROID_RELEASE_KEY_ALIAS. Set repository variable ANDROID_RELEASE_CERT_SHA256 to the approved SHA-256 certificate fingerprint (public metadata). No signing credentials belong in git, chat or logs.
- The PR pipeline inspects the actual previously published 1.1.1 APK certificate and tests signing and rejection paths with a disposable CI-only key. Recover/compare the previously distributed APK certificate first (apksigner verify --print-certs). If the matching private key is unavailable, a new signing identity is a deliberate migration: Android generally rejects in-place updates signed with another certificate. Back up documents before any uninstall, account for local recent snapshots and SAF grants, and explicitly approve migration.
- Increase both Android versionName and versionCode for the next public version. Run the Android workflow manually on main with `sign_candidate` enabled (no publication), download the signed candidate, and follow the migration/upgrade checks in the validation checklist before public release. A differently signed legacy APK cannot normally be updated in place. Tag publication is blocked without stable signing configuration.
- Both workflows publish checksum assets and do not overwrite an existing release.

## Release checklist (not completed by CI alone)
See [release validation](release-validation.md) for detailed acceptance tests and [Android signing setup](android-signing-setup.md) for owner-controlled configuration.
1. Decide next independent versions and update manifests/locks consistently; record changes.
2. Verify green CI and download candidate installer/APK; verify hashes.
3. On Windows: clean install, file open via Explorer, shortcuts, New menu, save CRLF, checkbox preview, Mermaid, dirty close, upgrade from previous installer without losing documents/recents, then uninstall.
4. On Android: clean install, SAF open/save/save as, cancel incoming document, save during edits, undo/redo, Mermaid pan/fit, tablet layout; verify in-place update and retained documents/recents/permissions with matching signing identity.
5. Only after approval create new version tags; verify published assets, hashes and release notes. Do not overwrite tags/releases or assume that CI green is physical-device validation.
