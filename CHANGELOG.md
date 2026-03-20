# Changelog

All notable changes to this project should be documented in this file.

## [Unreleased]

### Added

- Property-based test example with `moonbitlang/quickcheck`
- Package-level `src/README.mbt.md` with executable examples
- `just ci`, `just ci-all`, `just fmt-check`, and `just info-check`

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
