# mizchi/v8

MoonBit から V8 を叩くためのネイティブバインディングです。Node や Deno のような埋め込みランタイムを、できるだけ MoonBit 側に寄せて試作するための土台として作っています。

現在の binding surface は次です。

- Runtime / eval
  `runtime_new`, `runtime_new_with_snapshot`, `Runtime::eval_string`, `eval_json`, `eval_bytes`, `eval_async_*`, `eval_*_with_name`, `perform_microtask_checkpoint`
- Promise / module handles
  `Runtime::eval_promise_string`, `PromiseHandle::state / result_* / await_* / dispose`, `Runtime::eval_module_handle_string`, `Runtime::eval_module_handle_async_string`, `ModuleEvalHandle::promise_handle / await_ready / dispose`, `ModuleHandle::export_names / get_export_* / call_export_* / dispose`
- Host bridge
  `Runtime::set/get/call_global_json`, `set/get/call_global_bytes`, `register_sync_json_callback`, `register_sync_bytes_callback`, `register/push/take_sync_*_op`, `register/take/resolve/reject_async_*_op`
- Module / snapshot bootstrap
  `Runtime::load_module`, `RuntimeBuilder`, `RuntimeImage`, `SnapshotBuilder`, `snapshot_create`, `snapshot_extend`
- Error contract
  V8 例外を `Result[..., V8Error]` に変換し、`rusty_v8` とは薄い C ABI で接続

## Quick Start

```bash
git clone https://github.com/mizchi/v8
cd v8
just bootstrap
just test
just run
```

`just bootstrap` は `deps/rusty_v8` を取得し、`native/bridge` の Rust staticlib をビルドして MoonBit からリンクできる状態にします。

## API

```moonbit
match @v8.eval_string("'Hello' + ', MoonBit!'") {
  Ok(value) => println(value)
  Err(err) => println(err.to_string())
}
```

Promise を待つ場合:

```moonbit
match @v8.eval_async_string("(async () => { return (await Promise.resolve(39)) + 3 })()") {
  Ok(value) => println(value)
  Err(err) => println(err.to_string())
}
```

Promise を host 側で保持して、自前の microtask loop で進める場合:

```moonbit
match @v8.runtime_new() {
  Ok(runtime) => {
    ignore(runtime.eval_string(
      "globalThis.__resolve_later = null; globalThis.__tracked = new Promise((resolve) => { globalThis.__resolve_later = resolve })",
    ))
    let promise = runtime.eval_promise_string("globalThis.__tracked")
    ignore(runtime.eval_string("globalThis.__resolve_later(42)"))
    ignore(runtime.perform_microtask_checkpoint())
    println(
      promise
      |> Result::map(fn(promise) { promise.result_string() })
      |> Result::flatten,
    )
    runtime.dispose()
  }
  Err(err) => println(err.to_string())
}
```

Promise の結果を型を潰さず JSON/bytes で読む場合:

```moonbit
match @v8.runtime_new() {
  Ok(runtime) => {
    let promise = runtime.eval_promise_string(
      "(async () => ({ answer: 42, ok: true }))()",
    )
    ignore(runtime.perform_microtask_checkpoint())
    println(
      promise
      |> Result::map(fn(handle) { handle.result_json() })
      |> Result::flatten,
    )
    runtime.dispose()
  }
  Err(err) => println(err.to_string())
}
```

PromiseHandle 側で checkpoint を内包して待つ場合:

