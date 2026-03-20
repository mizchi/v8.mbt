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
