///|
test "rational frame time does not accumulate floating-point deltas" {
  let rate = @timeline.FrameRate::new(30000, denominator=1001)
  @test.assert_eq(rate.time(30000L), 1001.0)
  @test.assert_eq(rate.frame_count(1001.0), 30000L)
  @test.assert_eq(
    @timeline.FrameRate::new(60, denominator=2),
    @timeline.FrameRate::new(30),
  )
}

///|
test "frame counts exclude duplicate endpoints and tolerate boundary roundoff" {
  let rate = @timeline.FrameRate::new(25)
  @test.assert_eq(rate.frame_count(0.28), 7L)
  @test.assert_eq(rate.frame_count(0.0), 0L)
  @test.assert_eq(rate.frame_count(0.001), 1L)
  @test.assert_eq(rate.frame_count(1.01), 26L)
  @test.assert_raise(() => rate.frame_count(-1.0))
  @test.assert_raise(() => rate.frame_count(0.0 / 0.0))
  @test.assert_raise(() => @timeline.FrameRate::new(0))
  @test.assert_raise(() => @timeline.FrameRate::new(30, denominator=0))
}