```moonbit
match @v8.runtime_new() {
  Ok(runtime) => {
    let promise = runtime.eval_promise_string(
      "(async () => ({ answer: 42, ok: true }))()",
    )
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

MoonBit 側イベントループで async op を捌く場合:

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

同期 JSON op を固定応答テーブルで返す場合:

```moonbit
match @v8.runtime_new() {
  Ok(runtime) => {
    ignore(runtime.register_sync_json_op("add"))
    ignore(runtime.push_sync_json_op_response(
      "add", "[20,22]", "{\"answer\":42}",
    ))
    println(runtime.eval_json("MoonBit.opSync('add', [20, 22])"))
    println(runtime.take_sync_json_op())
    runtime.dispose()
  }
  Err(err) => println(err.to_string())
}
```

同期 JSON op を MoonBit callback で直接捌く場合:

```moonbit
match @v8.runtime_new() {
  Ok(runtime) => {
    let base = 40
    ignore(runtime.register_sync_json_callback("add", fn(payload) {
      if payload == "[20,22]" {
        "{\"answer\":" + (base + 2).to_string() + "}"
      } else {
        "{\"answer\":0}"
      }
    }))
    println(runtime.eval_json("MoonBit.opSync('add', [20, 22])"))
    println(runtime.take_sync_json_op())
    runtime.dispose()
  }
  Err(err) => println(err.to_string())
}
```

同期 bytes op を固定応答テーブルで返す場合:

```moonbit
match @v8.runtime_new() {
  Ok(runtime) => {
    ignore(runtime.register_sync_bytes_op("reverse"))
    ignore(runtime.push_sync_bytes_op_response(
      "reverse",
      @utf8.encode("ABC"),
      @utf8.encode("CBA"),
    ))
    println(
      runtime.eval_bytes(
        "MoonBit.opSyncBytes('reverse', new Uint8Array([65, 66, 67]))",
      ).map(@utf8.decode_lossy),
    )
    println(runtime.take_sync_bytes_op())
    runtime.dispose()
  }
  Err(err) => println(err.to_string())
}
```

同期 bytes op を MoonBit callback で直接捌く場合:

```moonbit
match @v8.runtime_new() {
  Ok(runtime) => {
    let suffix = @utf8.encode("!")
    ignore(runtime.register_sync_bytes_callback("decorate", fn(payload) {
      @utf8.encode(@utf8.decode_lossy(payload) + @utf8.decode_lossy(suffix))
    }))
    println(
      runtime.eval_bytes(
        "MoonBit.opSyncBytes('decorate', new Uint8Array([65, 66]))",
      ).map(@utf8.decode_lossy),
    )
    println(runtime.take_sync_bytes_op())
    runtime.dispose()
  }
  Err(err) => println(err.to_string())
}
```

binary payload の async op を捌く場合:

```moonbit
match @v8.runtime_new() {
  Ok(runtime) => {
    ignore(runtime.register_async_bytes_op("reverse"))
    let promise = runtime.eval_promise_string(
      "MoonBit.opAsyncBytes('reverse', new Uint8Array([65, 66, 67]))",
    )
    match runtime.take_async_bytes_op() {
      Ok(Some(op)) => ignore(runtime.resolve_async_bytes_op(op.id, @utf8.encode("CBA")))
      _ => ()
    }
    println(
      promise
      |> Result::map(fn(handle) { handle.await_bytes() })
      |> Result::flatten
      |> Result::map(@utf8.decode_lossy),
    )
    runtime.dispose()
  }
  Err(err) => println(err.to_string())
}
```

script の結果を JSON/bytes のまま受け取る場合:

```moonbit
match @v8.runtime_new() {
  Ok(runtime) => {
    println(runtime.eval_json("({ answer: 42, ok: true })"))
    println(
      runtime
      .eval_async_bytes("(async () => new Uint8Array([65, 66, 67]).buffer)()")
      .map(@utf8.decode_lossy),
    )
    runtime.dispose()
  }
  Err(err) => println(err.to_string())
}
```

script origin を明示して relative dynamic import の基準点を変える場合:

```moonbit
match @v8.eval_async_string_with_name(
  "file:///feature/bootstrap.js",
  "(async () => { let mod = await import('./dep.mjs'); return mod.answer })()",
) {
  Ok(value) => println(value)
  Err(err) => println(err.to_string())
}
```

typed bridge のまま relative dynamic import を解決する場合:

```moonbit
match @v8.runtime_new() {
  Ok(runtime) => {
    ignore(runtime.load_module(
      "file:///feature/dep.mjs", "export const answer = 42;",
    ))
    println(
      runtime.eval_async_json_with_name(
        "file:///feature/bootstrap.js",
        "(async () => { let mod = await import('./dep.mjs'); return { answer: mod.answer } })()",
      ),
    )
    runtime.dispose()
  }
  Err(err) => println(err.to_string())
}
```

Module を評価する場合:

```moonbit
match @v8.eval_module_string(
  "globalThis.answer = 6 * 7; export default globalThis.answer",
) {
  Ok(_) => println("module evaluated")
  Err(err) => println(err.to_string())
}
```

module export を host 側から直接読む場合:

```moonbit
match @v8.runtime_new() {
  Ok(runtime) => {
    let module_handle = runtime.eval_module_handle_string(
      "export const answer = 42; export const nested = { ok: true }",
    )
    println(
      module_handle
      |> Result::map(fn(handle) { handle.get_export_json("nested") })
      |> Result::flatten,
    )
    runtime.dispose()
  }
  Err(err) => println(err.to_string())
}
```

module export 名を列挙する場合:

```moonbit
match @v8.runtime_new() {
  Ok(runtime) => {
    let module_handle = runtime.eval_module_handle_string(
      "export const answer = 42; export const nested = { ok: true }",
    )
    println(
      module_handle
      |> Result::map(fn(handle) { handle.export_names() })
      |> Result::flatten,
    )
    runtime.dispose()
  }
  Err(err) => println(err.to_string())
}
```

module export function を host 側から直接呼ぶ場合:

```moonbit
match @v8.runtime_new() {
  Ok(runtime) => {
    let module_handle = runtime.eval_module_handle_string(
      "export const add = async (a, b) => ({ answer: a + b })",
    )
    println(
      module_handle
      |> Result::map(fn(handle) { handle.call_export_json("add", "[20,22]") })
      |> Result::flatten,
    )
    runtime.dispose()
  }
  Err(err) => println(err.to_string())
}
```

top-level await module を host loop で駆動する場合:

```moonbit
match @v8.runtime_new() {
  Ok(runtime) => {
    ignore(runtime.register_async_json_op("load_answer"))
    let module_eval = runtime.eval_module_handle_async_string_with_specifier(
      "file:///feature/main.mjs",
      "const payload = await MoonBit.opAsync('load_answer', { base: 40 }); export const answer = payload.base + 2;",
    )
    match runtime.take_async_json_op() {
      Ok(Some(op)) => ignore(runtime.resolve_async_json_op(op.id, "{\"base\":40}"))
      _ => ()
    }
    println(
      module_eval
      |> Result::map(fn(handle) { handle.await_ready() })
      |> Result::flatten
      |> Result::map(fn(handle) { handle.get_export_json("answer") })
      |> Result::flatten,
    )
    runtime.dispose()
  }
  Err(err) => println(err.to_string())
}
```

entry module specifier を明示して relative import を解決する場合:

```moonbit
match @v8.eval_module_string_with_specifier(
  "file:///feature/main.mjs",
  "import { answer } from './dep.mjs'; globalThis.answer = answer",
) {
  Ok(_) => println("module evaluated")
  Err(err) => println(err.to_string())
}
```

事前登録した module を import する場合:

```moonbit
match @v8.runtime_new() {
  Ok(runtime) => {
    ignore(runtime.load_module("dep", "export const answer = 41;"))
    let result = runtime.eval_module_string(
      "import { answer } from 'dep'; globalThis.answer = answer + 1",
    )
    runtime.dispose()
    println(result.to_string())
  }
  Err(err) => println(err.to_string())
}
```

host から JSON を global に渡して、global 関数を JSON 引数で呼ぶ場合:

```moonbit
match @v8.runtime_new() {
  Ok(runtime) => {
    ignore(runtime.set_global_json("config", "{\"base\":40}"))
    ignore(runtime.eval_string(
      "globalThis.compute = async (delta) => ({ answer: config.base + delta })",
    ))
    let result = runtime.call_global_json("compute", "[2]")
    runtime.dispose()
    println(result.to_string())
  }
  Err(err) => println(err.to_string())
}
```

host から `Uint8Array` を渡して binary を返す場合:

```moonbit
match @v8.runtime_new() {
  Ok(runtime) => {
    ignore(runtime.set_global_bytes("input", @utf8.encode("ABC")))
    ignore(runtime.eval_string(
      "globalThis.reverse_buf = (buf) => new Uint8Array([buf[2], buf[1], buf[0]])",
    ))
    let result = runtime.call_global_bytes("reverse_buf", @utf8.encode("ABC"))
    runtime.dispose()
    println(result |> Result::map(@utf8.decode_lossy))
  }
  Err(err) => println(err.to_string())
}
```

長寿命ランタイムを使う場合:

```moonbit
match @v8.runtime_new() {
  Ok(runtime) => {
    let result = runtime.eval_string("1 + 2")
    runtime.dispose()
    println(result.to_string())
  }
  Err(err) => println(err.to_string())
}
```

snapshot を作って runtime を起動する場合:

```moonbit
match @v8.snapshot_create("globalThis.answer = 41;") {
  Ok(snapshot) => match @v8.runtime_new_with_snapshot(snapshot) {
    Ok(runtime) => {
      let result = runtime.eval_string("globalThis.answer + 1")
      runtime.dispose()
      println(result.to_string())
    }
    Err(err) => println(err.to_string())
  }
  Err(err) => println(err.to_string())
}
```

builder で snapshot 初期化 script と module preload をまとめる場合:

```moonbit
let builder = @v8.runtime_builder_new()
  .eval_snapshot("globalThis.base = 40;")
  .load_module("dep", "export const answer = globalThis.base + 2;")

