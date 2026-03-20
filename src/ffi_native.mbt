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

///|
#borrow(error_out)
extern "C" fn runtime_perform_microtask_checkpoint_native(
  handle : UInt64,
  error_out : Bytes,
) -> Unit = "moonbit_v8_runtime_perform_microtask_checkpoint"

///|
#borrow(source, error_out)
extern "C" fn runtime_eval_async_native(
  handle : UInt64,
  source : Bytes,
  source_len : Int,
  error_out : Bytes,
) -> Bytes = "moonbit_v8_runtime_eval_async"

///|
#borrow(source, error_out)
extern "C" fn runtime_eval_module_native(
  handle : UInt64,
  source : Bytes,
  source_len : Int,
  error_out : Bytes,
) -> Bytes = "moonbit_v8_runtime_eval_module"
