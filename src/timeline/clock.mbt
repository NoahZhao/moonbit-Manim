///|
/// Positive rational FPS. Duration is measured in seconds.
#derive(Eq, @debug.Debug)
pub struct FrameRate {
  numerator : Int32
  denominator : Int32
}

///|
pub fn FrameRate::new(
  numerator : Int32,
  denominator~ : Int32 = 1,
) -> FrameRate raise @errors.EngineError {
  if numerator <= 0 || denominator <= 0 {
    raise @errors.InvalidArgument(
      "frame rate numerator and denominator must be positive",
    )
  }
  let mut a = numerator
  let mut b = denominator
  while b != 0 {
    let remainder = a % b
    a = b
    b = remainder
  }
  { numerator: numerator / a, denominator: denominator / a, }
}

///|
pub fn FrameRate::fps60() -> FrameRate {
  { numerator: 60, denominator: 1, }
}

///|
/// Compute from the frame index, never from accumulated wall-clock deltas.
pub fn FrameRate::time(self : FrameRate, frame : Int64) -> Double {
  frame.to_double() * self.denominator.to_double() / self.numerator.to_double()
}

///|
/// Frames sample [0,duration). Round each play up, tolerating 1e-9-frame roundoff.
/// Refuse indices beyond Double's exact integer range.
pub fn FrameRate::frame_count(
  self : FrameRate,
  duration : Double,
) -> Int64 raise @errors.EngineError {
  if !@math.finite(duration) || duration < 0.0 {
    raise @errors.InvalidArgument("duration must be finite and non-negative")
  }
  if duration == 0.0 {
    return 0L
  }
  let count = duration *
    self.numerator.to_double() /
    self.denominator.to_double()
  if !@math.finite(count) || count > 9007199254740991.0 {
    raise @errors.InvalidArgument("duration exceeds the supported frame range")
  }
  // Every positive duration emits at least one frame.
  @scalar.ceil(count - 1.0e-9).max(1.0).to_int64()
}
