# mizchi/v8

MoonBit から V8 を叩くためのネイティブバインディングです。Node や Deno のような埋め込みランタイムを、できるだけ MoonBit 側に寄せて試作するための土台として作っています。

初期スコープは最小です。

- `Runtime::new`
- `Runtime::eval_string`
- `Runtime::eval_async_string`
- `Runtime::eval_module_string`
- `Runtime::perform_microtask_checkpoint`
- V8 例外を `Result[String, V8Error]` に変換
- `rusty_v8` を依存取得に使い、MoonBit とは薄い C ABI で接続

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

Module を評価する場合:

```moonbit
match @v8.eval_module_string(
  "globalThis.answer = 6 * 7; export default globalThis.answer",
) {
  Ok(_) => println("module evaluated")
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

## Design

- MoonBit 側は `Runtime` と `V8Error` を公開し、FFI 詳細は `ffi_native.mbt` と `native/bridge/src/lib.rs` に隔離
- `rusty_v8` の複雑なリンクと初期化は Rust staticlib 側で閉じ、MoonBit からは安定した C ABI だけを見る
- Deno 風に、ホストロジックは MoonBit に寄せて、ネイティブ側は「Isolate/Context を作って JS を実行する」最小責務に留める

## Current Status

- `eval_string`, `eval_async_string`, `eval_module_string` までは利用可能
- まずは native target 前提
- Promise の解決と rejection 取得、明示的な microtask checkpoint、top-level await を含む module 評価までは利用可能
- import resolver はまだ未実装で、`import ...` を含む module は明示エラーになる
- いまは `rusty_v8::OwnedIsolate` の制約に合わせて、同時に 1 runtime のみを許可
- これから `ops`, `module loader`, `promise/microtask`, `host callbacks` を積む想定

## References

- `rusty_v8` README: https://github.com/denoland/rusty_v8
- `rusty_v8/examples/hello_world.rs`: https://github.com/denoland/rusty_v8/blob/main/examples/hello_world.rs
- V8 sample `hello-world.cc`: https://github.com/v8/v8/blob/main/samples/hello-world.cc

## License

Apache-2.0
