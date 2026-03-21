///|
struct OdenRunInvocation {
  package_path : String
  moon_args : Array[String]
  guest_args : Array[String]
  target_dir : String
  cwd : String
  is_release : Bool
}

///|
struct OdenJsRunResult {
  exit_code : Int
  stdout_lines : Array[String]
  stderr_lines : Array[String]
}

///|
fn default_run_target_dir() -> String {
  ".oden/run"
}

///|
fn starts_with_dash(arg : String) -> Bool {
  arg.has_prefix("-")
}

///|
fn find_arg_flag_value(args : Array[String], flag : String) -> String? {
  for i in 0..<args.length() {
    if args[i] == flag && i + 1 < args.length() {
      return Some(args[i + 1])
    }
  }
  None
}

///|
fn split_run_args(args : Array[String]) -> (Array[String], Array[String]) {
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
fn parse_run_invocation(
  plan : @oden.OdenCliPlan,
  cwd : String,
) -> Result[OdenRunInvocation, String] {
  if plan.kind != "run" {
    return Err("expected run plan")
  }
  if plan.argv.is_empty() || plan.argv[0] != "run" {
    return Err("expected moon run argv")
  }
  let package_path = if plan.argv.length() > 1 &&
    plan.argv[1] != "--" &&
    !starts_with_dash(plan.argv[1]) {
    plan.argv[1]
  } else {
    "src/main"
  }
  let trailing = if plan.argv.length() > 2 {
    plan.argv[2:].to_array()
  } else {
    []
  }
  let (moon_args, guest_args) = split_run_args(trailing)
  let target_dir = find_arg_flag_value(moon_args, "--target-dir").unwrap_or(
    default_run_target_dir(),
  )
  Ok(OdenRunInvocation::{
    package_path,
    moon_args,
    guest_args,
    target_dir,
    cwd,
    is_release: moon_args.contains("--release"),
  })
}

///|
fn join_path(left : String, right : String) -> String {
  if left.is_empty() || left == "." {
    right
  } else if right.is_empty() {
    left
  } else if right.has_prefix("/") {
    right
  } else if left.has_suffix("/") {
    left + right
  } else {
    left + "/" + right
  }
}

///|
fn resolve_path(cwd : String, path : String) -> String {
  if path.has_prefix("/") {
    path
  } else {
    join_path(cwd, path)
  }
}

///|
fn last_path_segment(path : String) -> String {
  match path.rev_find("/") {
    Some(index) => path[index + 1:].to_string()
    None => path
  }
}

///|
fn normalize_package_path(source_dir : String, package_path : String) -> String {
  if package_path == source_dir {
    ""
  } else {
    match package_path.strip_prefix(source_dir + "/") {
      Some(rest) => rest.to_string()
      None => package_path
    }
  }
}

///|
fn module_stem(module_name : String) -> String {
  last_path_segment(module_name)
}

///|
fn resolve_js_artifact_path(
  module_name : String,
  source_dir : String,
  package_path : String,
  target_dir : String,
  is_release : Bool,
) -> String {
  let profile_dir = if is_release { "release" } else { "debug" }
  let build_root = join_path(
    join_path(join_path(target_dir, "js"), profile_dir),
    "build",
  )
  let normalized = normalize_package_path(source_dir, package_path)
  if normalized.is_empty() {
    join_path(build_root, module_stem(module_name) + ".js")
  } else {
    join_path(
      join_path(build_root, normalized),
      last_path_segment(normalized) + ".js",
    )
  }
}

///|
fn build_run_compile_argv(invocation : OdenRunInvocation) -> Array[String] {
  let argv : Array[String] = ["build", invocation.package_path]
  invocation.moon_args.each(arg => argv.push(arg))
  if find_arg_flag_value(invocation.moon_args, "--target-dir") is None {
    argv.push("--target-dir")
    argv.push(invocation.target_dir)
  }
  argv
}

///|
async fn read_module_config(cwd : String) -> Result[(String, String), String] {
  let moon_mod_path = resolve_path(cwd, "moon.mod.json")
  let moon_mod_text = @fs.read_file(moon_mod_path).text() catch {
    err =>
      return Err("failed to read " + moon_mod_path + ": " + err.to_string())
  }
  let moon_mod = @json.parse(moon_mod_text) catch {
    err =>
      return Err("failed to parse " + moon_mod_path + ": " + err.to_string())
  }
  guard moon_mod is Object(fields) else {
    return Err("moon.mod.json must be a JSON object")
  }
  let module_name = match fields.get("name") {
    Some(String(name)) => name
    _ => return Err("moon.mod.json must contain string name")
  }
  let source_dir = match fields.get("source") {
    Some(String(source_dir)) => source_dir
    _ => "src"
  }
  Ok((module_name, source_dir))
}

///|
fn guest_args_json(guest_args : Array[String]) -> String {
  Json::array(guest_args.map(arg => Json::string(arg))).stringify()
}

///|
fn console_payload_text(payload : String) -> String {
  let parsed = @json.parse(payload) catch { _ => Json::string(payload) }
  match parsed {
    String(text) => text
    _ => parsed.stringify()
  }
}

///|
fn install_console_shim(
  runtime : @v8.Runtime,
  stdout_lines : Ref[Array[String]],
  stderr_lines : Ref[Array[String]],
) -> Result[Unit, String] {
  let stdout_registered = runtime.register_sync_json_callback(
    "__oden_console_stdout__",
    payload => {
      stdout_lines.val.push(console_payload_text(payload))
      "null"
    },
  )
  guard stdout_registered is Ok(_) else {
    return Err(stdout_registered.unwrap_err().to_string())
  }
  let stderr_registered = runtime.register_sync_json_callback(
    "__oden_console_stderr__",
    payload => {
      stderr_lines.val.push(console_payload_text(payload))
      "null"
    },
  )
  guard stderr_registered is Ok(_) else {
    return Err(stderr_registered.unwrap_err().to_string())
  }
  let installed = runtime.eval_string_with_name(
    "file:///compat/oden-console.js", "(function(){ const root = globalThis; const oden = root.Oden ?? (root.Oden = {}); const format = function(value){ if (typeof value === 'string') return value; try { const text = JSON.stringify(value); return text === undefined ? String(value) : text; } catch (_) { return String(value); } }; const write = function(op, args){ const text = Array.prototype.slice.call(args).map(format).join(' '); MoonBit.opSync(op, text); }; root.console = { log: function(...args){ write('__oden_console_stdout__', args); }, info: function(...args){ write('__oden_console_stdout__', args); }, debug: function(...args){ write('__oden_console_stdout__', args); }, error: function(...args){ write('__oden_console_stderr__', args); }, warn: function(...args){ write('__oden_console_stderr__', args); } }; const process = (typeof root.process === 'object' && root.process !== null) ? root.process : (root.process = {}); if (typeof process.exitCode !== 'number') process.exitCode = 0; const exitImpl = function(code){ const next = Number.isFinite(code) ? (code | 0) : 1; oden.exitCode = next; process.exitCode = next; return next; }; process.exit = exitImpl; if (typeof oden.exitCode !== 'number') oden.exitCode = 0; oden.exit = exitImpl; })()",
  )
  guard installed is Ok(_) else {
    return Err(installed.unwrap_err().to_string())
  }
  Ok(())
}

///|
fn apply_guest_args(
  runtime : @v8.Runtime,
  guest_args : Array[String],
) -> Result[Unit, String] {
  let args_json = guest_args_json(guest_args)
  let set = runtime.eval_string(
    "globalThis.Deno.args = " +
    args_json +
    "; globalThis.Oden.args = " +
    args_json +
    ";",
  )
  guard set is Ok(_) else { return Err(set.unwrap_err().to_string()) }
  Ok(())
}

///|
fn script_resource_name(path : String) -> String {
  if path.has_prefix("file://") {
    path
  } else if path.has_prefix("/") {
    "file://" + path
  } else {
    "file:///" + path
  }
}

///|
fn read_guest_exit_code(runtime : @v8.Runtime) -> Result[Int, String] {
  let value = runtime.eval_string(
    "(function(){ const oden = globalThis.Oden; const process = globalThis.process; if (typeof process === 'object' && process !== null && typeof process.exitCode === 'number') return String(process.exitCode | 0); if (typeof oden === 'object' && oden !== null && typeof oden.exitCode === 'number') return String(oden.exitCode | 0); return '0'; })()",
  )
  guard value is Ok(_) else { return Err(value.unwrap_err().to_string()) }
  try @strconv.parse_int(value.unwrap()) |> Ok catch {
    err => Err("failed to parse guest exit code: " + err.to_string())
  }
}

///|
fn guest_runtime_error_text(built_js_path : String, detail : String) -> String {
  if detail.contains(built_js_path) {
    detail
  } else {
    "oden run guest runtime error: " + built_js_path + "\n" + detail
  }
}

///|
fn make_js_run_result(
  exit_code : Int,
  stdout_lines : Ref[Array[String]],
  stderr_lines : Ref[Array[String]],
) -> OdenJsRunResult {
  OdenJsRunResult::{
    exit_code,
    stdout_lines: stdout_lines.val.copy(),
    stderr_lines: stderr_lines.val.copy(),
  }
}

///|
async fn run_built_js_on_runtime(
  runtime : @v8.Runtime,
  built_js_path : String,
  guest_args : Array[String],
) -> Result[OdenJsRunResult, String] {
  let stdout_lines = Ref::new([])
  let stderr_lines = Ref::new([])
  let installed = @oden.install(runtime)
  guard installed is Ok(_) else {
    return Err(installed.unwrap_err().to_string())
  }
  let console_installed = install_console_shim(
    runtime, stdout_lines, stderr_lines,
  )
  guard console_installed is Ok(_) else {
    return Err(console_installed.unwrap_err())
  }
  let args_applied = apply_guest_args(runtime, guest_args)
  guard args_applied is Ok(_) else { return Err(args_applied.unwrap_err()) }
  let source = @fs.read_file(built_js_path).text() catch {
    err =>
      return Err("failed to read " + built_js_path + ": " + err.to_string())
  }
  let evaluated = runtime.eval_string_with_name(
    script_resource_name(built_js_path),
    source,
  )
  guard evaluated is Ok(_) else {
    stderr_lines.val.push(
      guest_runtime_error_text(
        built_js_path,
        evaluated.unwrap_err().to_string(),
      ),
    )
    return Ok(make_js_run_result(1, stdout_lines, stderr_lines))
  }
  let drained = runtime.run_event_loop_until_idle_async()
  if drained is Err(err) {
    stderr_lines.val.push(
      guest_runtime_error_text(built_js_path, err.to_string()),
    )
    return Ok(make_js_run_result(1, stdout_lines, stderr_lines))
  }
  let exit_code = read_guest_exit_code(runtime)
  guard exit_code is Ok(_) else { return Err(exit_code.unwrap_err()) }
  Ok(make_js_run_result(exit_code.unwrap(), stdout_lines, stderr_lines))
}

///|
async fn write_output_line(text : String, stderr? : Bool = false) -> Unit {
  let out = if stderr { @stdio.stderr } else { @stdio.stdout }
  out.write(text + "\n")
}

///|
async fn write_non_empty_output(text : String, stderr? : Bool = false) -> Unit {
  let trimmed = text.trim(chars="\r\n").to_string()
  if !trimmed.is_empty() {
    write_output_line(trimmed, stderr~)
  }
}

///|
async fn flush_js_run_output(result : OdenJsRunResult) -> Unit {
  for line in result.stdout_lines {
    write_output_line(line)
  }
  for line in result.stderr_lines {
    write_output_line(line, stderr=true)
  }
}

///|
pub async fn execute_run_plan(plan : @oden.OdenCliPlan) -> Result[Int, String] {
  if plan.kind == "run" && plan.target == "js" {
    execute_js_run_plan(plan)
  } else {
    try @process.run(plan.program, plan.argv, cwd=plan.cwd) |> Ok catch {
      err => Err(err.to_string())
    }
  }
}

///|
async fn execute_js_run_plan(plan : @oden.OdenCliPlan) -> Result[Int, String] {
  execute_js_run_plan_in_cwd(plan, plan.cwd)
}

///|
async fn execute_js_run_plan_in_cwd(
  plan : @oden.OdenCliPlan,
  cwd : String,
) -> Result[Int, String] {
  let invocation = parse_run_invocation(plan, cwd)
  guard invocation is Ok(_) else { return Err(invocation.unwrap_err()) }
  let invocation = invocation.unwrap()
  let build_argv = build_run_compile_argv(invocation)
  let (code, stdout, stderr) = @process.collect_output(
    "moon",
    build_argv,
    cwd=invocation.cwd,
  )
  if code != 0 {
    write_non_empty_output(stdout.text())
    write_non_empty_output(stderr.text(), stderr=true)
    return Ok(code)
  }
  let module_config = read_module_config(invocation.cwd)
  guard module_config is Ok(_) else { return Err(module_config.unwrap_err()) }
  let (module_name, source_dir) = module_config.unwrap()
  let built_js_path = resolve_path(
    invocation.cwd,
    resolve_js_artifact_path(
      module_name,
      source_dir,
      invocation.package_path,
      invocation.target_dir,
      invocation.is_release,
    ),
  )
  let runtime = @v8.runtime_new()
  guard runtime is Ok(_) else { return Err(runtime.unwrap_err().to_string()) }
  let runtime = runtime.unwrap()
  defer runtime.dispose()
  let executed = run_built_js_on_runtime(
    runtime,
    built_js_path,
    invocation.guest_args,
  )
  guard executed is Ok(_) else { return Err(executed.unwrap_err()) }
  let executed = executed.unwrap()
  flush_js_run_output(executed)
  Ok(executed.exit_code)
}
