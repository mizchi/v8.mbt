///|
fn install_compat_source(
  runtime : Runtime,
  resource_name : String,
  source : String,
) -> Result[Unit, V8Error] {
  let installed = runtime.eval_string_with_name(resource_name, source)
  guard installed is Ok(_) else { return Err(installed.unwrap_err()) }
  Ok(())
}

///|
fn apply_runtime_builder_compat(
  builder : RuntimeBuilder,
  source : String,
) -> RuntimeBuilder {
  builder.eval_snapshot(source)
}

///|
fn apply_snapshot_builder_compat(
  builder : SnapshotBuilder,
  source : String,
) -> SnapshotBuilder {
  builder.eval(source)
}
