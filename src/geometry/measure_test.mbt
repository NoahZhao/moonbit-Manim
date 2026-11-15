///|
test "subsegment preserves the original curve under reparameterization" {
  let curve : @geometry.Cubic = {
    p0: @math.Vec3::new(-2.0, 1.0),
    p1: @math.Vec3::new(0.0, 4.0),
    p2: @math.Vec3::new(2.0, -3.0),
    p3: @math.Vec3::new(4.0, 2.0),
  }
  let part = curve.subsegment(0.23, 0.89)
  for i in 0..<21 {
    let t = i.to_double() / 20.0
    @test.assert_eq(part.point(t).near(curve.point(0.23 + 0.66 * t)), true)
  }
  @test.assert_eq(curve.subsegment(0.0, 1.0), curve)
  let point = curve.subsegment(0.4, 0.4)
  @test.assert_eq(point.p0, curve.point(0.4))
  @test.assert_eq(point.p0, point.p3)
  @test.assert_raise(() => curve.subsegment(-0.1, 0.5))
  @test.assert_raise(() => curve.subsegment(0.6, 0.5))
  @test.assert_raise(() => curve.subsegment(0.0, 1.1))
}

///|
test "arc inversion handles a straight curve with cubic parameter speed" {
  let origin = @math.Vec3::zero()
  let curve : @geometry.Cubic = {
    p0: origin,
    p1: origin,
    p2: origin,
    p3: @math.Vec3::new(8.0, 0.0),
  }
  let path = @geometry.Path::new([@geometry.Contour::new([curve])])
  let measure = path.measure()
  @test.assert_eq(measure.length, 8.0)
  @test.assert_eq(curve.point(0.5).x, 1.0)
  @test.assert_eq(
    measure.point_at(0.5).unwrap().near(@math.Vec3::new(4.0, 0.0)),
    true,
  )
  @test.assert_eq(
    measure.point_at(0.25).unwrap().near(@math.Vec3::new(2.0, 0.0)),
    true,
  )
  let half = measure.partial(0.0, 0.5)
  @test.assert_eq(
    half.contours()[0].segments()[0].p3.near(@math.Vec3::new(4.0, 0.0)),
    true,
  )
}

///|
/// Independent analytic arc length of p(t)=(t,t^2).
fn parabola_length(t : Double) -> Double {
  0.5 * t * (1.0 + 4.0 * t * t).sqrt() + @scalar.asinh(2.0 * t) * 0.25
}

///|
test "adaptive length and inverse agree with analytic parabola arc length" {
  let path = @geometry.Path::new([
    @geometry.Contour::new([
      {
        p0: @math.Vec3::zero(),
        p1: @math.Vec3::new(1.0 / 3.0, 0.0),
        p2: @math.Vec3::new(2.0 / 3.0, 1.0 / 3.0),
        p3: @math.Vec3::new(1.0, 1.0),
      },
    ]),
  ])
  let measure = path.measure(tolerance=1.0e-8)
  let exact = parabola_length(1.0)
  @test.assert_eq((measure.length - exact).abs() < 1.0e-8, true)
  @test.assert_eq(measure.uncertainty <= 1.0e-8, true)
  for i in 1..<10 {
    let fraction = i.to_double() / 10.0
    let point = measure.point_at(fraction).unwrap()
    @test.assert_eq((point.y - point.x * point.x).abs() < 1.0e-12, true)
    @test.assert_eq(
      (parabola_length(point.x) - exact * fraction).abs() < 3.0e-8,
      true,
    )
  }
}

///|
test "unequal segments and metric scaling use distance rather than segment count" {
  let origin = @math.Vec3::zero()
  let corner = @math.Vec3::new(1.0, 0.0)
  let end = @math.Vec3::new(1.0, 3.0)
  let path = @geometry.Path::new([
    @geometry.Contour::new([
      @geometry.Cubic::line(origin, corner),
      @geometry.Cubic::line(corner, end),
    ]),
  ])
  let measure = path.measure()
  @test.assert_eq(measure.length.is_close(4.0), true)
  @test.assert_eq(
    measure.point_at(0.5).unwrap().near(@math.Vec3::new(1.0, 1.0)),
    true,
  )
  let scaled = path.measure(metric_transform=@math.Affine2::scaling(10.0, 1.0))
  @test.assert_eq(scaled.length.is_close(13.0), true)
  @test.assert_eq(
    scaled.point_at(0.5).unwrap().near(@math.Vec3::new(0.65, 0.0)),
    true,
  )
  @test.assert_eq(scaled.partial(0.0, 1.0), path)
}

