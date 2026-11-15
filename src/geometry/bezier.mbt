///|
/// A cubic segment in world coordinates.
#derive(Eq, @debug.Debug)
pub(all) struct Cubic {
  p0 : @math.Vec3
  p1 : @math.Vec3
  p2 : @math.Vec3
  p3 : @math.Vec3
}

///|
/// Exact degree elevation of a line.
pub fn Cubic::line(start : @math.Vec3, end : @math.Vec3) -> Cubic {
  {
    p0: start,
    p1: start.lerp(end, 1.0 / 3.0),
    p2: start.lerp(end, 2.0 / 3.0),
    p3: end,
  }
}

///|
/// de Casteljau evaluation avoids expanding the cubic polynomial.
pub fn Cubic::point(self : Cubic, t : Double) -> @math.Vec3 {
  let a = self.p0.lerp(self.p1, t)
  let b = self.p1.lerp(self.p2, t)
  let c = self.p2.lerp(self.p3, t)
  a.lerp(b, t).lerp(b.lerp(c, t), t)
}

///|
/// Exact subdivision into curves parameterized over [0,t] and [t,1].
pub fn Cubic::split(self : Cubic, t : Double) -> (Cubic, Cubic) {
  let a = self.p0.lerp(self.p1, t)
  let b = self.p1.lerp(self.p2, t)
  let c = self.p2.lerp(self.p3, t)
  let d = a.lerp(b, t)
  let e = b.lerp(c, t)
  let mid = d.lerp(e, t)
  (
    { p0: self.p0, p1: a, p2: d, p3: mid, },
    { p0: mid, p1: e, p2: c, p3: self.p3, },
  )
}

///|
pub fn Cubic::transformed(self : Cubic, transform : @math.Affine2) -> Cubic {
  {
    p0: transform.apply(self.p0),
    p1: transform.apply(self.p1),
    p2: transform.apply(self.p2),
    p3: transform.apply(self.p3),
  }
}

///|
pub fn Cubic::lerp(self : Cubic, target : Cubic, alpha : Double) -> Cubic {
  {
    p0: self.p0.lerp(target.p0, alpha),
    p1: self.p1.lerp(target.p1, alpha),
    p2: self.p2.lerp(target.p2, alpha),
    p3: self.p3.lerp(target.p3, alpha),
  }
}

///|
pub fn Cubic::is_finite(self : Cubic) -> Bool {
  self.p0.is_finite() &&
  self.p1.is_finite() &&
  self.p2.is_finite() &&
  self.p3.is_finite()
}

///|
/// Exact curve over [start,end], reparameterized to [0,1].
/// A zero interval returns a point curve. Parameters must be finite and ordered.
pub fn Cubic::subsegment(
  self : Cubic,
  start : Double,
  end : Double,
) -> Cubic raise @errors.EngineError {
  validate_interval(start, end)
  if !self.is_finite() {
    raise @errors.InvalidArgument("curve coordinates must be finite")
  }
  cubic_portion(self, start, end)
}

///|
fn cubic_portion(curve : Cubic, start : Double, end : Double) -> Cubic {
  if start == 0.0 && end == 1.0 {
    return curve
  }
  if start == end {
    let p = curve.point(start)
    return { p0: p, p1: p, p2: p, p3: p, }
  }
  let (prefix, _) = curve.split(end)
  if start == 0.0 {
    return prefix
  }
  let (_, result) = prefix.split(start / end)
  result
}

///|
fn validate_interval(
  start : Double,
  end : Double,
) -> Unit raise @errors.EngineError {
  if !@math.finite(start) ||
    !@math.finite(end) ||
    start < 0.0 ||
    end > 1.0 ||
    start > end {
    raise @errors.InvalidArgument(
      "expected a finite interval 0 <= start <= end <= 1",
    )
  }
}
