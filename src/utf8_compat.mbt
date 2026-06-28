///|
let utf8_replacement_char : Char = (65533).to_char().unwrap()

///|
fn push_utf8_byte(bytes : Array[Byte], value : Int) -> Unit {
  bytes.push(value.to_byte())
}

///|
pub fn utf8_encode(text : String) -> Bytes {
  let out : Array[Byte] = Array::new(capacity=text.length())
  text
  .iter()
  .each(fn(ch) {
    let code = ch.to_int()
    if code <= 127 {
      push_utf8_byte(out, code)
    } else if code <= 2047 {
      push_utf8_byte(out, (192).lor(code >> 6))
      push_utf8_byte(out, (128).lor(code.land(63)))
    } else if code <= 65535 {
      push_utf8_byte(out, (224).lor(code >> 12))
      push_utf8_byte(out, (128).lor((code >> 6).land(63)))
      push_utf8_byte(out, (128).lor(code.land(63)))
    } else {
      push_utf8_byte(out, (240).lor(code >> 18))
      push_utf8_byte(out, (128).lor((code >> 12).land(63)))
      push_utf8_byte(out, (128).lor((code >> 6).land(63)))
      push_utf8_byte(out, (128).lor(code.land(63)))
    }
  })
  Bytes::from_array(out)
}

///|
fn utf8_continuation_byte(value : Int) -> Bool {
  value.land(192) == 128
}

///|
fn utf8_push_codepoint(builder : StringBuilder, code : Int) -> Unit {
  match code.to_char() {
    Some(ch) => builder.write_char(ch)
    None => builder.write_char(utf8_replacement_char)
  }
}

///|
pub fn utf8_decode_lossy(bytes : Bytes) -> String {
  let builder = StringBuilder(size_hint=bytes.length())
  let mut i = 0
  while i < bytes.length() {
    let first = bytes[i].to_int()
    if first <= 127 {
      utf8_push_codepoint(builder, first)
      i = i + 1
      continue
    }
    if first >= 194 && first <= 223 && i + 1 < bytes.length() {
      let second = bytes[i + 1].to_int()
      if utf8_continuation_byte(second) {
        utf8_push_codepoint(builder, (first.land(31) << 6).lor(second.land(63)))
        i = i + 2
        continue
      }
    }
    if first >= 194 && first <= 223 && i + 1 >= bytes.length() {
      builder.write_char(utf8_replacement_char)
      i = bytes.length()
      continue
    }
    if first >= 224 && first <= 239 && i + 2 < bytes.length() {
      let second = bytes[i + 1].to_int()
      let third = bytes[i + 2].to_int()
      let valid_second = if first == 224 {
        second >= 160 && second <= 191
      } else if first == 237 {
        second >= 128 && second <= 159
      } else {
        utf8_continuation_byte(second)
      }
      if valid_second && utf8_continuation_byte(third) {
        utf8_push_codepoint(
          builder,
          (first.land(15) << 12).lor(second.land(63) << 6).lor(third.land(63)),
        )
        i = i + 3
        continue
      }
    }
    if first >= 224 &&
      first <= 239 &&
      i + 2 >= bytes.length() &&
      i + 1 < bytes.length() &&
      utf8_continuation_byte(bytes[i + 1].to_int()) {
      builder.write_char(utf8_replacement_char)
      i = bytes.length()
      continue
    }
    if first >= 240 && first <= 244 && i + 3 < bytes.length() {
      let second = bytes[i + 1].to_int()
      let third = bytes[i + 2].to_int()
      let fourth = bytes[i + 3].to_int()
      let valid_second = if first == 240 {
        second >= 144 && second <= 191
      } else if first == 244 {
        second >= 128 && second <= 143
      } else {
        utf8_continuation_byte(second)
      }
      if valid_second &&
        utf8_continuation_byte(third) &&
        utf8_continuation_byte(fourth) {
        utf8_push_codepoint(
          builder,
          (first.land(7) << 18)
          .lor(second.land(63) << 12)
          .lor(third.land(63) << 6)
          .lor(fourth.land(63)),
        )
        i = i + 4
        continue
      }
    }
    if first >= 240 &&
      first <= 244 &&
      i + 3 >= bytes.length() &&
      i + 1 < bytes.length() &&
      utf8_continuation_byte(bytes[i + 1].to_int()) {
      builder.write_char(utf8_replacement_char)
      i = bytes.length()
      continue
    }
    builder.write_char(utf8_replacement_char)
    i = i + 1
  }
  builder.to_string()
}
