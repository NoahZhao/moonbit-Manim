///|
test "de Casteljau subdivision preserves the original curve" {
  let curve : @geometry.Cubic = {
    p0: @math.Vec3::new(0.0, 0.0),
    p1: @math.Vec3::new(1.0, 3.0),
    p2: @math.Vec3::new(2.0, -2.0),
    p3: @math.Vec3::new(4.0, 1.0),
  }
  let split = 0.37
  let (left, right) = curve.split(split)
  for i in 0..<21 {
    let t = i.to_double() / 20.0
    @test.assert_eq(left.point(t).near(curve.point(t * split)), true)
    @test.assert_eq(
      right.point(t).near(curve.point(split + t * (1.0 - split))),
      true,
    )
  }
  @test.assert_eq(left.p3, right.p0)
}

///|
test "path construction owns immutable copies" {
  let original = @geometry.Cubic::line(
    @math.Vec3::zero(),
    @math.Vec3::new(1.0, 0.0),
  )
  let segments = [original]
  let contour = @geometry.Contour::new(segments)
  let contours = [contour]
  let path = @geometry.Path::new(contours)
  segments[0] = @geometry.Cubic::line(
    @math.Vec3::zero(),
    @math.Vec3::new(99.0, 0.0),
  )
  contours.clear()
  @test.assert_eq(path.contours()[0].segments()[0], original)
}

///|
test "disconnected and falsely closed contours are rejected" {
  let a = @geometry.Cubic::line(@math.Vec3::zero(), @math.Vec3::new(1.0, 0.0))
  let b = @geometry.Cubic::line(
    @math.Vec3::new(2.0, 0.0),
    @math.Vec3::new(3.0, 0.0),
  )
  @test.assert_raise(() => @geometry.Contour::new([]))
  @test.assert_raise(() => @geometry.Contour::new([a, b]))
  @test.assert_raise(() => @geometry.Contour::new([a], closed=true))
}

///|
test "circle approximation stays within its advertised radial error" {
  let circle = @geometry.circle(2.0)
  for segment in circle.contours()[0].segments() {
    for i in 0..<101 {
      let radius = segment.point(i.to_double() / 100.0).length()
      @test.assert_eq((radius - 2.0).abs() < 0.000546, true)
    }
  }
  @test.assert_raise(() => @geometry.circle(0.0))
  @test.assert_raise(() => @geometry.square(-1.0))
}

///|
test "morph subdivides without changing either input or endpoint" {
  let source = @geometry.square(2.0)
  let target = @geometry.circle(1.0)
  let morph = @geometry.PathMorph::new(source, target)
  @test.assert_eq(morph.sample(0.0), source)
  @test.assert_eq(morph.sample(1.0), target)
  @test.assert_eq(morph.sample(0.5).segment_count(), 8)
  @test.assert_eq(source.segment_count(), 8)
  @test.assert_eq(target.segment_count(), 4)
  let midpoint = morph.sample(0.5)
  @test.assert_eq(morph.sample(0.2).is_finite(), true)
  @test.assert_eq(morph.sample(0.5), midpoint)
}

///|
test "identity morph retains the geometry of a subdivided straight path" {
  let a = @math.Vec3::zero()
  let b = @math.Vec3::new(3.0, 0.0)
  let long = @geometry.line(a, b)
  let split = @geometry.Path::new([
    @geometry.Contour::new([
      @geometry.Cubic::line(a, @math.Vec3::new(1.5, 0.0)),
      @geometry.Cubic::line(@math.Vec3::new(1.5, 0.0), b),
    ]),
  ])
  let middle = @geometry.PathMorph::new(long, split).sample(0.5)
  let segments = middle.contours()[0].segments()
  @test.assert_eq(segments.length(), 2)
  @test.assert_eq(segments[0].point(0.5).near(@math.Vec3::new(0.75, 0.0)), true)
  @test.assert_eq(segments[1].point(0.5).near(@math.Vec3::new(2.25, 0.0)), true)
}

///|
test "unsupported contour topology fails explicitly" {
  let shape = @geometry.square(2.0)
  let open = @geometry.line(@math.Vec3::zero(), @math.Vec3::new(1.0, 0.0))
  @test.assert_raise(() => @geometry.PathMorph::new(shape, open))
  @test.assert_raise(() => {
    @geometry.PathMorph::new(shape, @geometry.Path::new([]))
  })
}
