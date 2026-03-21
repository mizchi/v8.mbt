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

- `run`: JS-first 既定では `moon build` した JS artifact を `mizchi/v8` runtime で実行し、build 出力先の既定は `.oden/run`。`--target wasm` / `wasm-gc` / `native` など JS 以外では `moon run` subprocess に委譲
- `check` / `test`: JS-first 既定で `moon` command に変換
- `bundle`: wasm-first 既定で `moon build` に変換し、`--target-dir` 未指定なら `.oden/build/<target>` を使う
- `fmt`: `moon fmt` へそのまま転送
- `info`: JS-first 既定で `moon info` に変換
- `task`: `just` へ変換し、引数なしなら `just --summary`
- `plan`: 実行せずに変換結果を JSON で表示。`run(js)` の場合は `execution: "embedded-v8"` に加えて `buildArgv` / `guestArgv` / `outDir` も含み、`run(--target wasm*)` では `execution: "subprocess"` のまま `moon run` plan を返す
- `help` / `-h` / `--help`
- `version` / `-V` / `--version`
- `manifest`

`mizchi/oden` package には runtime helper もあります。

- `builder_new()` / `snapshot_builder_new()`: `Deno.core` + `Oden` CLI globals を preload した builder
- `run_builder_new()` / `run_snapshot_builder_new()` / `run_image_new()`: `console` / `process.exit` / `Oden.__prepareRun` まで snapshot に固めた run 用 builder/image
- `prepare_run_runtime(runtime, args)`: run image から作った isolate に guest args と exit code 初期値を流し込む
- `just bench`: `bench/fixtures/run_sync` を使って `oden run` の hot/cold snapshot benchmark を取り、結果 JSON は `.oden/bench` に出力

```bash
cd oden
moon run src/cmd/oden --target native -- help
moon run src/cmd/oden --target native -- --version
moon run src/cmd/oden --target native -- manifest
moon run src/cmd/oden --target native -- check --target native
moon run src/cmd/oden --target native -- info --target native
moon run src/cmd/oden --target native -- task
moon run src/cmd/oden --target native -- plan bundle app/main
```

`run(js)` は subprocess ではなく、上の run image から V8 isolate を起こして guest code を評価します。なので guest の `stdout` / `stderr` / `process.exitCode` を `oden` 側に反映できます。さらに serialized run snapshot は guest project の `.oden/run/oden-run.snapshot.bin` にキャッシュされ、同じ project での warm run では再利用されます。repo 内で self-host smoke をするときは `moon run` より build 済み binary を project dir から直接叩く方が実利用に近いです。

```bash
moon -C oden build src/cmd/oden --target native
cd /path/to/moonbit-project
/abs/path/to/v8.mbt/oden/_build/native/debug/build/cmd/oden/oden.exe run
```

`oden` 自体は `mizchi/v8` の上に載る native module なので、この repo の中で `check/test/bundle/info/task/plan` を試すときは明示的に `--target native` override を渡っています。将来的に別 repo へ切り出した後は、JS/WASM first な project を対象に同じ router をそのまま使う想定です。
