///|
/// Column-vector affine transform: (x,y) -> (a*x+c*y+tx, b*x+d*y+ty).
#derive(Eq, @debug.Debug)
pub(all) struct Affine2 {
  a : Double
  b : Double
  c : Double
  d : Double
  tx : Double
  ty : Double
}

///|
pub fn Affine2::identity() -> Affine2 {
  { a: 1.0, b: 0.0, c: 0.0, d: 1.0, tx: 0.0, ty: 0.0, }
}

///|
pub fn Affine2::translation(x : Double, y : Double) -> Affine2 {
  { ..Affine2::identity(), tx: x, ty: y, }
}

///|
pub fn Affine2::scaling(x : Double, y : Double) -> Affine2 {
  { a: x, b: 0.0, c: 0.0, d: y, tx: 0.0, ty: 0.0, }
}

///|
pub fn Affine2::rotation(radians : Double) -> Affine2 {
  let c = @scalar.cos(radians)
  let s = @scalar.sin(radians)
  { a: c, b: s, c: -s, d: c, tx: 0.0, ty: 0.0, }
}

///|
pub fn Affine2::apply(self : Affine2, point : Vec3) -> Vec3 {
  {
    x: self.a * point.x + self.c * point.y + self.tx,
    y: self.b * point.x + self.d * point.y + self.ty,
    z: point.z,
  }
}

///|
/// Composition self * other: apply other first, then self.
pub fn Affine2::compose(self : Affine2, other : Affine2) -> Affine2 {
  {
    a: self.a * other.a + self.c * other.b,
    b: self.b * other.a + self.d * other.b,
    c: self.a * other.c + self.c * other.d,
    d: self.b * other.c + self.d * other.d,
    tx: self.a * other.tx + self.c * other.ty + self.tx,
    ty: self.b * other.tx + self.d * other.ty + self.ty,
  }
}

///|
pub fn Affine2::inverse(self : Affine2) -> Affine2 raise @errors.EngineError {
  let det = self.a * self.d - self.b * self.c
  if !self.is_finite() || !finite(det) || det == 0.0 {
    raise @errors.InvalidArgument("affine transform is singular or non-finite")
  }
  let result : Affine2 = {
    a: self.d / det,
    b: -self.b / det,
    c: -self.c / det,
    d: self.a / det,
    tx: (self.c * self.ty - self.d * self.tx) / det,
    ty: (self.b * self.tx - self.a * self.ty) / det,
  }
  if !result.is_finite() {
    raise @errors.InvalidArgument("affine inverse exceeds finite precision")
  }
  result
}

///|
pub fn Affine2::is_finite(self : Affine2) -> Bool {
  finite(self.a) &&
  finite(self.b) &&
  finite(self.c) &&
  finite(self.d) &&
  finite(self.tx) &&
  finite(self.ty)
}
