use std::any::Any;
use std::ffi::{c_char, c_int, c_void, CStr, CString};
use std::panic::{self, AssertUnwindSafe};
use std::ptr;
use std::slice;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Once;

type MoonBitBytes = *mut u8;

unsafe extern "C" {
    fn moonbit_make_bytes(size: i32, init: c_int) -> MoonBitBytes;
}

struct Runtime {
    context: v8::Global<v8::Context>,
    isolate: v8::OwnedIsolate,
}

static INIT_V8: Once = Once::new();
static ACTIVE_RUNTIME: AtomicBool = AtomicBool::new(false);

fn ensure_v8() {
    INIT_V8.call_once(|| {
        let platform = v8::new_default_platform(0, false).make_shared();
        v8::V8::initialize_platform(platform);
        v8::V8::initialize();
    });
}

unsafe fn read_raw_ptr(bytes: *const u8) -> *mut c_void {
    if bytes.is_null() {
        ptr::null_mut()
    } else {
        unsafe { ptr::read_unaligned(bytes.cast::<*mut c_void>()) }
    }
}

unsafe fn write_raw_ptr(bytes: *mut u8, value: *mut c_void) {
    if !bytes.is_null() {
        unsafe { ptr::write_unaligned(bytes.cast::<*mut c_void>(), value) };
    }
}

fn clear_error(error_out: *mut u8) {
    unsafe { write_raw_ptr(error_out, ptr::null_mut()) }
}

fn set_error(error_out: *mut u8, message: &str) {
    if error_out.is_null() {
        return;
    }
    let sanitized = message.replace('\0', " ");
    let message =
        CString::new(sanitized).unwrap_or_else(|_| CString::new("V8 bridge error").unwrap());
    unsafe { write_raw_ptr(error_out, message.into_raw().cast()) }
}

fn panic_message(payload: Box<dyn Any + Send>) -> String {
    if let Some(message) = payload.downcast_ref::<&'static str>() {
        (*message).to_string()
    } else if let Some(message) = payload.downcast_ref::<String>() {
        message.clone()
    } else {
        "panic in rusty_v8 bridge".to_string()
    }
}

fn empty_bytes() -> MoonBitBytes {
    unsafe { moonbit_make_bytes(0, 0) }
}

fn copy_bytes_to_moonbit(bytes: &[u8]) -> MoonBitBytes {
    let out = unsafe { moonbit_make_bytes(bytes.len() as i32, 0) };
    if out.is_null() || bytes.is_empty() {
        return out;
    }
    unsafe { ptr::copy_nonoverlapping(bytes.as_ptr(), out, bytes.len()) };
    out
}

fn copy_string_to_moonbit(value: &str) -> MoonBitBytes {
    copy_bytes_to_moonbit(value.as_bytes())
}

#[allow(clippy::unnecessary_wraps)]
fn unsupported_module_resolve_callback<'s>(
    context: v8::Local<'s, v8::Context>,
    specifier: v8::Local<'s, v8::String>,
    _import_attributes: v8::Local<'s, v8::FixedArray>,
    _referrer: v8::Local<'s, v8::Module>,
) -> Option<v8::Local<'s, v8::Module>> {
    v8::callback_scope!(unsafe scope, context);
    v8::scope!(let scope, scope);

    let specifier = specifier.to_rust_string_lossy(scope);
    let message = format!("module imports are not supported yet: {specifier}");
    let exception = v8::String::new(scope, &message)
        .or_else(|| v8::String::new(scope, "module imports are not supported yet"))
        .expect("failed to allocate module resolve exception");
    scope.throw_exception(exception.into());
    None
}

#[no_mangle]
pub extern "C" fn moonbit_ptr_sizeof() -> i32 {
    std::mem::size_of::<*mut c_void>() as i32
}

#[no_mangle]
pub extern "C" fn moonbit_ptr_is_null(bytes: *const u8) -> bool {
    unsafe { read_raw_ptr(bytes).is_null() }
}

