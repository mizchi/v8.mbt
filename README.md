# mizchi/v8

[English](README.md) | [日本語](README.ja.md)

`mizchi/v8` is a native-only V8 binding for MoonBit. It is intended as a foundation for prototyping MoonBit-first embedded runtimes in the style of Node or Deno.

> Experimental release note: on Moon `0.1.20260309` / MoonBit `v0.8.3`, this package still requires consumer-side prebuild and link setup.

## What You Can Do

- evaluate scripts and modules from MoonBit
- exchange JS values as `String`, JSON, or `Bytes`
- keep pending promises and top-level await modules as host-side handles
- work with preloaded modules, relative imports, and dynamic imports
- build snapshots and runtime images for reusable isolate startup
- experiment with host-side event loops through `MoonBit.opSync(...)` and `MoonBit.opAsync(...)`

## Status

- version: `0.1.0`
- target: `native`
- usable as an embedder-facing experimental binding
- implementation status and known gaps are tracked in [docs/development-log.md](docs/development-log.md)

## Install From mooncakes

```bash
moon add mizchi/v8
mkdir -p scripts
cp .mooncakes/mizchi/v8/docs/examples/mizchi-v8-consumer-prebuild.mjs scripts/
moon check --target native
```

With Moon `0.1.20260309` / MoonBit `v0.8.3`, dependency-side native hooks are not applied to consumers automatically. In practice, consumers need one small prebuild script in their own module.

Add this to your `moon.mod.json`:

```json
{
  "--moonbit-unstable-prebuild": "scripts/mizchi-v8-consumer-prebuild.mjs"
}
```

And add this to the package that produces your final native binary:

```moonbit
options(
  "is-main": true,
  link: {
    "native": {
      "cc-link-flags": "${build.MIZCHI_V8_CC_LINK_FLAGS}",
    },
  },
)
```

### Prerequisites

- `git`
- `bash`
- Rust toolchain with `cargo`
- a native C/C++ toolchain
- `node` for the consumer-side prebuild script
- network access to GitHub, crates.io, and the `rusty_v8` release mirror

The published package also uses a `postadd` hook to eagerly build the native bridge in the installed module cache, but the consumer-side link setup is still required today.

### Develop From Source

```bash
git clone https://github.com/mizchi/v8.mbt
cd v8.mbt
just bootstrap
just test
```

`just bootstrap` builds `deps/rusty_v8` and the Rust bridge in the current checkout. End users installing from mooncakes do not need to run it manually.

## Minimal Example

For one-shot evaluation, the top-level helpers are enough.

```moonbit
match @v8.eval_string("'Hello' + ', MoonBit!'") {
  Ok(value) => println(value)
  Err(err) => println(err.to_string())
}
```

For a longer-lived runtime, `RuntimeBuilder` can combine snapshot initialization and module preload.

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

For host-driven event loop experiments, async ops can be handled as a queue.

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

## Main APIs

- evaluation: `Runtime`, `eval_*`, `eval_module_*`, `perform_microtask_checkpoint`
- async handles: `PromiseHandle`, `ModuleEvalHandle`, `ModuleHandle`
- bootstrap: `Runtime::load_module`, `RuntimeBuilder`, `SnapshotBuilder`, `RuntimeImage`
- value bridge: `set/get/call_global_json`, `set/get/call_global_bytes`, `eval_json`, `eval_bytes`
- host bridge: `register_sync_*_callback`, `register_*_op`, `take_*_op`, `resolve_*_op`, `reject_*_op`

For the complete public surface and more examples, see [src/README.mbt.md](src/README.mbt.md).

## Limitations

- native target only
- only one runtime can exist at a time
- async host callback surface is not implemented yet
- this project targets low-level embedder bindings, not Node / Deno compatibility APIs
- consumers still need a small module-level prebuild setup today
- local path dependencies do not get the same install-time hook behavior as `moon add`

## Documentation

- package API and executable examples: [src/README.mbt.md](src/README.mbt.md)
- implementation status and constraints: [docs/development-log.md](docs/development-log.md)
- Japanese README: [README.ja.md](README.ja.md)
- release history: [CHANGELOG.md](CHANGELOG.md)

## License

Apache-2.0
