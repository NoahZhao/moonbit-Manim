///|
/// A frozen frame description; no native pointers or browser objects cross this boundary.
#derive(Eq, @debug.Debug)
pub(all) struct Frame {
  index : Int64
  time : Double
  items : ReadOnlyArray[@mobject.DrawItem]
}

///|
/// A synchronous sink provides natural backpressure to the scene runner.
pub(open) trait Renderer {
  fn render(Self, Frame) -> Unit raise
}

///|
pub struct Camera2D {
  pixel_width : Int32
  pixel_height : Int32
  frame_width : Double
  frame_height : Double
  center : @math.Vec3
  background : @mobject.Color
}

///|
/// Square pixels and aspect-preserving XY projection, with world +Y pointing up.
pub fn Camera2D::new(
  pixel_width~ : Int32 = 1280,
  pixel_height~ : Int32 = 720,
  frame_height~ : Double = 8.0,
  center~ : @math.Vec3 = @math.Vec3::zero(),
  background~ : @mobject.Color = @mobject.Color::black(),
) -> Camera2D raise @errors.EngineError {
  let frame_width = frame_height *
    pixel_width.to_double() /
    pixel_height.to_double()
  if pixel_width <= 0 ||
    pixel_height <= 0 ||
    !@math.finite(frame_height) ||
    frame_height <= 0.0 ||
    !@math.finite(frame_width) ||
    frame_width <= 0.0 ||
    !center.is_finite() {
    raise @errors.InvalidArgument("invalid camera dimensions or center")
  }
  { pixel_width, pixel_height, frame_width, frame_height, center, background, }
}

///|
pub fn Camera2D::project(self : Camera2D, point : @math.Vec3) -> @math.Vec3 {
  {
    x: ((point.x - self.center.x) / self.frame_width + 0.5) *
    self.pixel_width.to_double(),
    y: (0.5 - (point.y - self.center.y) / self.frame_height) *
    self.pixel_height.to_double(),
    z: point.z,
  }
}
