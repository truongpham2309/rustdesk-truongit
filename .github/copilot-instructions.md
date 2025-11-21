<!-- Copied/merged guidance for AI coding agents working in this repo. -->

# Copilot Instructions (short)

This repository is a Rust core with a Flutter UI. Be concise, change only what's needed, and prefer small, well-scoped edits.

- **Big picture**: core runtime and services live in `src/` (Rust). UI is Flutter under `flutter/`. Shared libraries and platform code are in `libs/` (e.g. `libs/hbb_common`, `libs/scrap`, `libs/enigo`, `libs/clipboard`). Packaging and build orchestration is performed by `build.py`.

- **Important files to reference**:
  - `build.py` — canonical build flow and flags (`--flutter`, `--hwcodec`, `--vram`, `--portable`, `--skip-cargo`). Use it to discover packaging rules.
  - `Cargo.toml` and `src/` — Rust crate entry points and features.
  - `flutter/` — Flutter app, `flutter/lib/generated_bridge.dart` (ffi bridge), and `src/flutter_ffi.rs` (Rust FFI input).
  - `libs/hbb_common/src/config.rs` — runtime configuration structures.
  - `src/rendezvous_mediator.rs` — network/rendezvous protocol with rustdesk-server (integration surface).

- **Developer workflows (most-used commands)**
  - Build and run Rust debug: `cargo run` (root)
  - Build release Rust binary: `cargo build --release`
  - Build Flutter+Rust (recommended): `python3 build.py --flutter` (accepts `--release`, `--hwcodec`, `--vram`, `--portable`)
  - Build Android/iOS (flutter): `cd flutter && flutter build android` / `flutter build ios`
  - Tests: `cargo test` and `cd flutter && flutter test`

- **Cross-component patterns to follow**
  - Feature flags: `build.py` collects features and passes them to `cargo`. To enable platform features use the same flags (e.g. `--hwcodec` → `hwcodec`).
  - FFI: Flutter ↔ Rust uses generated bindings. The Rust input is `src/flutter_ffi.rs`; the generated Dart file is `flutter/lib/generated_bridge.dart`. Regenerate bindings when changing FFI signatures (build pipeline in `build.py`).
  - Native libs: vcpkg-managed C++ libs (libvpx/libyuv/opus/aom) are required for hw codec features. Expect `VCPKG_ROOT` env var and platform-specific packaging in `build.py`.

- **Integration & build nuances**
  - The `libs/virtual_display/dylib` subproject is built separately on Windows during packaging (`build.py`), so edits to that crate may require rebuilding that target.
  - legacy Sciter UI lives in `src/ui/` but is deprecated — prefer Flutter edits unless explicitly maintaining legacy UI.
  - Packaging: `build.py` contains platform packaging steps (deb, dmg, portable exe). Consult it for exact file locations (e.g. where build artifacts are copied into `flutter/` packaging directories).

- **What to change vs avoid**
  - Change: small focused fixes, API surface in `src/`, Flutter widgets and platform-specific glue in `flutter/` and `libs/*`.
  - Avoid: large refactors crossing Rust ↔ Flutter FFI boundaries without updating `src/flutter_ffi.rs` and re-running the bridge generation. Avoid changing build.py unless you fully understand packaging impact.

- **Examples (copyable)**
  - Build Flutter desktop release with hwcodec: `python3 build.py --flutter --hwcodec --release`
  - Run unit tests (Rust): `cargo test`
  - Regenerate Dart FFI bridge (part of build): `~/.cargo/bin/flutter_rust_bridge_codegen --rust-input ./src/flutter_ffi.rs --dart-output ./flutter/lib/generated_bridge.dart`

- **Where to look for more context**
  - `README.md` (root) — platform-specific prerequisites and vcpkg instructions.
  - `CLAUDE.md` — contains a compact dev-commands crib (mirrors much of the above).

If anything is unclear or you want more detail on a specific area (packaging, FFI, or a sub-library), tell me which area and I will expand or merge more verbatim content from docs found in the repo.
