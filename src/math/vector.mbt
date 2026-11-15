///|
/// Double precision world coordinates. The initial drawing pipeline projects onto XY.
#derive(Eq, @debug.Debug)
pub(all) struct Vec3 {
  x : Double
  y : Double
  z : Double
}

///|
pub fn Vec3::new(x : Double, y : Double, z~ : Double = 0.0) -> Vec3 {
  { x, y, z, }
}

///|
pub fn Vec3::zero() -> Vec3 {
  { x: 0.0, y: 0.0, z: 0.0, }
}

///|
pub fn Vec3::add(self : Vec3, other : Vec3) -> Vec3 {
  { x: self.x + other.x, y: self.y + other.y, z: self.z + other.z, }
}

///|
pub fn Vec3::sub(self : Vec3, other : Vec3) -> Vec3 {
  { x: self.x - other.x, y: self.y - other.y, z: self.z - other.z, }
}

///|
pub fn Vec3::scale(self : Vec3, factor : Double) -> Vec3 {
  { x: self.x * factor, y: self.y * factor, z: self.z * factor, }
}

///|
pub fn Vec3::dot(self : Vec3, other : Vec3) -> Double {
  self.x * other.x + self.y * other.y + self.z * other.z
}

///|
pub fn Vec3::cross(self : Vec3, other : Vec3) -> Vec3 {
  {
    x: self.y * other.z - self.z * other.y,
    y: self.z * other.x - self.x * other.z,
    z: self.x * other.y - self.y * other.x,
  }
}

///|
pub fn Vec3::length(self : Vec3) -> Double {
  @scalar.hypot(@scalar.hypot(self.x, self.y), self.z)
}

///|
pub fn Vec3::normalized(self : Vec3) -> Vec3 raise @errors.EngineError {
  let scale = self.x.abs().max(self.y.abs()).max(self.z.abs())
  if !self.is_finite() || scale == 0.0 {
    raise @errors.InvalidArgument(
      "cannot normalize a zero or non-finite vector",
    )
  }
  let scaled : Vec3 = {
    x: self.x / scale,
    y: self.y / scale,
    z: self.z / scale,
  }
  scaled.scale(1.0 / scaled.length())
}

///|
/// Endpoints are returned exactly; alpha is not clamped to allow explicit extrapolation.
pub fn Vec3::lerp(self : Vec3, other : Vec3, alpha : Double) -> Vec3 {
  if alpha == 0.0 {
    self
  } else if alpha == 1.0 {
    other
  } else {
    self.scale(1.0 - alpha).add(other.scale(alpha))
  }
}

///|
pub fn Vec3::is_finite(self : Vec3) -> Bool {
  finite(self.x) && finite(self.y) && finite(self.z)
}

///|
pub fn Vec3::near(
  self : Vec3,
  other : Vec3,
  tolerance~ : Double = 1.0e-9,
) -> Bool {
  self.sub(other).length() <= tolerance
}

///|
pub fn finite(value : Double) -> Bool {
  !value.is_nan() && !value.is_inf()
}

///|
pub fn clamp01(value : Double) -> Double {
  value.max(0.0).min(1.0)
}
