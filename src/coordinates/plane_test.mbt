///|
test "plane coordinates invert a rotated scaled translated coordinate frame" {
  let plane = @coordinates.NumberPlane::new(
    transform=@math.Affine2::translation(2.0, -1.0)
      .compose(@math.Affine2::rotation(0.7))
      .compose(@math.Affine2::scaling(2.0, 3.0)),
  )
  @test.assert_eq(
    plane.coordinates(plane.point(1.5, -2.0)).near(@math.Vec3::new(1.5, -2.0)),
    true,
  )
  let small = @coordinates.NumberPlane::new(
    x_min=-1.0,
    x_max=1.0,
    y_min=-1.0,
    y_max=1.0,
  )
  @test.assert_eq(small.grid().contours().length(), 6)
  @test.assert_eq(small.axes().contours().length(), 2)
  @test.assert_raise(() => small.grid(step=1.0e-12))
}

///|
test "plot never bridges explicit discontinuities or invalid samples" {
  let plane = @coordinates.NumberPlane::new(
    x_min=-1.0,
    x_max=1.0,
    y_min=-2.0,
    y_max=2.0,
  )
  let separated = plane.plot(
    x => Some(if x < 0.0 { -1.0 } else { 1.0 }),
    samples=6,
    breaks=[0.0],
  )
  @test.assert_eq(separated.contours().length(), 2)
  for contour in separated.contours() {
    for c in contour.segments() {
      @test.assert_eq(c.p0.y, c.p3.y)
    }
  }
  let missing = plane.plot(
    x => if x.abs() < 0.3 { None } else { Some(x) },
    samples=9,
  )
  @test.assert_eq(missing.contours().length(), 2)
}
