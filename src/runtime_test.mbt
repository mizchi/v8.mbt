///|
fn[T] is_err(result : Result[T, V8Error]) -> Bool {
  match result {
    Ok(_) => false
    Err(_) => true
  }
}

///|
test "version is exposed" {
  inspect(version().length() > 0, content="true")
}

///|
test "eval string concatenation" {
  inspect(
    eval_string("'Hello' + ', MoonBit!'"),
    content="Ok(\"Hello, MoonBit!\")",
  )
}

///|
test "eval arithmetic" {
  inspect(eval_string("1 + 2"), content="Ok(\"3\")")
}

///|
test "syntax error surfaces as err" {
  inspect(is_err(eval_string("let = ;")), content="true")
}

///|
test "eval async string resolves promise" {
  inspect(
    eval_async_string(
      "(async () => { return (await Promise.resolve(39)) + 3 })()",
    ),
    content="Ok(\"42\")",
  )
}

///|
test "rejected promise surfaces as err" {
  inspect(
    is_err(eval_async_string("Promise.reject(new Error('boom'))")),
    content="true",
  )
}

///|
test "microtask checkpoint drains scheduled jobs" {
  let result = with_runtime(fn(runtime) {
    let scheduled = runtime.eval_string(
      "globalThis.__x = 0; Promise.resolve().then(() => { globalThis.__x = 42 }); 'scheduled'",
    )
    guard scheduled is Ok(_) else { return Err(scheduled.unwrap_err()) }
    let flushed = runtime.perform_microtask_checkpoint()
    guard flushed is Ok(_) else { return Err(flushed.unwrap_err()) }
    runtime.eval_string("globalThis.__x")
  })
  inspect(result, content="Ok(\"42\")")
}
