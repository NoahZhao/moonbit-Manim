///|
/// Closed polygon in the supplied vertex order. Vertices are copied into cubics.
pub fn polygon(vertices : Array[@math.Vec3]) -> Path raise @errors.EngineError {
  if vertices.length() < 3 || vertices.any(p => !p.is_finite()) {
    raise @errors.InvalidArgument(
      "a polygon needs at least three finite vertices",
    )
  }
  let segments : Array[Cubic] = []
  for i in 0..<vertices.length() {
    segments.push(
      Cubic::line(vertices[i], vertices[(i + 1) % vertices.length()]),
    )
  }
  Path::new([Contour::new(segments, closed=true)])
}

///|
pub fn rectangle(
  width : Double,
  height : Double,
) -> Path raise @errors.EngineError {
  if !@math.finite(width) ||
    !@math.finite(height) ||
    width <= 0.0 ||
    height <= 0.0 {
    raise @errors.InvalidArgument(
      "rectangle dimensions must be finite and positive",
    )
  }
  polygon([
    @math.Vec3::new(-width / 2.0, -height / 2.0),
    @math.Vec3::new(width / 2.0, -height / 2.0),
    @math.Vec3::new(width / 2.0, height / 2.0),
    @math.Vec3::new(-width / 2.0, height / 2.0),
  ])
}

///|
/// Open shaft and two independent arrowhead contours; no artificial connectors.
pub fn arrow(
  start : @math.Vec3,
  end : @math.Vec3,
  tip_length~ : Double = 0.18,
) -> Path raise @errors.EngineError {
  let delta = end.sub(start)
  if !start.is_finite() ||
    !end.is_finite() ||
    start.z != 0.0 ||
    end.z != 0.0 ||
    !@math.finite(tip_length) ||
    tip_length <= 0.0 ||
    delta.length() == 0.0 {
    raise @errors.InvalidArgument(
      "arrow requires distinct finite XY endpoints and a positive tip",
    )
  }
  let size = tip_length.min(delta.length() * 0.3)
  let direction = delta.normalized()
  let base = end.sub(direction.scale(size))
  let side = @math.Vec3::new(-direction.y, direction.x).scale(size * 0.48)
  Path::new([
    Contour::new([Cubic::line(start, end)]),
    Contour::new([
      Cubic::line(base.add(side), end),
      Cubic::line(end, base.sub(side)),
    ]),
  ])
}
