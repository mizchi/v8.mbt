# Changelog

All notable changes to this project should be documented in this file.

## [Unreleased]

### Added

- Property-based test example with `moonbitlang/quickcheck`
- Package-level `src/README.mbt.md` with executable examples
- `just ci`, `just ci-all`, `just fmt-check`, and `just info-check`
- Direct async host callbacks via `register_async_json_callback` and `register_async_bytes_callback`
- Result-based host callbacks that can throw/reject via `register_*_result_callback`
- JSON-valued throw/reject reasons via `register_*_result_callback_with_json_error` and `reject_async_*_op_with_json`
- Multiple runtimes can now coexist in the same process
- Bundled `src/scripts/setup-consumer.mjs` to automate the common mooncakes consumer setup path
- `setup-consumer.mjs --build-bridge` to cover local path dependency bootstrapping from the same helper

### Changed

- GitHub Actions CI now verifies formatting and generated `.mbti` files
- CI now runs `native` checks on both Ubuntu and macOS
- Root README is now user-facing and split into English and Japanese entry points
- `moon.mod.json` now points `readme` to `README.md`
- Published package now includes a consumer-side prebuild helper for mooncakes installs
- README now documents the current Moon `0.1.20260309` / MoonBit `v0.8.3` requirement for consumer-side prebuild and link setup

### Fixed

- Removed the broken `hello()` example from the published README path
- Aligned local `just` workflows with the CI entrypoints
- Packaged docs now explain the native build prerequisites and current mooncakes consumer limitation

## [0.1.2] - 2026-02-12

### Changed

- Baseline template state before release-workflow hardening.
