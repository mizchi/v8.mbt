///|
test "oden module can expose cli manifest" {
  let result = match cli_manifest_json() {
    Ok(value) =>
      Ok(
        value.contains("\"run\"").to_string() +
        ":" +
        value.contains("\"bundle\"").to_string() +
        ":" +
        value.contains("\"fmt\"").to_string() +
        ":" +
        value.contains("\"info\"").to_string() +
        ":" +
        value.contains("\"task\"").to_string() +
        ":" +
        value.contains("\"plan\"").to_string() +
        ":" +
        value.contains("\"defaultOutDir\":\".oden/build/wasm-gc\"").to_string() +
        ":" +
        value.contains("\"language\":\"moonbit\"").to_string() +
        ":" +
        value.contains("\"firstClassTargets\":[\"js\",\"wasm\"]").to_string() +
        ":" +
        value.contains("\"execPath\":\"/mizchi-oden/bin/oden\"").to_string(),
      )
    Err(err) => Err(err)
  }
  inspect(
    result,
    content="Ok(\"true:true:true:true:true:true:true:true:true:true\")",
  )
}

///|
test "oden routes run command to moon js target" {
  let result = match route_cli(["run"]) {
    Ok(OdenCliRoute::Exec(plan)) =>
      plan.name +
      ":" +
      plan.program +
      ":" +
      plan.target +
      ":" +
      plan.argv[0] +
      ":" +
      plan.argv[1] +
      ":" +
      plan.argv[2] +
      ":" +
      plan.argv[3]
    Ok(_) => "unexpected"
    Err(err) => err
  }
  inspect(result, content="run:moon:js:run:src/main:--target:js")
}

///|
test "oden routes bundle command to moon wasm build" {
  let result = match route_cli(["bundle", "app/main", "--release"]) {
    Ok(OdenCliRoute::Exec(plan)) =>
      plan.name +
      ":" +
      plan.program +
      ":" +
      plan.target +
      ":" +
      plan.out_dir.unwrap_or("none") +
      ":" +
      plan.argv[0] +
      ":" +
      plan.argv[1] +
      ":" +
      plan.argv[2] +
      ":" +
      plan.argv[3] +
      ":" +
      plan.argv[4] +
      ":" +
      plan.argv[5] +
      ":" +
      plan.argv[6]
    Ok(_) => "unexpected"
    Err(err) => err
  }
  inspect(
    result,
    content="bundle:moon:wasm-gc:.oden/build/wasm-gc:build:app/main:--target:wasm-gc:--release:--target-dir:.oden/build/wasm-gc",
  )
}

///|
test "oden keeps explicit target override" {
  let result = match route_cli(["check", "--target", "wasm"]) {
    Ok(OdenCliRoute::Exec(plan)) =>
      plan.target + ":" + plan.argv[0] + ":" + plan.argv[1] + ":" + plan.argv[2]
    Ok(_) => "unexpected"
    Err(err) => err
  }
  inspect(result, content="wasm:check:--target:wasm")
}

///|
test "oden routes fmt command without target injection" {
  let result = match route_cli(["fmt", "--check"]) {
    Ok(OdenCliRoute::Exec(plan)) =>
      plan.name +
      ":" +
      plan.program +
      ":" +
      plan.target +
      ":" +
      plan.argv[0] +
      ":" +
      plan.argv[1]
    Ok(_) => "unexpected"
    Err(err) => err
  }
  inspect(result, content="fmt:moon:none:fmt:--check")
}

///|
test "oden routes info command to moon info js target" {
  let result = match route_cli(["info"]) {
    Ok(OdenCliRoute::Exec(plan)) =>
      plan.name +
      ":" +
      plan.program +
      ":" +
      plan.target +
      ":" +
      plan.argv[0] +
      ":" +
      plan.argv[1] +
      ":" +
      plan.argv[2]
    Ok(_) => "unexpected"
    Err(err) => err
  }
  inspect(result, content="info:moon:js:info:--target:js")
}

///|
test "oden routes task summary to just" {
  let result = match route_cli(["task"]) {
    Ok(OdenCliRoute::Exec(plan)) =>
      plan.name + ":" + plan.program + ":" + plan.target + ":" + plan.argv[0]
    Ok(_) => "unexpected"
    Err(err) => err
  }
  inspect(result, content="task:just:none:--summary")
}

///|
test "oden routes task arguments to just without rewriting" {
  let result = match route_cli(["task", "check", "--target", "native"]) {
    Ok(OdenCliRoute::Exec(plan)) =>
      plan.name +
      ":" +
      plan.program +
      ":" +
      plan.target +
      ":" +
      plan.argv[0] +
      ":" +
      plan.argv[1] +
      ":" +
      plan.argv[2]
    Ok(_) => "unexpected"
    Err(err) => err
  }
  inspect(result, content="task:just:none:check:--target:native")
}

