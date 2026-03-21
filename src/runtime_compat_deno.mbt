///|
fn deno_core_resources_op_name() -> String {
  "__mizchi_v8_deno_resources__"
}

///|
fn deno_core_close_op_name() -> String {
  "__mizchi_v8_deno_close__"
}

///|
fn deno_core_try_close_op_name() -> String {
  "__mizchi_v8_deno_try_close__"
}

///|
fn install_deno_core_resource_compat(
  runtime : Runtime,
) -> Result[Unit, V8Error] {
  let registered_resources = runtime.register_sync_json_result_callback(
    deno_core_resources_op_name(),
    _payload => {
      let resources_json = runtime_resource_list_json(runtime)
      guard resources_json is Ok(_) else {
        return Err(resources_json.unwrap_err().to_string())
      }
      Ok(resources_json.unwrap())
    },
  )
  guard registered_resources is Ok(_) else {
    return Err(registered_resources.unwrap_err())
  }
  let registered_close = runtime.register_sync_json_result_callback(
    deno_core_close_op_name(),
    payload_json => {
      let rid = parse_resource_rid(payload_json)
      guard rid is Ok(_) else { return Err(rid.unwrap_err()) }
      let closed = runtime.close_resource(rid.unwrap())
      guard closed is Ok(_) else { return Err(closed.unwrap_err().to_string()) }
      Ok("null")
    },
  )
  guard registered_close is Ok(_) else {
    return Err(registered_close.unwrap_err())
  }
  let registered_try_close = runtime.register_sync_json_result_callback(
    deno_core_try_close_op_name(),
    payload_json => {
      let rid = parse_resource_rid(payload_json)
      guard rid is Ok(_) else { return Err(rid.unwrap_err()) }
      let closed = runtime.try_close_resource(rid.unwrap())
      guard closed is Ok(_) else { return Err(closed.unwrap_err().to_string()) }
      Ok(Json::boolean(closed.unwrap()).stringify())
    },
  )
  guard registered_try_close is Ok(_) else {
    return Err(registered_try_close.unwrap_err())
  }
  Ok(())
}

///|
fn deno_core_compat_source() -> String {
  "(function(){ " +
  "const root = globalThis; " +
  "const deno = root.Deno ?? (root.Deno = {}); " +
  "const encode = typeof TextEncoder === 'function' ? function(value){ return new TextEncoder().encode(String(value)); } : function(value){ const text = String(value); const out = new Uint8Array(text.length); for (let i = 0; i < text.length; i += 1) out[i] = text.charCodeAt(i) & 255; return out; }; " +
  "const asBytes = function(value){ if (value instanceof Uint8Array) return value; if (ArrayBuffer.isView(value)) return new Uint8Array(value.buffer, value.byteOffset, value.byteLength); if (value instanceof ArrayBuffer) return new Uint8Array(value); return new Uint8Array(0); }; " +
  "const decode = typeof TextDecoder === 'function' ? function(value){ return new TextDecoder().decode(asBytes(value)); } : function(value){ const bytes = asBytes(value); let out = ''; for (let i = 0; i < bytes.length; i += 1) out += String.fromCharCode(bytes[i]); return out; }; " +
  "if (!Array.isArray(deno.args)) deno.args = []; " +
  "if (typeof deno.build !== 'object' || deno.build === null) deno.build = { arch: 'unknown', os: 'unknown', vendor: 'unknown', target: 'unknown' }; " +
  "if (typeof deno.version !== 'object' || deno.version === null) deno.version = { deno: '0.0.0-mizchi-v8', v8: '" +
  version() +
  "', typescript: 'unknown' }; " +
  "if (typeof deno.pid !== 'number') deno.pid = 0; " +
  "if (typeof deno.ppid !== 'number') deno.ppid = 0; " +
  "if (typeof deno.noColor !== 'boolean') deno.noColor = false; " +
  "if (typeof deno.exitCode !== 'number') deno.exitCode = 0; " +
  "if (typeof deno.cwd !== 'function') deno.cwd = function(){ return '/'; }; " +
  "if (typeof deno.execPath !== 'function') deno.execPath = function(){ return '/mizchi-v8/deno'; }; " +
  "if (typeof deno.inspect !== 'function') deno.inspect = function(value, _options){ try { const inspected = JSON.stringify(value); return inspected === undefined ? String(value) : inspected; } catch (_) { return String(value); } }; " +
  "const core = deno.core ?? (deno.core = {}); " +
  "if (typeof core.opSync !== 'function') core.opSync = function(name, payload){ return MoonBit.opSync(name, payload); }; " +
  "if (typeof core.opAsync !== 'function') core.opAsync = function(name, payload){ return MoonBit.opAsync(name, payload); }; " +
  "if (typeof core.opSyncBytes !== 'function') core.opSyncBytes = function(name, payload){ return MoonBit.opSyncBytes(name, payload); }; " +
  "if (typeof core.opAsyncBytes !== 'function') core.opAsyncBytes = function(name, payload){ return MoonBit.opAsyncBytes(name, payload); }; " +
  "if (typeof core.encode !== 'function') core.encode = encode; " +
  "if (typeof core.decode !== 'function') core.decode = decode; " +
  "if (typeof core.resources !== 'function') core.resources = function(){ return MoonBit.opSync('" +
  deno_core_resources_op_name() +
  "', null); }; " +
  "if (typeof core.close !== 'function') core.close = function(rid){ MoonBit.opSync('" +
  deno_core_close_op_name() +
  "', rid); }; " +
  "if (typeof core.tryClose !== 'function') core.tryClose = function(rid){ return MoonBit.opSync('" +
  deno_core_try_close_op_name() +
  "', rid); }; " +
  "if (typeof core.refOpPromise !== 'function') core.refOpPromise = function(promise){ return promise; }; " +
  "if (typeof core.unrefOpPromise !== 'function') core.unrefOpPromise = function(promise){ return promise; }; " +
  "if (typeof core.print !== 'function') core.print = function(message, is_err){ if (typeof console !== 'object' || console === null) return; const text = String(message); if (is_err && typeof console.error === 'function') { console.error(text); return; } if (typeof console.log === 'function') console.log(text); }; " +
  "if (typeof core.ops !== 'object' || core.ops === null) core.ops = new Proxy({}, { get(_target, key) { return typeof key === 'string' ? key : undefined; } }); " +
  "if (typeof core.opsBytes !== 'object' || core.opsBytes === null) core.opsBytes = new Proxy({}, { get(_target, key) { return typeof key === 'string' ? key : undefined; } }); " +
  "return 'ok'; " +
  "})()"
}

///|
pub fn Runtime::install_deno_core_compat(
  self : Runtime,
) -> Result[Unit, V8Error] {
  let registered = install_deno_core_resource_compat(self)
  guard registered is Ok(_) else { return Err(registered.unwrap_err()) }
  install_compat_source(
    self,
    "file:///compat/deno_core.js",
    deno_core_compat_source(),
  )
}

///|
pub fn RuntimeBuilder::with_deno_core_compat(
  self : RuntimeBuilder,
) -> RuntimeBuilder {
  apply_runtime_builder_compat(self, deno_core_compat_source())
}

///|
pub fn SnapshotBuilder::with_deno_core_compat(
  self : SnapshotBuilder,
) -> SnapshotBuilder {
  apply_snapshot_builder_compat(self, deno_core_compat_source())
}
