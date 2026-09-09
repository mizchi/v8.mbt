///|
test "native pointer null check handles nonzero pointer bytes" {
  @debug.debug_inspect(native_ptr_is_null(make_ptr_buffer()), content="true")
  let buffer = Bytes::make(native_ptr_sizeof(), 255)
  @debug.debug_inspect(native_ptr_is_null(buffer), content="false")
  native_ptr_clear(buffer)
  @debug.debug_inspect(native_ptr_is_null(buffer), content="true")
}