///|
test "oden routes plan command without executing" {
  let result = match route_cli(["plan", "bundle", "app/main"]) {
    Ok(OdenCliRoute::Plan(plan)) =>
      plan.name +
      ":" +
      plan.program +
      ":" +
      plan.target +
      ":" +
      plan.out_dir.unwrap_or("none") +
      ":" +
      plan.argv[0] +
      ":" +
      plan.argv[1] +
      ":" +
      plan.argv[2] +
      ":" +
      plan.argv[3] +
      ":" +
      plan.argv[4] +
      ":" +
      plan.argv[5]
    Ok(_) => "unexpected"
    Err(err) => err
  }
  inspect(
    result,
    content="bundle:moon:wasm-gc:.oden/build/wasm-gc:build:app/main:--target:wasm-gc:--target-dir:.oden/build/wasm-gc",
  )
}

///|
test "oden keeps explicit bundle target dir override" {
  let result = match
    route_cli(["bundle", "--target", "js", "--target-dir", "dist/js"]) {
    Ok(OdenCliRoute::Exec(plan)) =>
      plan.target +
      ":" +
      plan.out_dir.unwrap_or("none") +
      ":" +
      plan.argv[0] +
      ":" +
      plan.argv[1] +
      ":" +
      plan.argv[2] +
      ":" +
      plan.argv[3] +
      ":" +
      plan.argv[4] +
      ":" +
      plan.argv[5]
    Ok(_) => "unexpected"
    Err(err) => err
  }
  inspect(
    result,
    content="js:dist/js:build:src/main:--target:js:--target-dir:dist/js",
  )
}

///|
test "oden rejects empty plan command" {
  let result = match route_cli(["plan"]) {
    Ok(_) => "unexpected"
    Err(err) => err
  }
  inspect(result, content="plan requires a subcommand")
}

///|
test "oden can stringify plan json" {
  let result = match route_cli(["plan", "task", "check"]) {
    Ok(OdenCliRoute::Plan(plan)) => plan_json(plan)
    Ok(_) => "unexpected"
    Err(err) => err
  }
  inspect(
    result.contains("\"name\":\"task\"").to_string() +
    ":" +
    result.contains("\"program\":\"just\"").to_string() +
    ":" +
    result.contains("\"kind\":\"task\"").to_string() +
    ":" +
    result.contains("\"cwd\":\".\"").to_string() +
    ":" +
    result.contains("\"argv\":[\"check\"]").to_string() +
    ":" +
    result.contains("\"outDir\":null").to_string() +
    ":" +
    result.contains("\"target\":\"none\"").to_string(),
    content="true:true:true:true:true:true:true",
  )
}

///|
test "oden can stringify bundle out dir in plan json" {
  let result = match route_cli(["plan", "bundle"]) {
    Ok(OdenCliRoute::Plan(plan)) => plan_json(plan)
    Ok(_) => "unexpected"
    Err(err) => err
  }
  inspect(
    result.contains("\"outDir\":\".oden/build/wasm-gc\"").to_string(),
    content="true",
  )
}

///|
test "oden supports help and version aliases" {
  let result = match
    (
      route_cli(["-h"]),
      route_cli(["--help"]),
      route_cli(["version"]),
      route_cli(["--version"]),
      route_cli(["-V"]),
    ) {
    (
      Ok(OdenCliRoute::Help),
      Ok(OdenCliRoute::Help),
      Ok(OdenCliRoute::Version),
      Ok(OdenCliRoute::Version),
      Ok(OdenCliRoute::Version),
    ) => "ok"
    _ => "unexpected"
  }
  inspect(result, content="ok")
}

///|
test "oden can expose version text" {
  let result = version_text()
  inspect(
    result.contains("oden 0.0.0-mizchi-v8").to_string() +
    ":" +
    result.contains("v8 ").to_string() +
    ":" +
    result.contains("moonbit ").to_string(),
    content="true:true:true",
  )
}

///|
test "oden builder preloads compat" {
  let result = builder_new().with_runtime(fn(runtime) {
    runtime.eval_json(
      "({ sameCore: Oden.core === Deno.core, bundleTarget: Oden.cli.command('bundle').defaultTarget, hasFmt: Oden.cli.command('fmt') !== null, hasTask: Oden.cli.command('task') !== null, hasPlan: Oden.cli.command('plan') !== null, execPath: Oden.execPath() })",
    )
  })
  inspect(
    result,
    content="Ok(\"{\\\"sameCore\\\":true,\\\"bundleTarget\\\":\\\"wasm\\\",\\\"hasFmt\\\":true,\\\"hasTask\\\":true,\\\"hasPlan\\\":true,\\\"execPath\\\":\\\"/mizchi-oden/bin/oden\\\"}\")",
  )
}

///|
test "oden can install compat on raw runtime" {
  let result = @v8.with_runtime(fn(runtime) {
    let installed = install(runtime)
    guard installed is Ok(_) else { return Err(installed.unwrap_err()) }
    runtime.eval_json(
      "({ hasSleep: typeof Oden.sleep === 'function', runTarget: Oden.cli.command('run').defaultTarget, hasInfo: Oden.cli.command('info') !== null })",
    )
  })
  inspect(
    result,
    content="Ok(\"{\\\"hasSleep\\\":true,\\\"runTarget\\\":\\\"js\\\",\\\"hasInfo\\\":true}\")",
  )
}
