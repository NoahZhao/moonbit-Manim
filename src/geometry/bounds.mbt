///|
/// Tight axis-aligned bounds in the coordinates of the measured path.
#derive(Eq, @debug.Debug)
pub struct Bounds3 {
  min : @math.Vec3
  max : @math.Vec3
}

///|
pub fn Bounds3::union(self : Bounds3, other : Bounds3) -> Bounds3 {
  {
    min: {
      x: self.min.x.min(other.min.x),
      y: self.min.y.min(other.min.y),
      z: self.min.z.min(other.min.z),
    },
    max: {
      x: self.max.x.max(other.max.x),
      y: self.max.y.max(other.max.y),
      z: self.max.z.max(other.max.z),
    },
  }
}

///|
pub fn Bounds3::center(self : Bounds3) -> @math.Vec3 {
  self.min.scale(0.5).add(self.max.scale(0.5))
}

///|
pub fn Bounds3::contains(self : Bounds3, point : @math.Vec3) -> Bool {
  point.x >= self.min.x &&
  point.x <= self.max.x &&
  point.y >= self.min.y &&
  point.y <= self.max.y &&
  point.z >= self.min.z &&
  point.z <= self.max.z
}

///|
fn point_bounds(point : @math.Vec3) -> Bounds3 {
  { min: point, max: point, }
}

///|
/// Stable quadratic roots of the derivative. Scaling coordinates before taking
/// differences prevents overflow for otherwise finite control points.
fn extrema(p0 : Double, p1 : Double, p2 : Double, p3 : Double) -> Array[Double] {
  let scale = p0.abs().max(p1.abs()).max(p2.abs()).max(p3.abs())
  if scale == 0.0 {
    return []
  }
  let x0 = p0 / scale
  let x1 = p1 / scale
  let x2 = p2 / scale
  let x3 = p3 / scale
  let d0 = x1 - x0
  let d1 = x2 - x1
  let d2 = x3 - x2
  let a = d0 - 2.0 * d1 + d2
  let b = 2.0 * (d1 - d0)
  let c = d0
  if a == 0.0 {
    return if b == 0.0 { [] } else { [-c / b] }
  }
  let discriminant = b * b - 4.0 * a * c
  if discriminant < 0.0 {
    return []
  }
  let root = discriminant.sqrt()
  let q = -0.5 * (b + (if b < 0.0 { -root } else { root }))
  if q == 0.0 {
    [-b / (2.0 * a)]
  } else {
    [q / a, c / q]
  }
}

///|
/// Endpoints plus roots of dx/dt, dy/dt and dz/dt, rather than the control hull.
pub fn Cubic::bounds(self : Cubic) -> Bounds3 raise @errors.EngineError {
  if !self.is_finite() {
    raise @errors.InvalidArgument("curve coordinates must be finite")
  }
  let mut result = point_bounds(self.p0).union(point_bounds(self.p3))
  for
    roots in [
      extrema(self.p0.x, self.p1.x, self.p2.x, self.p3.x),
      extrema(self.p0.y, self.p1.y, self.p2.y, self.p3.y),
      extrema(self.p0.z, self.p1.z, self.p2.z, self.p3.z),
    ] {
    for t in roots {
      if t > 0.0 && t < 1.0 {
        result = result.union(point_bounds(self.point(t)))
      }
    }
  }
  result
}

///|
/// Empty paths have no bounds. Transform the path first to obtain world bounds.
pub fn Path::bounds(self : Path) -> Bounds3? raise @errors.EngineError {
  let mut result : Bounds3? = None
  for contour in self.contours() {
    for segment in contour.segments() {
      let bounds = segment.bounds()
      result = Some(
        match result {
          None => bounds
          Some(previous) => previous.union(bounds)
        },
      )
    }
  }
  result
}
