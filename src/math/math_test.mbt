///|
test "vector algebra and normalization" {
  let x = @math.Vec3::new(1.0, 0.0)
  let y = @math.Vec3::new(0.0, 1.0)
  @test.assert_eq(x.dot(y), 0.0)
  @test.assert_eq(x.cross(y), @math.Vec3::new(0.0, 0.0, z=1.0))
  let n = @math.Vec3::new(3.0, 4.0).normalized()
  @test.assert_eq(n.near(@math.Vec3::new(0.6, 0.8)), true)
  @test.assert_raise(() => @math.Vec3::zero().normalized())
}

///|
test "affine composition order and inverse" {
  let transform = @math.Affine2::translation(3.0, -2.0)
    .compose(@math.Affine2::rotation(0.73))
    .compose(@math.Affine2::scaling(2.0, 0.5))
  let point = @math.Vec3::new(-1.2, 4.1, z=3.0)
  @test.assert_eq(
    transform.inverse().apply(transform.apply(point)).near(point),
    true,
  )
  let translated = @math.Affine2::translation(2.0, 0.0)
    .compose(@math.Affine2::scaling(3.0, 3.0))
    .apply(@math.Vec3::new(1.0, 0.0))
  @test.assert_eq(translated, @math.Vec3::new(5.0, 0.0))
}

///|
test "singular affine transforms cannot be inverted" {
  @test.assert_raise(() => @math.Affine2::scaling(0.0, 1.0).inverse())
}

///|
test "vector interpolation has exact endpoints" {
  let a = @math.Vec3::new(2.0, -5.0)
  let b = @math.Vec3::new(-1.0, 6.0)
  @test.assert_eq(a.lerp(b, 0.0), a)
  @test.assert_eq(a.lerp(b, 1.0), b)
}

///|
test "normalization handles very large and subnormal finite vectors" {
  @test.assert_eq(
    @math.Vec3::new(1.0e308, 1.0e308).normalized().length().is_close(1.0),
    true,
  )
  @test.assert_eq(
    @math.Vec3::new(1.0e-320, 0.0).normalized(),
    @math.Vec3::new(1.0, 0.0),
  )
  @test.assert_raise(() => @math.Vec3::new(1.0 / 0.0, 0.0).normalized())
}
