# Dependency management

The repository commits the package-manager-generated `package-lock.json`, `src-tauri/Cargo.lock`, and `mobile/pubspec.lock`. They were generated on the same toolchain versions as the successful baseline CI, not hand-written.

- Desktop: Node.js from `.node-version` (npm 11.20.0 in the baseline), Rust from `rust-toolchain.toml`. Run `npm ci`, `cargo test --locked --manifest-path src-tauri/Cargo.toml`, and `npm run tauri -- build --no-bundle -- --locked`.
- Android: Flutter 3.47.0, Temurin JDK 17.0.21+9 in CI. Bootstrap copies the committed lockfile into the generated scaffold. Run `flutter pub get --enforce-lockfile`, followed by `flutter analyze --no-pub`, `flutter test --no-pub` and `flutter build apk --release --no-pub` in `.mobile-build`.
- CI rejects lockfile drift and pins directly used workflow actions to full commit SHAs. The Inno Setup download is checksum-verified.

To update a dependency, intentionally change its manifest and regenerate the corresponding lockfile with the pinned toolchain. Review both files and run all platform checks in a focused PR. For Flutter, regenerate `mobile/pubspec.lock` from `mobile/` before running the bootstrap. Do not edit lockfiles by hand.

Locked resolution is not a promise of bit-for-bit identical executables: hosted runner images, generated Android scaffold/native tooling and signing still influence build output. Release signing and deeper reproducibility checks remain separate tasks.
