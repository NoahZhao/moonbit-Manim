///|
test "cubic bounds evaluate interior extrema in all three coordinates" {
  let curve : @geometry.Cubic = {
    p0: @math.Vec3::zero(),
    p1: @math.Vec3::new(1.0, 2.0, z=3.0),
    p2: @math.Vec3::new(2.0, 2.0, z=-3.0),
    p3: @math.Vec3::new(3.0, 0.0),
  }
  let bounds = curve.bounds()
  @test.assert_eq(bounds.min.x, 0.0)
  @test.assert_eq(bounds.max.x, 3.0)
  @test.assert_eq(bounds.max.y.is_close(1.5), true)
  @test.assert_eq(bounds.min.z.is_close(-3.0.sqrt() * 0.5), true)
  @test.assert_eq(bounds.max.z.is_close(3.0.sqrt() * 0.5), true)
  @test.assert_eq(bounds.center().near(@math.Vec3::new(1.5, 0.75)), true)
  for i in 0..<101 {
    @test.assert_eq(bounds.contains(curve.point(i.to_double() / 100.0)), true)
  }
}

///|
test "empty, constant and transformed paths have meaningful bounds" {
  @test.assert_eq(@geometry.Path::new([]).bounds(), None)
  let point = @math.Vec3::new(2.0, -3.0)
  let constant = @geometry.Cubic::line(point, point).bounds()
  @test.assert_eq(constant.min, point)
  @test.assert_eq(constant.max, point)
  let square = @geometry.square(2.0).transformed(
    @math.Affine2::translation(3.0, 4.0).compose(
      @math.Affine2::rotation(0.7853981633974483),
    ),
  )
  let bounds = square.bounds().unwrap()
  @test.assert_eq(
    bounds.min.near(@math.Vec3::new(3.0 - 2.0.sqrt(), 4.0 - 2.0.sqrt())),
    true,
  )
  @test.assert_eq(
    bounds.max.near(@math.Vec3::new(3.0 + 2.0.sqrt(), 4.0 + 2.0.sqrt())),
    true,
  )
}

///|
test "bounds tolerate huge finite coordinates without overflowing derivatives" {
  let curve : @geometry.Cubic = {
    p0: @math.Vec3::new(-1.0e308, 0.0),
    p1: @math.Vec3::new(1.0e308, 0.0),
    p2: @math.Vec3::new(-1.0e308, 0.0),
    p3: @math.Vec3::new(1.0e308, 0.0),
  }
  let bounds = curve.bounds()
  @test.assert_eq(bounds.min.x, -1.0e308)
  @test.assert_eq(bounds.max.x, 1.0e308)
  @test.assert_eq(bounds.center().is_finite(), true)
}
