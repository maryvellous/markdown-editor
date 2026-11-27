# Android signing setup (owner-controlled computer)

The published 1.1.1 APK was inspected in CI run 46057821039: Android Debug, SHA-256 certificate ba518176666a73cd2deed9a053ec22ba2913599fa5e7a9d50600a4abb0a3e747. The original workflow used an ephemeral GitHub-hosted Ubuntu runner and no persistent signing secret. No matching private key is known; do not assume it can be recovered from the public certificate.

## Recover or migrate
Inspect any existing local backup/debug keystore before creating a replacement:

```powershell
./mobile/tool/setup-release-signing.ps1 -Keystore "$env:USERPROFILE/.android/debug.keystore" -Alias androiddebugkey
```

If none matches, create a dedicated PKCS12 keystore on the owner's private local drive (not inside a repository, shared folder or chat upload). The script prompts for a unique password and never prints it.

```powershell
./mobile/tool/setup-release-signing.ps1 -Keystore "$env:LOCALAPPDATA/Diaspro/Signing/markdown.p12" -CreateNew -AllowNewIdentity
```

Make an encrypted offline backup of the keystore and store the password in a password manager. Then configure GitHub directly with authenticated GitHub CLI and JDK keytool:

```powershell
./mobile/tool/setup-release-signing.ps1 -Keystore "$env:LOCALAPPDATA/Diaspro/Signing/markdown.p12" -AllowNewIdentity -ConfigureGitHub
```

For a recovered matching keystore use its path and alias without -AllowNewIdentity. The script refuses to overwrite any existing signing configuration; if an operation fails midway, reconcile it using GitHub settings without replacing a known-good key. It does not create tags or publish anything. No key or password should be uploaded to chat, committed or stored as an artifact.

## Candidate and device validation
Run the Build Android APK workflow manually from main with sign_candidate=true. Verify that the artifact fingerprint matches the configured fingerprint. Back up all local documents and any recent-only snapshots before removing an old differently signed app. SAF permissions and app-private history may be lost. Do not uninstall until the backup is verified. For later versions, install over the existing signed candidate, without uninstall, and verify data retention. Actual production signing, owner backup and physical-device migration are outstanding until performed.
