///|
test "geometry is independent of seek order and manual exploration" {
  let model = @tangent.Tangent::new()
  let retained = model.at(2.5).stringify()
  for time in [12.0, 0.0, 7.3, 1.0, 4.0] {
    ignore(model.at(time))
  }
  ignore(model.manual(3.0, 2.0))
  ignore(model.manual(-3.0, 0.0))
  @test.assert_eq(model.at(2.5).stringify(), retained)
  @test.assert_eq(@tangent.Tangent::new().at(2.5).stringify(), retained)
}

///|
test "tangent timeline and exploration have stable exact limits" {
  let model = @tangent.Tangent::new()
  @test.assert_eq(model.lesson.duration, model.narration.duration)
  @test.assert_eq(
    model.lesson.sample(model.narration.bookmark("travel")).get("h"),
    0.0,
  )
  @test.assert_eq(
    model.lesson.sample(model.narration.bookmark("return")).get("x"),
    2.6,
  )
  @test.assert_eq(
    model.lesson.sample(model.lesson.duration).get("h").abs() < 1.0e-12,
    true,
  )
  let picture = model.manual(0.0, 0.0).stringify()
  @test.assert_eq(picture.contains("NaN"), false)
  @test.assert_eq(picture.contains("Infinity"), false)
  @test.assert_raise(() => model.manual(0.0, -1.0))
}
