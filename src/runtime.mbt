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
pub fn snapshot_create(source : String) -> Result[Bytes, V8Error] {
  let err_ptr = make_ptr_buffer()
  native_ptr_clear(err_ptr)
  let source_bytes = @utf8.encode(source)
  let snapshot = snapshot_create_native(
    source_bytes,
    source_bytes.length(),
    err_ptr,
  )
  if not(native_ptr_is_null(err_ptr)) {
    Err(
      take_native_error(
        err_ptr,
        V8Error::NativeError("snapshot_create_native failed"),
      ),
    )
  } else {
    Ok(snapshot)
  }
}

///|
pub fn snapshot_extend(
  snapshot : Bytes,
  source : String,
) -> Result[Bytes, V8Error] {
  let err_ptr = make_ptr_buffer()
  native_ptr_clear(err_ptr)
  let source_bytes = @utf8.encode(source)
  let extended = snapshot_extend_native(
    snapshot,
    snapshot.length(),
    source_bytes,
    source_bytes.length(),
    err_ptr,
  )
  if not(native_ptr_is_null(err_ptr)) {
    Err(
      take_native_error(
        err_ptr,
        V8Error::NativeError("snapshot_extend_native failed"),
      ),
    )
  } else {
    Ok(extended)
  }
}

///|
fn runtime_from_handle(
  handle : UInt64,
  err_ptr : Bytes,
  fallback : V8Error,
) -> Result[Runtime, V8Error] {
  if handle == 0 {
    Err(take_native_error(err_ptr, fallback))
  } else if not(native_ptr_is_null(err_ptr)) {
    Err(take_native_error(err_ptr, fallback))
  } else {
    Ok(Runtime::{ state: Ref::new(RuntimeState::{ handle, }) })
  }
}

///|
pub fn runtime_new() -> Result[Runtime, V8Error] {
  let err_ptr = make_ptr_buffer()
  native_ptr_clear(err_ptr)
  let handle = runtime_new_native(err_ptr)
  runtime_from_handle(
    handle,
    err_ptr,
    V8Error::DependencyMissing("failed to initialize V8 runtime"),
  )
}

///|
pub fn runtime_new_with_snapshot(snapshot : Bytes) -> Result[Runtime, V8Error] {
  let err_ptr = make_ptr_buffer()
  native_ptr_clear(err_ptr)
  let handle = runtime_new_with_snapshot_native(
    snapshot,
    snapshot.length(),
    err_ptr,
  )
  runtime_from_handle(
    handle,
    err_ptr,
    V8Error::NativeError("runtime_new_with_snapshot_native failed"),
  )
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
pub fn Runtime::load_module(
  self : Runtime,
  specifier : String,
  source : String,
) -> Result[Unit, V8Error] {
  let handle = self.state.val.handle
  if handle == 0 {
    return Err(V8Error::RuntimeClosed)
  }
  let err_ptr = make_ptr_buffer()
  native_ptr_clear(err_ptr)
  let specifier_bytes = @utf8.encode(specifier)
  let source_bytes = @utf8.encode(source)
  runtime_load_module_native(
    handle,
    specifier_bytes,
    specifier_bytes.length(),
    source_bytes,
    source_bytes.length(),
    err_ptr,
  )
  if not(native_ptr_is_null(err_ptr)) {
    Err(
      take_native_error(
        err_ptr,
        V8Error::NativeError("runtime_load_module_native failed"),
      ),
    )
  } else {
    Ok(())
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
pub fn Runtime::eval_string_with_name(
  self : Runtime,
  resource_name : String,
  source : String,
) -> Result[String, V8Error] {
  let handle = self.state.val.handle
  if handle == 0 {
    return Err(V8Error::RuntimeClosed)
  }
  let err_ptr = make_ptr_buffer()
  native_ptr_clear(err_ptr)
  let resource_name_bytes = @utf8.encode(resource_name)
  let source_bytes = @utf8.encode(source)
  let result_bytes = runtime_eval_with_name_native(
    handle,
    resource_name_bytes,
    resource_name_bytes.length(),
    source_bytes,
    source_bytes.length(),
    err_ptr,
  )
  if not(native_ptr_is_null(err_ptr)) {
    Err(
      take_native_error(
        err_ptr,
        V8Error::NativeError("runtime_eval_with_name_native failed"),
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
pub fn Runtime::eval_async_string_with_name(
  self : Runtime,
  resource_name : String,
  source : String,
) -> Result[String, V8Error] {
  let handle = self.state.val.handle
  if handle == 0 {
    return Err(V8Error::RuntimeClosed)
  }
  let err_ptr = make_ptr_buffer()
  native_ptr_clear(err_ptr)
  let resource_name_bytes = @utf8.encode(resource_name)
  let source_bytes = @utf8.encode(source)
  let result_bytes = runtime_eval_async_with_name_native(
    handle,
    resource_name_bytes,
    resource_name_bytes.length(),
    source_bytes,
    source_bytes.length(),
    err_ptr,
  )
  if not(native_ptr_is_null(err_ptr)) {
    Err(
      take_native_error(
        err_ptr,
        V8Error::NativeError("runtime_eval_async_with_name_native failed"),
      ),
    )
  } else {
    Ok(@utf8.decode_lossy(result_bytes))
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
pub fn Runtime::eval_module_string_with_specifier(
  self : Runtime,
  specifier : String,
  source : String,
) -> Result[String, V8Error] {
  let handle = self.state.val.handle
  if handle == 0 {
    return Err(V8Error::RuntimeClosed)
  }
  let err_ptr = make_ptr_buffer()
  native_ptr_clear(err_ptr)
  let specifier_bytes = @utf8.encode(specifier)
  let source_bytes = @utf8.encode(source)
  let result_bytes = runtime_eval_module_with_specifier_native(
    handle,
    specifier_bytes,
    specifier_bytes.length(),
    source_bytes,
    source_bytes.length(),
    err_ptr,
  )
  if not(native_ptr_is_null(err_ptr)) {
    Err(
      take_native_error(
        err_ptr,
        V8Error::NativeError("runtime_eval_module_with_specifier_native failed"),
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
pub fn[T] with_runtime_with_snapshot(
  snapshot : Bytes,
  f : (Runtime) -> Result[T, V8Error],
) -> Result[T, V8Error] {
  match runtime_new_with_snapshot(snapshot) {
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
pub fn eval_string_with_name(
  resource_name : String,
  source : String,
) -> Result[String, V8Error] {
  with_runtime(fn(runtime) {
    runtime.eval_string_with_name(resource_name, source)
  })
}

///|
pub fn eval_async_string(source : String) -> Result[String, V8Error] {
  with_runtime(fn(runtime) { runtime.eval_async_string(source) })
}

///|
pub fn eval_async_string_with_name(
  resource_name : String,
  source : String,
) -> Result[String, V8Error] {
  with_runtime(fn(runtime) {
    runtime.eval_async_string_with_name(resource_name, source)
  })
}

///|
pub fn eval_module_string(source : String) -> Result[String, V8Error] {
  with_runtime(fn(runtime) { runtime.eval_module_string(source) })
}

///|
pub fn eval_module_string_with_specifier(
  specifier : String,
  source : String,
) -> Result[String, V8Error] {
  with_runtime(fn(runtime) {
    runtime.eval_module_string_with_specifier(specifier, source)
  })
}
