# Development Log

[English](development-log.md) | [日本語](development-log.ja.md)

This document tracks the implementation status, design notes, and known limitations of `mizchi/v8`. For the user-facing entry point, see [README.md](../README.md). For the full public surface, see [src/README.mbt.md](../src/README.mbt.md).

## Goals

- provide a thin native binding so MoonBit can drive V8 directly
- keep as much runtime logic as possible on the MoonBit side
- keep the Rust side focused on isolate/context management and the C ABI bridge
- provide a base for experimenting with Node / Deno-style event loops

## Current Status

### Core Runtime

- [x] `runtime_new`, `runtime_new_with_snapshot`
- [x] `eval_string`, `eval_async_string`, `eval_module_string`
- [x] named script origins and entry module specifiers
- [x] `perform_microtask_checkpoint`
- [x] `V8Error`-based error contract

### Value Bridge

- [x] `eval_json`, `eval_bytes`, `eval_async_json`, `eval_async_bytes`
- [x] `set/get/call_global_json`
- [x] `set/get/call_global_bytes`

### Promise / Module Handle

- [x] `PromiseHandle::state`, `result_*`, `await_*`
- [x] `ModuleHandle::export_names`, `get_export_*`, `call_export_*`
- [x] asynchronous top-level await module evaluation through `ModuleEvalHandle`

### Module Loading

- [x] `Runtime::load_module`, `load_modules`
- [x] static import / dynamic import
- [x] relative specifier resolution
- [x] reusable runtime images with preloaded modules

### Snapshot / Bootstrap

- [x] `snapshot_create`, `snapshot_extend`
- [x] `SnapshotBuilder`
- [x] `RuntimeBuilder`
- [x] `RuntimeImage`

### Host Bridge

- [x] sync JSON op
- [x] sync bytes op
- [x] async JSON op queue
- [x] async bytes op queue
- [x] sync JSON callback
- [x] sync bytes callback
- [ ] async host callback
- [ ] richer host op surface

## Current Limitations

- native target only
- only one runtime can exist at a time
- no Node / Deno compatibility layer
- async host integration is still queue-based because async host callbacks are not implemented

## Design Notes

- keep `Runtime` and handle types on the MoonBit side, and isolate the Rust bridge in a small staticlib
- hide `rusty_v8` initialization and link complexity behind the Rust layer
- stabilize the public API in MoonBit while keeping the Rust implementation replaceable
- focus first on JSON and bytes as the two value lanes needed for runtime-loop experiments

## Where To Look Next

- package API index: [src/README.mbt.md](../src/README.mbt.md)
- release history: [CHANGELOG.md](../CHANGELOG.md)
- Rust bridge implementation: [native/bridge/src/lib.rs](../native/bridge/src/lib.rs)