#[no_mangle]
pub extern "C" fn moonbit_ptr_clear(bytes: *mut u8) {
    unsafe { write_raw_ptr(bytes, ptr::null_mut()) }
}

#[no_mangle]
pub extern "C" fn moonbit_v8_error_delete_ptr(bytes: *const u8) {
    let ptr = unsafe { read_raw_ptr(bytes) }.cast::<c_char>();
    if ptr.is_null() {
        return;
    }
    unsafe {
        drop(CString::from_raw(ptr));
    }
}

#[no_mangle]
pub extern "C" fn moonbit_v8_error_message_bytes(bytes: *const u8) -> MoonBitBytes {
    let ptr = unsafe { read_raw_ptr(bytes) }.cast::<c_char>();
    if ptr.is_null() {
        return empty_bytes();
    }
    let message = unsafe { CStr::from_ptr(ptr) };
    copy_bytes_to_moonbit(message.to_bytes())
}

#[no_mangle]
pub extern "C" fn moonbit_v8_version_bytes() -> MoonBitBytes {
    match panic::catch_unwind(AssertUnwindSafe(|| {
        copy_string_to_moonbit(v8::V8::get_version())
    })) {
        Ok(bytes) => bytes,
        Err(_) => empty_bytes(),
    }
}

#[no_mangle]
pub extern "C" fn moonbit_v8_runtime_new(error_out: *mut u8) -> u64 {
    clear_error(error_out);
    if ACTIVE_RUNTIME.swap(true, Ordering::SeqCst) {
        set_error(error_out, "only one active runtime is supported for now");
        return 0;
    }

    let result = panic::catch_unwind(AssertUnwindSafe(|| {
        ensure_v8();
        let mut isolate = v8::Isolate::new(v8::CreateParams::default());
        isolate.set_microtasks_policy(v8::MicrotasksPolicy::Explicit);
        let context = {
            v8::scope!(let scope, &mut isolate);
            let context = v8::Context::new(scope, Default::default());
            v8::Global::new(scope, context)
        };
        let runtime = Box::new(Runtime { context, isolate });
        Box::into_raw(runtime) as usize as u64
    }));

    match result {
        Ok(handle) => handle,
        Err(payload) => {
            ACTIVE_RUNTIME.store(false, Ordering::SeqCst);
            set_error(error_out, &panic_message(payload));
            0
        }
    }
}

#[no_mangle]
pub extern "C" fn moonbit_v8_runtime_delete(handle: u64) {
    if handle == 0 {
        return;
    }

    let runtime = handle as usize as *mut Runtime;
    let _ = panic::catch_unwind(AssertUnwindSafe(|| unsafe {
        drop(Box::from_raw(runtime));
    }));
    ACTIVE_RUNTIME.store(false, Ordering::SeqCst);
}

