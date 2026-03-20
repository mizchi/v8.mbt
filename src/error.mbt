///|
/// Public error contract for V8 runtime operations.
pub suberror V8Error {
  DependencyMissing(String)
  NativeError(String)
  RuntimeClosed
} derive(Eq, Show)