match builder.with_runtime(fn(runtime) {
  runtime.eval_async_string(
    "(async () => { let mod = await import('dep'); return mod.answer })()",
  )
}) {
  Ok(value) => println(value)
  Err(err) => println(err.to_string())
}
```

runtime image として固めて、複数 isolate 起動に使い回す場合:

```moonbit
let image = match @v8.runtime_builder_new()
  .eval_snapshot("globalThis.base = 40;")
  .load_module("dep", "export const answer = globalThis.base + 2;")
  .build_image() {
  Ok(image) => image
  Err(err) => panic(err.to_string())
}

let first = image.with_runtime(fn(runtime) {
  runtime.eval_string("globalThis.base + 2")
})

let second = image.with_runtime(fn(runtime) {
  runtime.eval_async_string(
    "(async () => { let mod = await import('dep'); return mod.answer })()",
  )
})
```

snapshot builder で初期化 script を段階的に積む場合:

```moonbit
let result = @v8.snapshot_builder_new()
  .eval("globalThis.base = 40;")
  .eval("globalThis.answer = globalThis.base + 2;")
  .with_runtime(fn(runtime) {
    runtime.eval_string("globalThis.answer")
  })
```

snapshot builder を runtime builder に流し込む場合:

```moonbit
let snapshot_builder = @v8.snapshot_builder_new()
  .eval("globalThis.base = 40;")
  .eval("globalThis.bump = 1;")

