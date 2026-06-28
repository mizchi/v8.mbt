///|
test "utf8 compat roundtrips multibyte strings" {
  let text = String::from_array([
    (233).to_char().unwrap(),
    (128578).to_char().unwrap(),
    (26085).to_char().unwrap(),
    (26412).to_char().unwrap(),
  ])
  let bytes = Bytes::from_array([
    (195).to_byte(),
    (169).to_byte(),
    (240).to_byte(),
    (159).to_byte(),
    (153).to_byte(),
    (130).to_byte(),
    (230).to_byte(),
    (151).to_byte(),
    (165).to_byte(),
    (230).to_byte(),
    (156).to_byte(),
    (172).to_byte(),
  ])
  @debug.debug_inspect(utf8_encode(text) == bytes, content="true")
  @debug.debug_inspect(utf8_decode_lossy(bytes) == text, content="true")
}

///|
test "utf8 compat replaces invalid sequences" {
  let replacement = String::from_array([(65533).to_char().unwrap()])
  @debug.debug_inspect(
    utf8_decode_lossy(Bytes::from_array([(255).to_byte()])) == replacement,
    content="true",
  )
  @debug.debug_inspect(
    utf8_decode_lossy(Bytes::from_array([(226).to_byte(), (130).to_byte()])) ==
    replacement,
    content="true",
  )
}
