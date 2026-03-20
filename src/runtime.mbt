///|
struct RuntimeState {
  mut handle : UInt64
}

///|
pub struct Runtime {
  priv state : Ref[RuntimeState]
}

///|
pub fn version() -> String {
  @utf8.decode_lossy(version_bytes_native())
}

///|
pub fn runtime_new() -> Result[Runtime, V8Error] {
  let err_ptr = make_ptr_buffer()
  native_ptr_clear(err_ptr)
  let handle = runtime_new_native(err_ptr)
  if handle == 0 {
    Err(
      take_native_error(
        err_ptr,
        V8Error::DependencyMissing("failed to initialize V8 runtime"),
      ),
    )
  } else if not(native_ptr_is_null(err_ptr)) {
    Err(
      take_native_error(
        err_ptr,
        V8Error::DependencyMissing("failed to initialize V8 runtime"),
      ),
    )
  } else {
    Ok(Runtime::{ state: Ref::new(RuntimeState::{ handle, }) })
  }
}

///|
pub fn Runtime::is_closed(self : Runtime) -> Bool {
  self.state.val.handle == 0
}

///|
pub fn Runtime::dispose(self : Runtime) -> Unit {
  let handle = self.state.val.handle
  if handle != 0 {
    runtime_delete_native(handle)
    self.state.val.handle = 0
  }
}

///|
pub fn Runtime::eval_string(
  self : Runtime,
  source : String,
) -> Result[String, V8Error] {
  let handle = self.state.val.handle
  if handle == 0 {
    return Err(V8Error::RuntimeClosed)
  }
  let err_ptr = make_ptr_buffer()
  native_ptr_clear(err_ptr)
  let source_bytes = @utf8.encode(source)
  let result_bytes = runtime_eval_native(
    handle,
    source_bytes,
    source_bytes.length(),
    err_ptr,
  )
  if not(native_ptr_is_null(err_ptr)) {
    Err(
      take_native_error(
        err_ptr,
        V8Error::NativeError("runtime_eval_native failed"),
      ),
    )
  } else {
    Ok(@utf8.decode_lossy(result_bytes))
  }
}

///|
pub fn Runtime::perform_microtask_checkpoint(
  self : Runtime,
) -> Result[Unit, V8Error] {
  let handle = self.state.val.handle
  if handle == 0 {
    return Err(V8Error::RuntimeClosed)
  }
  let err_ptr = make_ptr_buffer()
  native_ptr_clear(err_ptr)
  runtime_perform_microtask_checkpoint_native(handle, err_ptr)
  if not(native_ptr_is_null(err_ptr)) {
    Err(
      take_native_error(
        err_ptr,
        V8Error::NativeError(
          "runtime_perform_microtask_checkpoint_native failed",
        ),
      ),
    )
  } else {
    Ok(())
  }
}

///|
pub fn Runtime::eval_async_string(
  self : Runtime,
  source : String,
) -> Result[String, V8Error] {
  let handle = self.state.val.handle
  if handle == 0 {
    return Err(V8Error::RuntimeClosed)
  }
  let err_ptr = make_ptr_buffer()
  native_ptr_clear(err_ptr)
  let source_bytes = @utf8.encode(source)
  let result_bytes = runtime_eval_async_native(
    handle,
    source_bytes,
    source_bytes.length(),
    err_ptr,
  )
  if not(native_ptr_is_null(err_ptr)) {
    Err(
      take_native_error(
        err_ptr,
        V8Error::NativeError("runtime_eval_async_native failed"),
      ),
    )
  } else {
    Ok(@utf8.decode_lossy(result_bytes))
  }
}

///|
pub fn Runtime::eval_module_string(
  self : Runtime,
  source : String,
) -> Result[String, V8Error] {
  let handle = self.state.val.handle
  if handle == 0 {
    return Err(V8Error::RuntimeClosed)
  }
  let err_ptr = make_ptr_buffer()
  native_ptr_clear(err_ptr)
  let source_bytes = @utf8.encode(source)
  let result_bytes = runtime_eval_module_native(
    handle,
    source_bytes,
    source_bytes.length(),
    err_ptr,
  )
  if not(native_ptr_is_null(err_ptr)) {
    Err(
      take_native_error(
        err_ptr,
        V8Error::NativeError("runtime_eval_module_native failed"),
      ),
    )
  } else {
    Ok(@utf8.decode_lossy(result_bytes))
  }
}

///|
pub fn[T] with_runtime(
  f : (Runtime) -> Result[T, V8Error],
) -> Result[T, V8Error] {
  match runtime_new() {
    Ok(runtime) => {
      let result = f(runtime)
      runtime.dispose()
      result
    }
    Err(err) => Err(err)
  }
}

///|
pub fn eval_string(source : String) -> Result[String, V8Error] {
  with_runtime(fn(runtime) { runtime.eval_string(source) })
}

///|
pub fn eval_async_string(source : String) -> Result[String, V8Error] {
  with_runtime(fn(runtime) { runtime.eval_async_string(source) })
}

///|
pub fn eval_module_string(source : String) -> Result[String, V8Error] {
  with_runtime(fn(runtime) { runtime.eval_module_string(source) })
}
