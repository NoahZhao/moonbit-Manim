///|
/// Counter-clockwise square, beginning on the positive X axis to match circle().
pub fn square(size : Double) -> Path raise @errors.EngineError {
  if !@math.finite(size) || size <= 0.0 {
    raise @errors.InvalidArgument("square size must be finite and positive")
  }
  let h = size / 2.0
  let points = [
    @math.Vec3::new(h, 0.0),
    @math.Vec3::new(h, h),
    @math.Vec3::new(0.0, h),
    @math.Vec3::new(-h, h),
    @math.Vec3::new(-h, 0.0),
    @math.Vec3::new(-h, -h),
    @math.Vec3::new(0.0, -h),
    @math.Vec3::new(h, -h),
    @math.Vec3::new(h, 0.0),
  ]
  let segments : Array[Cubic] = []
  for i in 0..<(points.length() - 1) {
    segments.push(Cubic::line(points[i], points[i + 1]))
  }
  Path::new([Contour::new(segments, closed=true)])
}

///|
/// Four cubic quarter arcs. Maximum radial approximation error is ~0.000273 * radius.
pub fn circle(radius : Double) -> Path raise @errors.EngineError {
  if !@math.finite(radius) || radius <= 0.0 {
    raise @errors.InvalidArgument("circle radius must be finite and positive")
  }
  let k = radius * 0.5522847498307936
  let r = radius
  let p = (x, y) => @math.Vec3::new(x, y)
  Path::new([
    Contour::new(
      [
        { p0: p(r, 0.0), p1: p(r, k), p2: p(k, r), p3: p(0.0, r), },
        { p0: p(0.0, r), p1: p(-k, r), p2: p(-r, k), p3: p(-r, 0.0), },
        { p0: p(-r, 0.0), p1: p(-r, -k), p2: p(-k, -r), p3: p(0.0, -r), },
        { p0: p(0.0, -r), p1: p(k, -r), p2: p(r, -k), p3: p(r, 0.0), },
      ],
      closed=true,
    ),
  ])
}

///|
pub fn line(
  start : @math.Vec3,
  end : @math.Vec3,
) -> Path raise @errors.EngineError {
  Path::new([Contour::new([Cubic::line(start, end)])])
}
