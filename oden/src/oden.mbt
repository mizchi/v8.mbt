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
  "const cliCommands = typeof cli.commands === 'object' && cli.commands !== null ? cli.commands : (cli.commands = { run: { name: 'run', primaryLanguage: 'moonbit', execution: 'embedded-v8', defaultTarget: 'js', defaultOutDir: '.oden/run', firstClassTargets: ['js', 'wasm'], description: 'build MoonBit JS and execute the entry module on the embedded V8 runtime' }, check: { name: 'check', primaryLanguage: 'moonbit', defaultTarget: 'js', firstClassTargets: ['js', 'wasm'], description: 'type-check MoonBit sources for JS/WASM-first targets' }, test: { name: 'test', primaryLanguage: 'moonbit', defaultTarget: 'js', firstClassTargets: ['js', 'wasm'], description: 'run MoonBit tests with JS/WASM-first outputs' }, bundle: { name: 'bundle', primaryLanguage: 'moonbit', defaultTarget: 'wasm', defaultOutDir: '.oden/build/wasm-gc', firstClassTargets: ['js', 'wasm'], description: 'bundle MoonBit JS/WASM artifacts for distribution' }, fmt: { name: 'fmt', primaryLanguage: 'moonbit', defaultTarget: null, firstClassTargets: ['js', 'wasm'], description: 'format MoonBit sources' }, info: { name: 'info', primaryLanguage: 'moonbit', defaultTarget: 'js', firstClassTargets: ['js', 'wasm'], description: 'emit MoonBit public API information for JS/WASM-first targets' }, task: { name: 'task', primaryLanguage: 'moonbit', defaultTarget: null, firstClassTargets: ['js', 'wasm'], description: 'run project automation tasks through just' }, plan: { name: 'plan', primaryLanguage: 'moonbit', defaultTarget: null, firstClassTargets: ['js', 'wasm'], description: 'print the translated execution plan without running it' } }); " +
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
  kind : String
  program : String
  argv : Array[String]
  cwd : String
  out_dir : String?
  target : String
}

