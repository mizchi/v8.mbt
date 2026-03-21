///|
fn oden_version() -> String {
  "0.0.0-mizchi-v8"
}

///|
fn moonbit_version() -> String {
  "unknown"
}

///|
fn oden_cli_compat_source() -> String {
  "(function(){ " +
  "const root = globalThis; " +
  "const tryDeno = function(){ const deno = root.Deno; return typeof deno === 'object' && deno !== null ? deno : null; }; " +
  "const requireDeno = function(){ const deno = tryDeno(); if (deno !== null) return deno; throw new Error('Oden CLI compat requires Deno core compat'); }; " +
  "const oden = root.Oden ?? (root.Oden = {}); " +
  "if (!Array.isArray(oden.args)) oden.args = []; " +
  "if (typeof oden.build !== 'object' || oden.build === null) oden.build = { arch: 'unknown', os: 'unknown', vendor: 'unknown', target: 'unknown', language: 'moonbit', firstClassTargets: ['js', 'wasm'] }; " +
  "if (typeof oden.build.language !== 'string') oden.build.language = 'moonbit'; " +
  "if (!Array.isArray(oden.build.firstClassTargets)) oden.build.firstClassTargets = ['js', 'wasm']; " +
  "if (typeof oden.version !== 'object' || oden.version === null) oden.version = { oden: '" +
  oden_version() +
  "', v8: '" +
  @v8.version() +
  "', moonbit: '" +
  moonbit_version() +
  "' }; " +
  "if (typeof oden.version.oden !== 'string') oden.version.oden = '" +
  oden_version() +
  "'; " +
  "if (typeof oden.version.v8 !== 'string') oden.version.v8 = '" +
  @v8.version() +
  "'; " +
  "if (typeof oden.version.moonbit !== 'string') oden.version.moonbit = '" +
  moonbit_version() +
  "'; " +
  "if (typeof oden.pid !== 'number') oden.pid = 0; " +
  "if (typeof oden.ppid !== 'number') oden.ppid = 0; " +
  "if (typeof oden.noColor !== 'boolean') oden.noColor = false; " +
  "if (typeof oden.exitCode !== 'number') oden.exitCode = 0; " +
  "if (typeof oden.cli !== 'object' || oden.cli === null) oden.cli = {}; " +
  "const cli = oden.cli; " +
  "const cliCommands = typeof cli.commands === 'object' && cli.commands !== null ? cli.commands : (cli.commands = { run: { name: 'run', primaryLanguage: 'moonbit', defaultTarget: 'js', firstClassTargets: ['js', 'wasm'], description: 'build MoonBit JS and execute the entry module' }, check: { name: 'check', primaryLanguage: 'moonbit', defaultTarget: 'js', firstClassTargets: ['js', 'wasm'], description: 'type-check MoonBit sources for JS/WASM-first targets' }, test: { name: 'test', primaryLanguage: 'moonbit', defaultTarget: 'js', firstClassTargets: ['js', 'wasm'], description: 'run MoonBit tests with JS/WASM-first outputs' }, bundle: { name: 'bundle', primaryLanguage: 'moonbit', defaultTarget: 'wasm', firstClassTargets: ['js', 'wasm'], description: 'bundle MoonBit JS/WASM artifacts for distribution' }, fmt: { name: 'fmt', primaryLanguage: 'moonbit', defaultTarget: null, firstClassTargets: ['js', 'wasm'], description: 'format MoonBit sources' }, info: { name: 'info', primaryLanguage: 'moonbit', defaultTarget: 'js', firstClassTargets: ['js', 'wasm'], description: 'emit MoonBit public API information for JS/WASM-first targets' } }); " +
  "if (typeof cli.command !== 'function') cli.command = function(name){ const key = String(name ?? ''); return Object.prototype.hasOwnProperty.call(cliCommands, key) ? cliCommands[key] : null; }; " +
  "if (typeof cli.commandNames !== 'function') cli.commandNames = function(){ return Object.keys(cliCommands); }; " +
  "if (!Object.prototype.hasOwnProperty.call(oden, 'core')) Object.defineProperty(oden, 'core', { configurable: true, enumerable: true, get: function(){ return requireDeno().core; } }); " +
  "if (typeof oden.cwd !== 'function') oden.cwd = function(){ const deno = tryDeno(); return deno && typeof deno.cwd === 'function' ? deno.cwd() : '/'; }; " +
  "if (typeof oden.execPath !== 'function') oden.execPath = function(){ return '/mizchi-oden/bin/oden'; }; " +
  "if (typeof oden.inspect !== 'function') oden.inspect = function(value, options){ const deno = tryDeno(); if (deno && typeof deno.inspect === 'function') return deno.inspect(value, options); try { const inspected = JSON.stringify(value); return inspected === undefined ? String(value) : inspected; } catch (_) { return String(value); } }; " +
  "if (typeof oden.sleep !== 'function') oden.sleep = function(delay){ return requireDeno().sleep(delay); }; " +
  "})();"
}

///|
pub struct OdenCliPlan {
  name : String
  moon_subcommand : String
  argv : Array[String]
  target : String
}

///|
pub enum OdenCliRoute {
  Help
  Version
  Manifest
  Exec(OdenCliPlan)
}

