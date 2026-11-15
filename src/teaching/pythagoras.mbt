///|
/// Two exact tilings of the same (a+b) square, using four congruent triangles.
/// Three translations rearrange the initial c² hole into a² and b² holes.
pub struct Pythagoras {
  a : Double
  b : Double
  c : Double
  side : Double
  triangles : ReadOnlyArray[@geometry.Path]
  offsets : ReadOnlyArray[@math.Vec3]
  c_square : @geometry.Path
  a_square : @geometry.Path
  b_square : @geometry.Path
}

///|
pub fn Pythagoras::new(
  a : Double,
  b : Double,
) -> Pythagoras raise @errors.EngineError {
  let side = a + b
  let c = (a * a + b * b).sqrt()
  if !@math.finite(a) ||
    !@math.finite(b) ||
    a <= 0.0 ||
    b <= 0.0 ||
    !@math.finite(side) ||
    !@math.finite(c) {
    raise @errors.InvalidArgument(
      "Pythagoras tiling requires finite positive representable side lengths",
    )
  }
  let p = (x, y) => @math.Vec3::new(x, y)
  {
    a,
    b,
    c,
    side,
    triangles: ReadOnlyArray::from_array([
      @geometry.polygon([p(0.0, 0.0), p(b, 0.0), p(0.0, a)]),
      @geometry.polygon([p(b, 0.0), p(side, 0.0), p(side, b)]),
      @geometry.polygon([p(side, b), p(side, side), p(a, side)]),
      @geometry.polygon([p(a, side), p(0.0, side), p(0.0, a)]),
    ]),
    offsets: ReadOnlyArray::from_array([
      p(a, 0.0),
      p(-b, a),
      p(0.0, -b),
      p(0.0, 0.0),
    ]),
    c_square: @geometry.polygon([p(b, 0.0), p(side, b), p(a, side), p(0.0, a)]),
    a_square: @geometry.polygon([p(0.0, 0.0), p(a, 0.0), p(a, a), p(0.0, a)]),
    b_square: @geometry.polygon([p(a, a), p(side, a), p(side, side), p(a, side)]),
  }
}
