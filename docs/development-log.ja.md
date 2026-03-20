# Development Log

[English](development-log.md) | [日本語](development-log.ja.md)

この文書は `mizchi/v8` の実装状況、設計メモ、既知の制約を追うためのものです。利用者向けの導線は [README.ja.md](../README.ja.md)、完全な public surface は [src/README.mbt.md](../src/README.mbt.md) に置いています。

## ゴール

- MoonBit から V8 を扱うための薄い native binding を作る
- runtime のロジックはなるべく MoonBit 側に寄せる
- Rust 側は isolate/context 管理と C ABI の橋渡しに留める
- Node / Deno 風イベントループの実験土台を作る

## 現在の実装状況

### Core Runtime

- [x] `runtime_new`, `runtime_new_with_snapshot`
- [x] `eval_string`, `eval_async_string`, `eval_module_string`
- [x] named script origin / entry module specifier
- [x] `perform_microtask_checkpoint`
- [x] `V8Error` ベースの error contract

### Value Bridge

- [x] `eval_json`, `eval_bytes`, `eval_async_json`, `eval_async_bytes`
- [x] `set/get/call_global_json`
- [x] `set/get/call_global_bytes`

### Promise / Module Handle

- [x] `PromiseHandle::state`, `result_*`, `await_*`
- [x] `ModuleHandle::export_names`, `get_export_*`, `call_export_*`
- [x] `ModuleEvalHandle` による top-level await module の非同期評価

### Module Loading

- [x] `Runtime::load_module`, `load_modules`
- [x] static import / dynamic import
- [x] relative specifier resolution
- [x] preload module を含む reusable runtime image

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

## 現在の制約

- native target のみを対象にしている
- `rusty_v8::OwnedIsolate` の扱いに合わせて、同時に 1 runtime のみ許可している
- Node / Deno 互換層は提供していない
- async host callback はまだないので、非同期 host 連携は queue ベースの op で回す前提
- 現状は mooncakes から import する consumer module 側にも prebuild と link glue が必要

## 設計メモ

- MoonBit 側は `Runtime` と handle 群、Rust 側は小さい staticlib bridge に分離する
- `rusty_v8` の複雑な初期化やリンクは Rust 側に閉じ込める
- public API は MoonBit で安定化し、Rust 実装は再生成・差し替えしやすい構造を保つ
- 値 bridge はまず JSON / bytes の 2 lane に絞り、イベントループ実験で必要な経路を先に揃える

## 次に見る場所

- package API 一覧: [src/README.mbt.md](../src/README.mbt.md)
- リリース履歴: [CHANGELOG.md](../CHANGELOG.md)
- Rust bridge 実装: [native/bridge/src/lib.rs](../native/bridge/src/lib.rs)
