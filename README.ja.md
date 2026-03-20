# mizchi/v8

[English](README.md) | [日本語](README.ja.md)

`mizchi/v8` は、MoonBit から V8 を扱うための native 専用バインディングです。Node や Deno のような埋め込みランタイムを、MoonBit 主導で試作するための土台として作っています。

## できること

- script / module を MoonBit から評価する
- JS の値を `String` / JSON / `Bytes` でやり取りする
- pending Promise や top-level await module を host 側 handle として保持する
- preload module、relative import、dynamic import を扱う
- snapshot / runtime image を作って isolate 起動を再利用する
- `MoonBit.opSync(...)` / `MoonBit.opAsync(...)` を使って host 側イベントループを試す

## ステータス

- バージョン: `0.1.0`
- 対応 target: `native`
- embedder 実験用として使える状態です
- 実装状況と未実装項目は [docs/development-log.ja.md](docs/development-log.ja.md) に分離しています

## Quick Start

```bash
git clone https://github.com/mizchi/v8.mbt
cd v8.mbt
just bootstrap
just test
```

`just bootstrap` は `deps/rusty_v8` と Rust bridge をビルドし、MoonBit からリンクできる状態を作ります。

## 最小例

一発評価だけならトップレベル helper で十分です。

```moonbit
match @v8.eval_string("'Hello' + ', MoonBit!'") {
  Ok(value) => println(value)
  Err(err) => println(err.to_string())
}
```

長寿命 `Runtime` を使うと、module preload や snapshot 初期化をまとめて扱えます。

```moonbit
let builder = @v8.runtime_builder_new()
  .eval_snapshot("globalThis.base = 40;")
  .load_module("dep", "export const answer = globalThis.base + 2;")

match builder.with_runtime(fn(runtime) {
  runtime.eval_async_json(
    "(async () => { let mod = await import('dep'); return { answer: mod.answer } })()",
  )
}) {
  Ok(value) => println(value)
  Err(err) => println(err.to_string())
}
```

host 側イベントループの実験では、`opAsync` を queue として捌けます。

```moonbit
match @v8.runtime_new() {
  Ok(runtime) => {
    ignore(runtime.register_async_json_op("add"))
    let promise = runtime.eval_promise_string("MoonBit.opAsync('add', [20, 22])")
    match runtime.take_async_json_op() {
      Ok(Some(op)) => ignore(runtime.resolve_async_json_op(op.id, "{\"answer\":42}"))
      _ => ()
    }
    println(
      promise
      |> Result::map(fn(handle) { handle.await_json() })
      |> Result::flatten,
    )
    runtime.dispose()
  }
  Err(err) => println(err.to_string())
}
```

## 主要 API

- 評価系: `Runtime`, `eval_*`, `eval_module_*`, `perform_microtask_checkpoint`
- 非同期 handle: `PromiseHandle`, `ModuleEvalHandle`, `ModuleHandle`
- bootstrap: `Runtime::load_module`, `RuntimeBuilder`, `SnapshotBuilder`, `RuntimeImage`
- 値 bridge: `set/get/call_global_json`, `set/get/call_global_bytes`, `eval_json`, `eval_bytes`
- host bridge: `register_sync_*_callback`, `register_*_op`, `take_*_op`, `resolve_*_op`, `reject_*_op`

完全な public surface と追加例は [src/README.mbt.md](src/README.mbt.md) を参照してください。

## 制約

- native target 専用です
- 同時に 1 runtime のみ許可しています
- async host callback surface は未実装です
- Node / Deno 互換 API ではなく、embedder 向けの低レベル binding を狙っています

## ドキュメント

- パッケージ API と実行例: [src/README.mbt.md](src/README.mbt.md)
- 実装状況と今の制約: [docs/development-log.ja.md](docs/development-log.ja.md)
- English README: [README.md](README.md)
- リリース差分: [CHANGELOG.md](CHANGELOG.md)

## ライセンス

Apache-2.0