#[no_mangle]
pub extern "C" fn moonbit_v8_runtime_eval(
    handle: u64,
    source: *const u8,
    source_len: i32,
    error_out: *mut u8,
) -> MoonBitBytes {
    clear_error(error_out);

    let result = panic::catch_unwind(AssertUnwindSafe(|| {
        if handle == 0 {
            set_error(error_out, "runtime handle is null");
            return empty_bytes();
        }
        if source.is_null() || source_len < 0 {
            set_error(error_out, "source buffer is invalid");
            return empty_bytes();
        }

        let runtime = unsafe { &mut *(handle as usize as *mut Runtime) };
        let source = unsafe { slice::from_raw_parts(source, source_len as usize) };
        let source = String::from_utf8_lossy(source);

        v8::scope!(let scope, &mut runtime.isolate);
        let context = v8::Local::new(scope, &runtime.context);
        let context_scope = &mut v8::ContextScope::new(scope, context);
        let mut try_catch = v8::TryCatch::new(context_scope);
        let mut try_catch = {
            let try_catch_pinned = unsafe { std::pin::Pin::new_unchecked(&mut try_catch) };
            try_catch_pinned.init()
        };
        let try_catch = &mut try_catch;
        macro_rules! format_exception {
            ($try_catch:expr) => {{
                let exception = $try_catch
                    .stack_trace()
                    .or_else(|| $try_catch.exception())
                    .map(|value| value.to_rust_string_lossy($try_catch))
                    .unwrap_or_else(|| "V8 exception".to_string());

                if let Some(message) = $try_catch.message() {
                    let line = message.get_line_number($try_catch).unwrap_or_default();
                    if line > 0 {
                        format!("line {}: {}", line, exception)
                    } else {
                        exception
                    }
                } else {
                    exception
                }
            }};
        }

        let source = match v8::String::new(try_catch, source.as_ref()) {
            Some(source) => source,
            None => {
                set_error(error_out, "failed to allocate V8 source string");
                return empty_bytes();
            }
        };

        let script = match v8::Script::compile(try_catch, source, None) {
            Some(script) => script,
            None => {
                set_error(error_out, &format_exception!(try_catch));
                return empty_bytes();
            }
        };

        let value = match script.run(try_catch) {
            Some(value) => value,
            None => {
                set_error(error_out, &format_exception!(try_catch));
                return empty_bytes();
            }
        };

        let value = match value.to_string(try_catch) {
            Some(value) => value,
            None => {
                set_error(error_out, &format_exception!(try_catch));
                return empty_bytes();
            }
        };

        copy_string_to_moonbit(&value.to_rust_string_lossy(try_catch))
    }));

    match result {
        Ok(bytes) => bytes,
        Err(payload) => {
            set_error(error_out, &panic_message(payload));
            empty_bytes()
        }
    }
}

#[no_mangle]
pub extern "C" fn moonbit_v8_runtime_perform_microtask_checkpoint(handle: u64, error_out: *mut u8) {
    clear_error(error_out);

    let result = panic::catch_unwind(AssertUnwindSafe(|| {
        if handle == 0 {
            set_error(error_out, "runtime handle is null");
            return;
        }

        let runtime = unsafe { &mut *(handle as usize as *mut Runtime) };
        v8::scope!(let scope, &mut runtime.isolate);
        let context = v8::Local::new(scope, &runtime.context);
        let scope = &mut v8::ContextScope::new(scope, context);
        scope.perform_microtask_checkpoint();
    }));

    if let Err(payload) = result {
        set_error(error_out, &panic_message(payload));
    }
}