///|
pub enum OdenCliRoute {
  Help
  Version
  Manifest
  Plan(OdenCliPlan)
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
    #|  task [name] [task args...]     run project tasks through just
    #|  plan <command ...>             print the translated execution plan as JSON
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
pub fn plan_json(plan : OdenCliPlan) -> String {
  let values : Map[String, Json] = Map::new()
  values.set("name", Json::string(plan.name))
  values.set("kind", Json::string(plan.kind))
  values.set("program", Json::string(plan.program))
  values.set("execution", Json::string("subprocess"))
  let argv : Array[Json] = []
  plan.argv.each(arg => argv.push(Json::string(arg)))
  values.set("argv", Json::array(argv))
  values.set("cwd", Json::string(plan.cwd))
  values.set(
    "outDir",
    match plan.out_dir {
      Some(out_dir) => Json::string(out_dir)
      None => Json::null()
    },
  )
  values.set("target", Json::string(plan.target))
  match embedded_v8_run_plan(plan) {
    Some((build_argv, guest_argv, out_dir)) => {
      values.set("execution", Json::string("embedded-v8"))
      values.set("buildProgram", Json::string("moon"))
      values.set("buildArgv", json_string_array(build_argv))
      values.set("guestArgv", json_string_array(guest_argv))
      values.set("outDir", Json::string(out_dir))
    }
    None => ()
  }
  Json::object(values).stringify()
}

///|
fn starts_with_option(arg : String) -> Bool {
  arg.has_prefix("-")
}

///|
fn find_flag_value(args : Array[String], flag : String) -> String? {
  for i in 0..<args.length() {
    if args[i] == flag && i + 1 < args.length() {
      return Some(args[i + 1])
    }
  }
  None
}

///|
fn json_string_array(values : Array[String]) -> Json {
  Json::array(values.map(value => Json::string(value)))
}

///|
fn run_target_dir() -> String {
  ".oden/run"
}

///|
fn split_embedded_run_args(
  args : Array[String],
) -> (Array[String], Array[String]) {
  let moon_args : Array[String] = []
  let guest_args : Array[String] = []
  let mut after_delimiter = false
  for i in 0..<args.length() {
    let arg = args[i]
    if !after_delimiter && arg == "--" {
      after_delimiter = true
      continue
    }
    if after_delimiter {
      guest_args.push(arg)
    } else {
      moon_args.push(arg)
    }
  }
  (moon_args, guest_args)
}

///|
fn embedded_v8_run_plan(
  plan : OdenCliPlan,
) -> (Array[String], Array[String], String)? {
  if plan.kind != "run" || plan.target != "js" {
    return None
  }
  let package_path = if plan.argv.length() > 1 &&
    plan.argv[1] != "--" &&
    !starts_with_option(plan.argv[1]) {
    plan.argv[1]
  } else {
    "src/main"
  }
  let trailing = if plan.argv.length() > 2 {
    plan.argv[2:].to_array()
  } else {
    []
  }
  let (moon_args, guest_args) = split_embedded_run_args(trailing)
  let build_argv : Array[String] = ["build", package_path]
  moon_args.each(arg => build_argv.push(arg))
  let out_dir = plan.out_dir.unwrap_or(run_target_dir())
  if find_flag_value(moon_args, "--target-dir") is None {
    build_argv.push("--target-dir")
    build_argv.push(out_dir)
  }
  Some((build_argv, guest_args, out_dir))
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
  if find_flag_value(extra_args, "--target") is None {
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
fn route_exec_moon_command(
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
    kind: name,
    program: "moon",
    argv: build_plan_args(
      moon_subcommand, path, default_path, default_target, extra_args,
    ),
    cwd: ".",
    out_dir: None,
    target: match find_flag_value(extra_args, "--target") {
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
fn route_run_command(args : Array[String]) -> OdenCliRoute {
  let (path, extra_args) = match args {
    [first, .. rest] if !starts_with_option(first) =>
      (Some(first), rest.to_array())
    _ => (None, args)
  }
  let target = find_flag_value(extra_args, "--target").unwrap_or("js")
  let out_dir = if target == "js" {
    Some(
      find_flag_value(extra_args, "--target-dir").unwrap_or(run_target_dir()),
    )
  } else {
    find_flag_value(extra_args, "--target-dir")
  }
  OdenCliRoute::Exec(OdenCliPlan::{
    name: "run",
    kind: "run",
    program: "moon",
    argv: build_plan_args("run", path, Some("src/main"), Some("js"), extra_args),
    cwd: ".",
    out_dir,
    target,
  })
}

///|
fn bundle_target_dir(target : String) -> String {
  ".oden/build/" + target
}

///|
fn route_bundle_command(args : Array[String]) -> OdenCliRoute {
  let (path, extra_args) = match args {
    [first, .. rest] if !starts_with_option(first) =>
      (Some(first), rest.to_array())
    _ => (None, args)
  }
  let target = find_flag_value(extra_args, "--target").unwrap_or("wasm-gc")
  let out_dir = find_flag_value(extra_args, "--target-dir").unwrap_or(
    bundle_target_dir(target),
  )
  let argv = build_plan_args(
    "build",
    path,
    Some("src/main"),
    Some(target),
    extra_args,
  )
  if find_flag_value(extra_args, "--target-dir") is None {
    argv.push("--target-dir")
    argv.push(out_dir)
  }
  OdenCliRoute::Exec(OdenCliPlan::{
    name: "bundle",
    kind: "bundle",
    program: "moon",
    argv,
    cwd: ".",
    out_dir: Some(out_dir),
    target,
  })
}

///|
fn route_task_command(args : Array[String]) -> OdenCliRoute {
  let argv = match args {
    [] => ["--summary"]
    _ => args
  }
  OdenCliRoute::Exec(OdenCliPlan::{
    name: "task",
    kind: "task",
    program: "just",
    argv,
    cwd: ".",
    out_dir: None,
    target: "none",
  })
}

///|
fn route_plan_command(args : Array[String]) -> Result[OdenCliRoute, String] {
  match args {
    [] => Err("plan requires a subcommand")
    _ =>
      match route_cli(args) {
        Ok(OdenCliRoute::Exec(plan)) => Ok(OdenCliRoute::Plan(plan))
        Ok(_) => Err("plan expects an executable subcommand")
        Err(err) => Err(err)
      }
  }
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
    ["run", .. rest] => Ok(route_run_command(rest.to_array()))
    ["check", .. rest] =>
      Ok(
        route_exec_moon_command(
          "check",
          "check",
          Some("js"),
          None,
          rest.to_array(),
        ),
      )
    ["test", .. rest] =>
      Ok(
        route_exec_moon_command(
          "test",
          "test",
          Some("js"),
          None,
          rest.to_array(),
        ),
      )
    ["bundle", .. rest] => Ok(route_bundle_command(rest.to_array()))
    ["fmt", .. rest] =>
      Ok(route_exec_moon_command("fmt", "fmt", None, None, rest.to_array()))
    ["info", .. rest] =>
      Ok(
        route_exec_moon_command(
          "info",
          "info",
          Some("js"),
          None,
          rest.to_array(),
        ),
      )
    ["task", .. rest] => Ok(route_task_command(rest.to_array()))
    ["plan", .. rest] => route_plan_command(rest.to_array())
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
