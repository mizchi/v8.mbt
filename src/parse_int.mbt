///|
fn parse_ascii_int(text : StringView) -> Result[Int, String] {
  let len = text.length()
  if len == 0 {
    return Err("empty input")
  }
  let minus = (45).to_uint16()
  let plus = (43).to_uint16()
  let zero = (48).to_uint16()
  let nine = (57).to_uint16()
  let mut index = 0
  let mut sign = 1
  if text[0] == minus {
    sign = -1
    index = 1
  } else if text[0] == plus {
    index = 1
  }
  if index == len {
    return Err("missing digits")
  }
  let mut value = 0
  while index < len {
    let code = text[index]
    if code < zero || code > nine {
      return Err("invalid digit")
    }
    value = value * 10 + code.to_int() - 48
    index = index + 1
  }
  Ok(value * sign)
}
