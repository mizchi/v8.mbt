# mizchi/oden

`mizchi/oden` は、`mizchi/v8` の上に載せる `oden` CLI/runtime 実験用 module です。

- `moon.mod.json` を root の `mizchi/v8` とは分離
- local path dependency で `..` の `mizchi/v8` を参照
- `Oden` CLI layer はこの module 側で管理
- 将来 `oden/` ディレクトリごと別 repo に切り出しやすい構成

## 使い方

```bash
cd oden
just run
```

`just run` は `oden manifest` 相当として `Oden.cli` の command descriptor と build metadata を JSON で出力します。

CLI router は次を提供します。

- `run` / `check` / `test`: JS-first 既定で `moon` command に変換
- `bundle`: wasm-first 既定で `moon build` に変換し、`--target-dir` 未指定なら `.oden/build/<target>` を使う
- `fmt`: `moon fmt` へそのまま転送
- `info`: JS-first 既定で `moon info` に変換
- `task`: `just` へ変換し、引数なしなら `just --summary`
- `plan`: 実行せずに変換結果を JSON で表示。`name` / `kind` / `program` / `cwd` / `argv` / `target` を含む
- `help` / `-h` / `--help`
- `version` / `-V` / `--version`
- `manifest`

```bash
cd oden
moon run src/main --target native -- help
moon run src/main --target native -- --version
moon run src/main --target native -- manifest
moon run src/main --target native -- check --target native
moon run src/main --target native -- info --target native
moon run src/main --target native -- task
moon run src/main --target native -- plan bundle app/main
moon run src/main --target native -- run src/main --target native -- manifest
```

最後の 5 行は self-host smoke 用です。`oden` 自体は `mizchi/v8` の上に載る native module なので、この repo の中で `run/check/test/bundle/info/task/plan` を試すときは明示的に `--target native` override を渡っています。将来的に別 repo へ切り出した後は、JS/WASM first な project を対象に同じ router をそのまま使う想定です。
