///|
/// Public error contract for V8 runtime operations.
pub suberror V8Error {
  DependencyMissing(String)
  ModuleClosed
  NativeError(String)
  PromiseClosed
  RuntimeClosed
} derive(Eq, @debug.Debug)

///|
pub impl Show for V8Error with fn output(self, logger) {
  match self {
    DependencyMissing(s) => {
      logger.write_string("DependencyMissing(")
      Show::output(s, logger)
      logger.write_string(")")
    }
    ModuleClosed => logger.write_string("ModuleClosed")
    NativeError(s) => {
      logger.write_string("NativeError(")
      Show::output(s, logger)
      logger.write_string(")")
    }
    PromiseClosed => logger.write_string("PromiseClosed")
    RuntimeClosed => logger.write_string("RuntimeClosed")
  }
}
