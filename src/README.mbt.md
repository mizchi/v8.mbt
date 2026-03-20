# mizchi/v8

MoonBit から V8 を扱うためのネイティブバインディングです。

## Package

- `mizchi/v8`

## Public Surface

- `version() -> String`
- `runtime_new() -> Result[Runtime, V8Error]`
- `Runtime::eval_string(String) -> Result[String, V8Error]`
- `Runtime::dispose() -> Unit`
- `eval_string(String) -> Result[String, V8Error]`

## Notes

- `rusty_v8` を依存取得に使い、Rust staticlib ブリッジ経由で MoonBit から呼びます
- いまは `Context` 1 個を保持する最小ランタイムです
- いまは同時に 1 runtime のみを許可します
- 将来的に module loader や host op 層を MoonBit 側へ積む想定です
