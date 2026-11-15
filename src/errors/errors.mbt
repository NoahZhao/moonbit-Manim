///|
/// Errors at public engine boundaries; invalid scene data never silently enters playback.
#derive(@debug.Debug)
pub(all) suberror EngineError {
  InvalidArgument(String)
  InvalidHandle
  InvalidHierarchy(String)
  UnsupportedMorph(String)
  AnimationConflict
  SceneBusy
  SceneFailed
}