///|
pub fn help_text() -> String {
  let text =
    #|Usage: oden <command> [options] [path]
    #|
    #|Commands:
    #|  run [path] [moon args...]      run MoonBit code with JS-first defaults
    #|  check [path] [moon args...]    check MoonBit code with JS-first defaults
    #|  test [path] [moon args...]     test MoonBit code with JS-first defaults
    #|  bundle [path] [moon args...]   build MoonBit code with wasm-gc-first defaults
    #|  fmt [moon args...]             format MoonBit sources
    #|  info [moon args...]            emit MoonBit public API info with JS-first defaults
    #|  version                        print Oden/V8/MoonBit version info
    #|  manifest                       print the Oden CLI manifest JSON
    #|  help                           show this help message
    #|
    #|Aliases:
    #|  -h, --help                     show this help message
    #|  -V, --version                  print version info
  text
}

///|
pub fn version_text() -> String {
  "oden " +
  oden_version() +
  "\n" +
  "v8 " +
  @v8.version() +
  "\n" +
  "moonbit " +
  moonbit_version()
}

///|
fn starts_with_option(arg : String) -> Bool {
  arg.has_prefix("-")
}

///|
fn find_target_value(args : Array[String]) -> String? {
  for i in 0..<args.length() {
    if args[i] == "--target" && i + 1 < args.length() {
      return Some(args[i + 1])
    }
  }
  None
}

///|
fn build_plan_args(
  moon_subcommand : String,
  path : String?,
  default_path : String?,
  default_target : String?,
  extra_args : Array[String],
) -> Array[String] {
  let argv = Array::default()
  argv.push(moon_subcommand)
  match path {
    Some(path) => argv.push(path)
    None =>
      match default_path {
        Some(path) => argv.push(path)
        None => ()
      }
  }
  if find_target_value(extra_args) is None {
    match default_target {
      Some(default_target) => {
        argv.push("--target")
        argv.push(default_target)
      }
      None => ()
    }
  }
  for i in 0..<extra_args.length() {
    argv.push(extra_args[i])
  }
  argv
}

///|
fn route_exec_command(
  name : String,
  moon_subcommand : String,
  default_target : String?,
  default_path : String?,
  args : Array[String],
) -> OdenCliRoute {
  let (path, extra_args) = match args {
    [first, .. rest] if !starts_with_option(first) =>
      (Some(first), rest.to_array())
    _ => (None, args)
  }
  OdenCliRoute::Exec(OdenCliPlan::{
    name,
    moon_subcommand,
    argv: build_plan_args(
      moon_subcommand, path, default_path, default_target, extra_args,
    ),
    target: match find_target_value(extra_args) {
      Some(target) => target
      None =>
        match default_target {
          Some(target) => target
          None => "none"
        }
    },
  })
}

///|
pub fn route_cli(args : Array[String]) -> Result[OdenCliRoute, String] {
  match args {
    [] => Ok(OdenCliRoute::Help)
    ["-h", ..] => Ok(OdenCliRoute::Help)
    ["--help", ..] => Ok(OdenCliRoute::Help)
    ["help", ..] => Ok(OdenCliRoute::Help)
    ["-V", ..] => Ok(OdenCliRoute::Version)
    ["--version", ..] => Ok(OdenCliRoute::Version)
    ["version", ..] => Ok(OdenCliRoute::Version)
    ["manifest", ..] => Ok(OdenCliRoute::Manifest)
    ["run", .. rest] =>
      Ok(
        route_exec_command(
          "run",
          "run",
          Some("js"),
          Some("src/main"),
          rest.to_array(),
        ),
      )
    ["check", .. rest] =>
      Ok(
        route_exec_command("check", "check", Some("js"), None, rest.to_array()),
      )
    ["test", .. rest] =>
      Ok(route_exec_command("test", "test", Some("js"), None, rest.to_array()))
    ["bundle", .. rest] =>
      Ok(
        route_exec_command(
          "bundle",
          "build",
          Some("wasm-gc"),
          Some("src/main"),
          rest.to_array(),
        ),
      )
    ["fmt", .. rest] =>
      Ok(route_exec_command("fmt", "fmt", None, None, rest.to_array()))
    ["info", .. rest] =>
      Ok(route_exec_command("info", "info", Some("js"), None, rest.to_array()))
    [command, ..] => Err("unknown oden subcommand: \{command}")
  }
}

///|
pub fn builder_new() -> @v8.RuntimeBuilder {
  @v8.runtime_builder_new()
  .with_deno_core_compat()
  .eval_snapshot(oden_cli_compat_source())
}

///|
pub fn snapshot_builder_new() -> @v8.SnapshotBuilder {
  @v8.snapshot_builder_new()
  .with_deno_core_compat()
  .eval(oden_cli_compat_source())
}

///|
pub fn install(runtime : @v8.Runtime) -> Result[Unit, @v8.V8Error] {
  let deno_installed = runtime.install_deno_core_compat()
  guard deno_installed is Ok(_) else { return Err(deno_installed.unwrap_err()) }
  let installed = runtime.eval_string_with_name(
    "file:///compat/oden.js",
    oden_cli_compat_source(),
  )
  guard installed is Ok(_) else { return Err(installed.unwrap_err()) }
  Ok(())
}

///|
pub fn[T] with_runtime(
  f : (@v8.Runtime) -> Result[T, @v8.V8Error],
) -> Result[T, @v8.V8Error] {
  builder_new().with_runtime(f)
}

///|
pub fn cli_manifest_json() -> Result[String, @v8.V8Error] {
  with_runtime(fn(runtime) {
    runtime.eval_json(
      "({ names: Oden.cli.commandNames(), commands: Oden.cli.commandNames().map((name) => Oden.cli.command(name)), build: Oden.build, version: Oden.version, execPath: Oden.execPath() })",
    )
  })
}