///|
test "pen-up boundaries do not introduce connectors" {
  let a = @geometry.line(@math.Vec3::zero(), @math.Vec3::new(1.0, 0.0))
  let b = @geometry.line(@math.Vec3::new(10.0, 0.0), @math.Vec3::new(13.0, 0.0))
  let path = @geometry.Path::new([a.contours()[0], b.contours()[0]])
  let measure = path.measure()
  @test.assert_eq(measure.length.is_close(4.0), true)
  @test.assert_eq(measure.point_at(0.25).unwrap(), @math.Vec3::new(10.0, 0.0))
  let prefix = measure.partial(0.0, 0.25)
  let suffix = measure.partial(0.25, 1.0)
  @test.assert_eq(prefix.contours().length(), 1)
  @test.assert_eq(suffix.contours().length(), 1)
  @test.assert_eq(
    prefix.contours()[0].segments()[0].p3,
    @math.Vec3::new(1.0, 0.0),
  )
  @test.assert_eq(
    suffix.contours()[0].segments()[0].p0,
    @math.Vec3::new(10.0, 0.0),
  )
  let middle = measure.partial(0.125, 0.75)
  @test.assert_eq(middle.contours().length(), 2)
  @test.assert_eq(
    middle.contours()[0].segments()[0].p0.near(@math.Vec3::new(0.5, 0.0)),
    true,
  )
  @test.assert_eq(
    middle.contours()[1].segments()[0].p3.near(@math.Vec3::new(12.0, 0.0)),
    true,
  )
}

///|
test "partial contours retain closure only when selected in full" {
  let square = @geometry.square(2.0)
  let measure = square.measure()
  @test.assert_eq(measure.partial(0.0, 1.0), square)
  @test.assert_eq(measure.partial(0.0, 0.5).contours()[0].closed, false)
  @test.assert_eq(measure.partial(0.5, 0.5).segment_count(), 0)
  let pair = @geometry.Path::new([square.contours()[0], square.contours()[0]])
  let first = pair.measure().partial(0.0, 0.5)
  @test.assert_eq(first.contours().length(), 1)
  @test.assert_eq(first.contours()[0].closed, true)
  @test.assert_eq(first, square)
}

///|
test "empty and degenerate paths have explicit sampling behavior" {
  let empty = @geometry.Path::new([]).measure()
  @test.assert_eq(empty.length, 0.0)
  @test.assert_eq(empty.point_at(0.5), None)
  @test.assert_eq(empty.partial(0.0, 1.0).segment_count(), 0)
  let a = @geometry.line(@math.Vec3::new(2.0, 3.0), @math.Vec3::new(2.0, 3.0))
  let b = @geometry.line(@math.Vec3::new(5.0, 6.0), @math.Vec3::new(5.0, 6.0))
  let path = @geometry.Path::new([a.contours()[0], b.contours()[0]])
  let zero = path.measure()
  @test.assert_eq(zero.length, 0.0)
  @test.assert_eq(zero.point_at(0.5), Some(@math.Vec3::new(2.0, 3.0)))
  @test.assert_eq(zero.point_at(1.0), Some(@math.Vec3::new(5.0, 6.0)))
  @test.assert_eq(zero.partial(0.2, 0.8).segment_count(), 0)
  @test.assert_eq(zero.partial(0.0, 1.0), path)
}

///|
test "retracing curves have nonzero arc length even when endpoints coincide" {
  let origin = @math.Vec3::zero()
  let path = @geometry.Path::new([
    @geometry.Contour::new([
      {
        p0: origin,
        p1: @math.Vec3::new(1.0, 0.0),
        p2: @math.Vec3::new(-1.0, 0.0),
        p3: origin,
      },
    ]),
  ])
  let measure = path.measure(tolerance=1.0e-7)
  @test.assert_eq((measure.length - 2.0 / 3.0.sqrt()).abs() < 1.0e-7, true)
  @test.assert_eq(
    measure.point_at(0.5).unwrap().near(origin, tolerance=1.0e-7),
    true,
  )
}

///|
test "invalid requests and exhausted length tolerance fail explicitly" {
  let path = @geometry.circle(1.0)
  @test.assert_raise(() => path.measure(tolerance=0.0))
  @test.assert_raise(() => path.measure(tolerance=1.0e-15, max_depth=1))
  @test.assert_raise(() => path.measure(max_depth=31))
  let measure = path.measure()
  @test.assert_raise(() => measure.point_at(0.0 / 0.0))
  @test.assert_raise(() => measure.partial(0.8, 0.2))
  @test.assert_raise(() => measure.partial(0.0, 1.1))
  let huge = @geometry.line(
    @math.Vec3::new(-1.0e308, 0.0),
    @math.Vec3::new(1.0e308, 0.0),
  )
  @test.assert_raise(() => huge.measure())
}
