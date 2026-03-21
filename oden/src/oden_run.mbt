///|
fn run_guest_args_json(guest_args : Array[String]) -> String {
  Json::array(guest_args.map(arg => Json::string(arg))).stringify()
}

///|
fn oden_run_compat_source() -> String {
  "(function(){ " +
  "const root = globalThis; " +
  "const oden = root.Oden ?? (root.Oden = {}); " +
  "const format = function(value){ if (typeof value === 'string') return value; try { const text = JSON.stringify(value); return text === undefined ? String(value) : text; } catch (_) { return String(value); } }; " +
  "const write = function(op, args){ const text = Array.prototype.slice.call(args).map(format).join(' '); MoonBit.opSync(op, text); }; " +
  "root.console = { log: function(...args){ write('__oden_console_stdout__', args); }, info: function(...args){ write('__oden_console_stdout__', args); }, debug: function(...args){ write('__oden_console_stdout__', args); }, error: function(...args){ write('__oden_console_stderr__', args); }, warn: function(...args){ write('__oden_console_stderr__', args); } }; " +
  "const process = (typeof root.process === 'object' && root.process !== null) ? root.process : (root.process = {}); " +
  "const exitImpl = function(code){ const next = Number.isFinite(code) ? (code | 0) : 1; oden.exitCode = next; process.exitCode = next; return next; }; " +
  "process.exit = exitImpl; " +
  "if (typeof process.exitCode !== 'number') process.exitCode = 0; " +
  "oden.exit = exitImpl; " +
  "if (typeof oden.exitCode !== 'number') oden.exitCode = 0; " +
  "oden.__prepareRun = function(args){ const nextArgs = Array.isArray(args) ? args.slice() : []; root.Deno.args = nextArgs.slice(); oden.args = nextArgs.slice(); process.exitCode = 0; oden.exitCode = 0; return null; }; " +
  "oden.__prepareRun([]); " +
  "})();"
}

///|
pub fn run_builder_new() -> @v8.RuntimeBuilder {
  builder_new().eval_snapshot(oden_run_compat_source())
}

///|
pub fn run_snapshot_builder_new() -> @v8.SnapshotBuilder {
  snapshot_builder_new().eval(oden_run_compat_source())
}

///|
pub fn run_image_new() -> Result[@v8.RuntimeImage, @v8.V8Error] {
  run_snapshot_builder_new().build_image()
}

///|
pub fn prepare_run_runtime(
  runtime : @v8.Runtime,
  guest_args : Array[String],
) -> Result[Unit, @v8.V8Error] {
  let prepared = runtime.eval_string(
    "Oden.__prepareRun(" + run_guest_args_json(guest_args) + ")",
  )
  guard prepared is Ok(_) else { return Err(prepared.unwrap_err()) }
  Ok(())
}