#[no_mangle]
pub extern "C" fn moonbit_v8_runtime_eval_async(
    handle: u64,
    source: *const u8,
    source_len: i32,
    error_out: *mut u8,
) -> MoonBitBytes {
    clear_error(error_out);

    let result = panic::catch_unwind(AssertUnwindSafe(|| {
        if handle == 0 {
            set_error(error_out, "runtime handle is null");
            return empty_bytes();
        }
        if source.is_null() || source_len < 0 {
            set_error(error_out, "source buffer is invalid");
            return empty_bytes();
        }

        let runtime = unsafe { &mut *(handle as usize as *mut Runtime) };
        let source = unsafe { slice::from_raw_parts(source, source_len as usize) };
        let source = String::from_utf8_lossy(source);

        v8::scope!(let scope, &mut runtime.isolate);
        let context = v8::Local::new(scope, &runtime.context);
        let context_scope = &mut v8::ContextScope::new(scope, context);
        let mut try_catch = v8::TryCatch::new(context_scope);
        let mut try_catch = {
            let try_catch_pinned = unsafe { std::pin::Pin::new_unchecked(&mut try_catch) };
            try_catch_pinned.init()
        };
        let try_catch = &mut try_catch;
        macro_rules! format_exception {
            ($try_catch:expr) => {{
                let exception = $try_catch
                    .stack_trace()
                    .or_else(|| $try_catch.exception())
                    .map(|value| value.to_rust_string_lossy($try_catch))
                    .unwrap_or_else(|| "V8 exception".to_string());

                if let Some(message) = $try_catch.message() {
                    let line = message.get_line_number($try_catch).unwrap_or_default();
                    if line > 0 {
                        format!("line {}: {}", line, exception)
                    } else {
                        exception
                    }
                } else {
                    exception
                }
            }};
        }

        let source = match v8::String::new(try_catch, source.as_ref()) {
            Some(source) => source,
            None => {
                set_error(error_out, "failed to allocate V8 source string");
                return empty_bytes();
            }
        };

        let script = match v8::Script::compile(try_catch, source, None) {
            Some(script) => script,
            None => {
                set_error(error_out, &format_exception!(try_catch));
                return empty_bytes();
            }
        };

        let value = match script.run(try_catch) {
            Some(value) => value,
            None => {
                set_error(error_out, &format_exception!(try_catch));
                return empty_bytes();
            }
        };

        if !value.is_promise() {
            let value = match value.to_string(try_catch) {
                Some(value) => value,
                None => {
                    set_error(error_out, &format_exception!(try_catch));
                    return empty_bytes();
                }
            };
            return copy_string_to_moonbit(&value.to_rust_string_lossy(try_catch));
        }

        let promise = match v8::Local::<v8::Promise>::try_from(value) {
            Ok(promise) => promise,
            Err(_) => {
                set_error(error_out, "failed to cast promise result");
                return empty_bytes();
            }
        };

        for _ in 0..1024 {
            match promise.state() {
                v8::PromiseState::Pending => {
                    try_catch.perform_microtask_checkpoint();
                }
                v8::PromiseState::Fulfilled => {
                    let value = promise.result(try_catch);
                    let value = match value.to_string(try_catch) {
                        Some(value) => value,
                        None => {
                            set_error(error_out, "failed to stringify fulfilled promise value");
                            return empty_bytes();
                        }
                    };
                    return copy_string_to_moonbit(&value.to_rust_string_lossy(try_catch));
                }
                v8::PromiseState::Rejected => {
                    let reason = promise.result(try_catch);
                    let reason = reason
                        .to_string(try_catch)
                        .map(|value| value.to_rust_string_lossy(try_catch))
                        .unwrap_or_else(|| "Promise rejected".to_string());
                    set_error(error_out, &reason);
                    return empty_bytes();
                }
            }
        }

        set_error(
            error_out,
            "promise is still pending after 1024 microtask checkpoints",
        );
        empty_bytes()
    }));

    match result {
        Ok(bytes) => bytes,
        Err(payload) => {
            set_error(error_out, &panic_message(payload));
            empty_bytes()
        }
    }
}

