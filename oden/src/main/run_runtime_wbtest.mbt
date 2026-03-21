///|
fn test_run_plan(args : Array[String]) -> @oden.OdenCliPlan {
  match @oden.route_cli(args) {
    Ok(@oden.OdenCliRoute::Exec(plan)) => plan
    _ => panic()
  }
}

///|
async fn ensure_dir(path : String) -> Unit {
  @fs.mkdir(path, permission=0o755, recursive=true) catch {
    _ => ()
  }
}

///|
async fn write_text_file(path : String, content : String) -> Unit {
  @fs.write_file(path, content, create=0o644)
}

///|
async fn write_temp_run_module(
  dir : String,
  async_main? : Bool = false,
) -> Unit {
  ensure_dir(dir)
  ensure_dir(dir + "/src")
  ensure_dir(dir + "/src/main")
  let moon_mod = if async_main {
    (
      #|{
      #|  "name": "tmp/oden_run_fixture",
      #|  "version": "0.1.0",
      #|  "source": "src",
      #|  "deps": {
      #|    "moonbitlang/async": "0.16.8"
      #|  }
      #|}
    )
  } else {
    (
      #|{
      #|  "name": "tmp/oden_run_fixture",
      #|  "version": "0.1.0",
      #|  "source": "src"
      #|}
    )
  }
  write_text_file(dir + "/moon.mod.json", moon_mod)
  let moon_pkg = if async_main {
    (
      #|import {
      #|  "moonbitlang/async",
      #|}
      #|
      #|options("is-main": true)
    )
  } else {
    (
      #|options("is-main": true)
    )
  }
  write_text_file(dir + "/src/main/moon.pkg", moon_pkg)
  let main_source = if async_main {
    (
      #|async fn main {
      #|  println("start")
      #|  @async.sleep(0)
      #|  println("done")
      #|}
    )
  } else {
    (
      #|fn main {
      #|  println("hello")
      #|}
    )
  }
  write_text_file(dir + "/src/main/main.mbt", main_source)
}

///|
test "run invocation splits moon args and guest args" {
  let result = match
    parse_run_invocation(
      test_run_plan(["run", "app/main", "--release", "--", "foo", "bar"]),
      ".",
    ) {
    Ok(invocation) =>
      invocation.package_path +
      ":" +
      invocation.target_dir +
      ":" +
      invocation.is_release.to_string() +
      ":" +
      invocation.moon_args.length().to_string() +
      ":" +
      invocation.guest_args.join(",")
    Err(err) => err
  }
  inspect(result, content="app/main:.oden/run:true:3:foo,bar")
}

///|
test "resolve js artifact path for nested package" {
  inspect(
    resolve_js_artifact_path(
      "tmp/oden_run_fixture", "src", "src/main", ".oden/run", false,
    ),
    content=".oden/run/js/debug/build/main/main.js",
  )
}

///|
test "resolve js artifact path for root package" {
  inspect(
    resolve_js_artifact_path(
      "tmp/oden_run_fixture", "src", "src", ".oden/run", true,
    ),
    content=".oden/run/js/release/build/oden_run_fixture.js",
  )
}

///|
async test "built js runtime runner sets args and drains timeout" {
  let dir = "/tmp/mizchi_v8_oden_run_runtime_probe"
  ensure_dir(dir)
  let script_path = dir + "/entry.js"
  write_text_file(
    script_path, "globalThis.__args = Oden.args.slice(); globalThis.__ticks = []; setTimeout(() => { globalThis.__ticks.push('tick') }, 0);",
  )
  let result = match @v8.runtime_new() {
    Ok(runtime) => {
      defer runtime.dispose()
      let executed = run_built_js_on_runtime(runtime, script_path, ["a", "b"])
      guard executed is Ok(_) else { Err(executed.unwrap_err()) }
      match
        runtime.eval_json(
          "({ args: globalThis.__args, ticks: globalThis.__ticks })",
        ) {
        Ok(value) => Ok(value)
        Err(err) => Err(err.to_string())
      }
    }
    Err(err) => Err(err.to_string())
  }
  inspect(
    result,
    content="Ok(\"{\\\"args\\\":[\\\"a\\\",\\\"b\\\"],\\\"ticks\\\":[\\\"tick\\\"]}\")",
  )
}

///|
async test "execute js run plan builds temp module and runs through v8" {
  let dir = "/tmp/mizchi_v8_oden_run_build_fixture"
  write_temp_run_module(dir, async_main=true)
  let result = execute_js_run_plan_in_cwd(test_run_plan(["run"]), dir)
  inspect(result, content="Ok(0)")
}
