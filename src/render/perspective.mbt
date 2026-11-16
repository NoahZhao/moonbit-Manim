///|
/// A backend-neutral perspective camera for 3D scene preparation.
/// It keeps the result in Vec3 so callers can use the rotated z value for
/// depth sorting or lighting before handing the x/y coordinates to Camera2D.
pub(all) struct Perspective3D {
  camera_distance : Double
  focal_length : Double
  yaw : Double
  pitch : Double
}

///|
pub fn Perspective3D::new(
  camera_distance~ : Double = 7.0,
  focal_length~ : Double = 4.1,
  yaw~ : Double = 0.0,
  pitch~ : Double = 0.0,
) -> Self raise @errors.EngineError {
  if !@math.finite(camera_distance) ||
    camera_distance <= 0.0 ||
    !@math.finite(focal_length) ||
    focal_length <= 0.0 ||
    !@math.finite(yaw) ||
    !@math.finite(pitch) {
    raise @errors.InvalidArgument("invalid perspective camera parameters")
  }
  { camera_distance, focal_length, yaw, pitch, }
}

///|
/// Rotate a world-space point into camera space without projecting it.
pub fn Perspective3D::rotate(self : Self, point : @math.Vec3) -> @math.Vec3 {
  let cy = @scalar.cos(self.yaw)
  let sy = @scalar.sin(self.yaw)
  let cp = @scalar.cos(self.pitch)
  let sp = @scalar.sin(self.pitch)
  let x = cy * point.x + sy * point.z
  let z = -sy * point.x + cy * point.z
  { x, y: cp * point.y - sp * z, z: sp * point.y + cp * z, }
}

///|
/// Project a world-space point and preserve camera-space depth in z.
pub fn Perspective3D::project(self : Self, point : @math.Vec3) -> @math.Vec3 {
  self.project_rotated(self.rotate(point))
}

///|
/// Project a point that has already been rotated into camera space.
pub fn Perspective3D::project_rotated(
  self : Self,
  point : @math.Vec3,
) -> @math.Vec3 {
  let depth = (self.camera_distance - point.z).max(0.75)
  let scale = self.focal_length / depth
  @math.Vec3::new(point.x * scale, point.y * scale, z=point.z)
}