#[no_mangle]
pub extern "C" fn moonbit_v8_runtime_eval_module(
    handle: u64,
    source: *const u8,
    source_len: i32,
    error_out: *mut u8,
) -> MoonBitBytes {
    clear_error(error_out);

    let result = panic::catch_unwind(AssertUnwindSafe(|| {
        if handle == 0 {
            set_error(error_out, "runtime handle is null");
            return empty_bytes();
        }
        if source.is_null() || source_len < 0 {
            set_error(error_out, "source buffer is invalid");
            return empty_bytes();
        }

        let runtime = unsafe { &mut *(handle as usize as *mut Runtime) };
        let source = unsafe { slice::from_raw_parts(source, source_len as usize) };
        let source = String::from_utf8_lossy(source);

        v8::scope!(let scope, &mut runtime.isolate);
        let context = v8::Local::new(scope, &runtime.context);
        let context_scope = &mut v8::ContextScope::new(scope, context);
        let mut try_catch = v8::TryCatch::new(context_scope);
        let mut try_catch = {
            let try_catch_pinned = unsafe { std::pin::Pin::new_unchecked(&mut try_catch) };
            try_catch_pinned.init()
        };
        let try_catch = &mut try_catch;
        macro_rules! format_exception {
            ($try_catch:expr) => {{
                let exception = $try_catch
                    .stack_trace()
                    .or_else(|| $try_catch.exception())
                    .map(|value| value.to_rust_string_lossy($try_catch))
                    .unwrap_or_else(|| "V8 exception".to_string());

                if let Some(message) = $try_catch.message() {
                    let line = message.get_line_number($try_catch).unwrap_or_default();
                    if line > 0 {
                        format!("line {}: {}", line, exception)
                    } else {
                        exception
                    }
                } else {
                    exception
                }
            }};
        }

        let source = match v8::String::new(try_catch, source.as_ref()) {
            Some(source) => source,
            None => {
                set_error(error_out, "failed to allocate V8 source string");
                return empty_bytes();
            }
        };
        let resource_name = match v8::String::new(try_catch, "moonbit:main.mjs") {
            Some(resource_name) => resource_name,
            None => {
                set_error(error_out, "failed to allocate module resource name");
                return empty_bytes();
            }
        };
        let origin = v8::ScriptOrigin::new(
            try_catch,
            resource_name.into(),
            0,
            0,
            false,
            -1,
            None,
            false,
            false,
            true,
            None,
        );
        let mut source = v8::script_compiler::Source::new(source, Some(&origin));

        let module = match v8::script_compiler::compile_module(try_catch, &mut source) {
            Some(module) => module,
            None => {
                set_error(error_out, &format_exception!(try_catch));
                return empty_bytes();
            }
        };

        match module.instantiate_module(try_catch, unsupported_module_resolve_callback) {
            Some(true) => {}
            Some(false) => {
                set_error(error_out, "module instantiation did not complete");
                return empty_bytes();
            }
            None => {
                set_error(error_out, &format_exception!(try_catch));
                return empty_bytes();
            }
        }

        let value = match module.evaluate(try_catch) {
            Some(value) => value,
            None => {
                set_error(error_out, &format_exception!(try_catch));
                return empty_bytes();
            }
        };

        if !value.is_promise() {
            let value = match value.to_string(try_catch) {
                Some(value) => value,
                None => {
                    set_error(error_out, &format_exception!(try_catch));
                    return empty_bytes();
                }
            };
            return copy_string_to_moonbit(&value.to_rust_string_lossy(try_catch));
        }

        let promise = match v8::Local::<v8::Promise>::try_from(value) {
            Ok(promise) => promise,
            Err(_) => {
                set_error(error_out, "failed to cast module evaluation promise");
                return empty_bytes();
            }
        };

        for _ in 0..1024 {
            match promise.state() {
                v8::PromiseState::Pending => {
                    try_catch.perform_microtask_checkpoint();
                }
                v8::PromiseState::Fulfilled => {
                    let value = promise.result(try_catch);
                    let value = match value.to_string(try_catch) {
                        Some(value) => value,
                        None => {
                            set_error(
                                error_out,
                                "failed to stringify fulfilled module value",
                            );
                            return empty_bytes();
                        }
                    };
                    return copy_string_to_moonbit(&value.to_rust_string_lossy(try_catch));
                }
                v8::PromiseState::Rejected => {
                    let reason = promise.result(try_catch);
                    let reason = reason
                        .to_string(try_catch)
                        .map(|value| value.to_rust_string_lossy(try_catch))
                        .unwrap_or_else(|| "Module evaluation rejected".to_string());
                    set_error(error_out, &reason);
                    return empty_bytes();
                }
            }
        }

        set_error(
            error_out,
            "module evaluation promise is still pending after 1024 microtask checkpoints",
        );
        empty_bytes()
    }));

    match result {
        Ok(bytes) => bytes,
        Err(payload) => {
            set_error(error_out, &panic_message(payload));
            empty_bytes()
        }
    }
}
