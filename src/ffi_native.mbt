///|
extern "C" fn version_bytes_native() -> Bytes = "moonbit_v8_version_bytes"

///|
#borrow(error_out)
extern "C" fn runtime_new_native(error_out : Bytes) -> UInt64 = "moonbit_v8_runtime_new"

///|
extern "C" fn runtime_delete_native(handle : UInt64) -> Unit = "moonbit_v8_runtime_delete"

///|
#borrow(source, error_out)
extern "C" fn runtime_eval_native(
  handle : UInt64,
  source : Bytes,
  source_len : Int,
  error_out : Bytes,
) -> Bytes = "moonbit_v8_runtime_eval"
