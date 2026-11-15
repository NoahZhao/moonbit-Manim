///|
/// Finite coordinate window. Grid spacing and plots use mathematical units;
/// the affine map places the complete plane in scene coordinates.
pub struct NumberPlane {
  x_min : Double
  x_max : Double
  y_min : Double
  y_max : Double
  transform : @math.Affine2
}

///|
pub fn NumberPlane::new(
  x_min~ : Double = -6.0,
  x_max~ : Double = 6.0,
  y_min~ : Double = -3.0,
  y_max~ : Double = 3.0,
  transform~ : @math.Affine2 = @math.Affine2::identity(),
) -> NumberPlane raise @errors.EngineError {
  if !@math.finite(x_min) ||
    !@math.finite(x_max) ||
    !@math.finite(y_min) ||
    !@math.finite(y_max) ||
    x_min >= x_max ||
    y_min >= y_max ||
    !@math.finite(x_max - x_min) ||
    !@math.finite(y_max - y_min) ||
    !transform.is_finite() {
    raise @errors.InvalidArgument(
      "coordinate window must be finite and ordered",
    )
  }
  ignore(transform.inverse())
  { x_min, x_max, y_min, y_max, transform, }
}

///|
pub fn NumberPlane::point(
  self : NumberPlane,
  x : Double,
  y : Double,
) -> @math.Vec3 {
  self.transform.apply(@math.Vec3::new(x, y))
}

///|
pub fn NumberPlane::coordinates(
  self : NumberPlane,
  point : @math.Vec3,
) -> @math.Vec3 raise @errors.EngineError {
  if !point.is_finite() {
    raise @errors.InvalidArgument("point must be finite")
  }
  self.transform.inverse().apply(point)
}

///|
pub fn NumberPlane::grid(
  self : NumberPlane,
  step~ : Double = 1.0,
) -> @geometry.Path raise @errors.EngineError {
  if !@math.finite(step) ||
    step <= 0.0 ||
    (self.x_max - self.x_min) / step > 2048.0 ||
    (self.y_max - self.y_min) / step > 2048.0 {
    raise @errors.InvalidArgument(
      "grid step must be positive and yield at most 2049 lines per axis",
    )
  }
  let contours : Array[@geometry.Contour] = []
  let x0 = (self.x_min / step).ceil() * step
  let y0 = (self.y_min / step).ceil() * step
  let nx = ((self.x_max - x0) / step).floor().to_int() + 1
  let ny = ((self.y_max - y0) / step).floor().to_int() + 1
  for i in 0..<nx.max(0) {
    let x = x0 + i.to_double() * step
    contours.push(
      @geometry.Contour::new([
        @geometry.Cubic::line(
          self.point(x, self.y_min),
          self.point(x, self.y_max),
        ),
      ]),
    )
  }
  for i in 0..<ny.max(0) {
    let y = y0 + i.to_double() * step
    contours.push(
      @geometry.Contour::new([
        @geometry.Cubic::line(
          self.point(self.x_min, y),
          self.point(self.x_max, y),
        ),
      ]),
    )
  }
  @geometry.Path::new(contours)
}

///|
pub fn NumberPlane::axes(
  self : NumberPlane,
) -> @geometry.Path raise @errors.EngineError {
  let contours : Array[@geometry.Contour] = []
  if self.y_min <= 0.0 && self.y_max >= 0.0 {
    contours.push(
      @geometry.Contour::new([
        @geometry.Cubic::line(
          self.point(self.x_min, 0.0),
          self.point(self.x_max, 0.0),
        ),
      ]),
    )
  }
  if self.x_min <= 0.0 && self.x_max >= 0.0 {
    contours.push(
      @geometry.Contour::new([
        @geometry.Cubic::line(
          self.point(0.0, self.y_min),
          self.point(0.0, self.y_max),
        ),
      ]),
    )
  }
  @geometry.Path::new(contours)
}

///|
/// Uniform polyline sampler, with explicit discontinuities. None, non-finite
/// and out-of-window samples split contours. No claim of adaptive error bounds.
pub fn NumberPlane::plot(
  self : NumberPlane,
  function : (Double) -> Double?,
  samples~ : Int32 = 240,
  breaks~ : Array[Double] = [],
) -> @geometry.Path raise @errors.EngineError {
  if samples < 2 || samples > 65536 || breaks.any(x => !@math.finite(x)) {
    raise @errors.InvalidArgument(
      "plot requires 2..65536 samples and finite breaks",
    )
  }
  let contours : Array[@geometry.Contour] = []
  let mut segments : Array[@geometry.Cubic] = []
  let mut previous : @math.Vec3? = None
  let mut previous_x = self.x_min
  for i in 0..<samples {
    let x = self.x_min +
      (self.x_max - self.x_min) * i.to_double() / (samples - 1).to_double()
    let crosses = breaks.any(b => b > previous_x && b <= x) ||
      breaks.any(b => b == x)
    let y = function(x)
    let point = match y {
      Some(y) if @math.finite(y) && y >= self.y_min && y <= self.y_max =>
        Some(self.point(x, y))
      _ => None
    }
    if crosses || point is None {
      if !segments.is_empty() {
        contours.push(@geometry.Contour::new(segments))
        segments = []
      }
      previous = None
    }
    match (previous, point) {
      (Some(a), Some(b)) => segments.push(@geometry.Cubic::line(a, b))
      _ => ()
    }
    // A sample precisely on a declared discontinuity is omitted as well.
    previous = if breaks.any(b => b == x) { None } else { point }
    previous_x = x
  }
  if !segments.is_empty() {
    contours.push(@geometry.Contour::new(segments))
  }
  @geometry.Path::new(contours)
}