let builder = @v8.runtime_builder_new()
  .with_snapshot_builder(snapshot_builder)
  .load_module("dep", "export const answer = globalThis.base + globalThis.bump + 1;")
```

## Design

- MoonBit 側は `Runtime` と `V8Error` を公開し、FFI 詳細は `ffi_native.mbt` と `native/bridge/src/lib.rs` に隔離
- `rusty_v8` の複雑なリンクと初期化は Rust staticlib 側で閉じ、MoonBit からは安定した C ABI だけを見る
- Deno 風に、ホストロジックは MoonBit に寄せて、ネイティブ側は「Isolate/Context を作って JS を実行する」最小責務に留める

## Current Status

- `eval_string`, `eval_async_string`, `eval_module_string`, `load_module`, `RuntimeBuilder`, `SnapshotBuilder`, `snapshot_create`, `snapshot_extend`, `runtime_new_with_snapshot` までは利用可能
- まずは native target 前提
- Promise の解決と rejection 取得、明示的な microtask checkpoint、top-level await を含む module 評価までは利用可能
- `eval_promise_string` / `eval_promise_string_with_name` で pending Promise を host 側 handle として保持できます
- `PromiseHandle::result_json` / `result_bytes` で fulfilled Promise の値を JSON/bytes のまま取得できます
- `PromiseHandle::await_string` / `await_json` / `await_bytes` で manual checkpoint なしに Promise を待てます
- `register_sync_json_callback` で `MoonBit.opSync(...)` を MoonBit closure に直接 dispatch できます
- `register_sync_json_op` / `push_sync_json_op_response` / `take_sync_json_op` で `MoonBit.opSync(...)` を固定応答テーブル付きでも扱えます
- `register_sync_bytes_callback` で `MoonBit.opSyncBytes(...)` を MoonBit closure に直接 dispatch できます
- `register_sync_bytes_op` / `push_sync_bytes_op_response` / `take_sync_bytes_op` で `MoonBit.opSyncBytes(...)` を固定応答テーブル付きでも扱えます
- `register_async_json_op` / `take_async_json_op` / `resolve_async_json_op` / `reject_async_json_op` で `MoonBit.opAsync(...)` を host loop で処理できます
- `register_async_bytes_op` / `take_async_bytes_op` / `resolve_async_bytes_op` / `reject_async_bytes_op` で `MoonBit.opAsyncBytes(...)` を host loop で処理できます
- `eval_module_handle_async_string` / `eval_module_handle_async_string_with_specifier` と `ModuleEvalHandle::await_ready` で top-level await module を host loop で非同期に扱えます
- `eval_json` / `eval_bytes` / `eval_async_json` / `eval_async_bytes` で script 結果を文字列化せず typed bridge で取得できます
- `eval_module_handle_string` / `eval_module_handle_string_with_specifier` で評価済み module の export を host 側から取得できます
- `ModuleHandle` 経由で export 一覧取得と export function の JSON/bytes 呼び出しもできます
- 事前登録した module に対して、static import / dynamic import の解決と相対 specifier の解決までは利用可能
- named script origin と named entry module specifier を渡して relative import の基準点を制御できます
- `set_global_json` / `get_global_json` / `call_global_json` で host と JS の JSON ベース値受け渡しができます
- `set_global_bytes` / `get_global_bytes` / `call_global_bytes` で `Uint8Array` / `ArrayBuffer` ベースの binary 受け渡しができます
- 初期化 script から snapshot を作り、既存 snapshot に追記して runtime を起動できます
- `RuntimeBuilder::eval_snapshot` と `RuntimeBuilder::with_snapshot_builder` で snapshot 初期化と module preload を 1 つの builder にまとめられます
- `RuntimeImage` で snapshot と module preload を再利用可能な起動イメージとして保持できます
- sync host op は preloaded JSON / bytes response table ベースで利用可能
- async host op は JSON / bytes queue ベースで利用可能
- sync host callback は JSON / bytes で利用可能
- async host callback と richer host op surface は未実装
- いまは `rusty_v8::OwnedIsolate` の制約に合わせて、同時に 1 runtime のみを許可
- 次は host callback surface を積む想定

## References

- `rusty_v8` README: https://github.com/denoland/rusty_v8
- `rusty_v8/examples/hello_world.rs`: https://github.com/denoland/rusty_v8/blob/main/examples/hello_world.rs
- V8 sample `hello-world.cc`: https://github.com/v8/v8/blob/main/samples/hello-world.cc

## License

Apache-2.0
