///|
fn parameter() -> @lesson.Parameter {
  {
    key: "x",
    label: "x",
    initial: -2.0,
    min: -3.0,
    max: 3.0,
    step: 0.1,
    unit: "",
  }
}

///|
fn example() -> @lesson.Lesson raise {
  @lesson.Lesson::new([parameter()], [
    @lesson.cue("hold", "initial", 1.0),
    @lesson.cue("move", "linear", 2.0, targets=[
      @lesson.to("x", 2.0, easing=Linear),
    ]),
    @lesson.cue("return", "smooth", 1.0, targets=[@lesson.to("x", -2.0)]),
  ])
}

///|
test "absolute samples have exact boundaries and stable random access" {
  let lesson = example()
  @test.assert_eq(lesson.duration, 4.0)
  @test.assert_eq(lesson.sample(-10.0).get("x"), -2.0)
  @test.assert_eq(lesson.sample(1.0).chapter, 1)
  @test.assert_eq(lesson.sample(2.0).get("x"), 0.0)
  @test.assert_eq(lesson.sample(3.0).get("x"), 2.0)
  @test.assert_eq(lesson.sample(3.0).chapter, 2)
  @test.assert_eq(lesson.sample(3.5).get("x"), 0.0)
  @test.assert_eq(lesson.sample(99.0).get("x"), -2.0)
  @test.assert_eq(lesson.sample(99.0).progress, 1.0)
  for time in [3.9, 0.0, 2.0, 4.0, 1.0, 2.0] {
    ignore(lesson.sample(time))
  }
  @test.assert_eq(lesson.sample(2.0).get("x"), 0.0)
  @test.assert_raise(() => lesson.sample(0.0 / 0.0))
  @test.assert_raise(() => lesson.sample(1.0 / 0.0))
}

///|
test "lesson freezes declarations and retained samples" {
  let targets = [@lesson.to("x", 2.0, easing=Linear)]
  let parameters = [parameter()]
  let cues = [@lesson.cue("move", "linear", 2.0, targets~)]
  let lesson = @lesson.Lesson::new(parameters, cues)
  parameters.clear()
  targets.clear()
  cues.clear()
  let retained = lesson.sample(1.0)
  ignore(lesson.sample(2.0))
  @test.assert_eq(retained.get("x"), 0.0)
  @test.assert_eq(lesson.sample(2.0).get("x"), 2.0)
}

///|
test "exploration validates bounds and does not change playback" {
  let lesson = example()
  @test.assert_eq(lesson.explore([]).get("x"), -2.0)
  @test.assert_eq(lesson.explore([("x", 0.123)]).get("x"), 0.123)
  @test.assert_eq(lesson.explore([("x", 3.0)]).chapter, -1)
  @test.assert_eq(lesson.sample(2.0).get("x"), 0.0)
  for
    values in [
      [("x", 4.0)],
      [("unknown", 1.0)],
      [("x", 0.0), ("x", 1.0)],
      [("x", 0.0 / 0.0)],
    ] {
    @test.assert_raise(() => lesson.explore(values))
  }
  @test.assert_raise(() => lesson.sample(0.0).get("unknown"))
}

///|
test "invalid declarations fail before a lesson can be sampled" {
  let p = parameter()
  for
    parameters in [
      [],
      [p, p],
      [{ ..p, initial: 4.0, }],
      [{ ..p, step: 0.0, }],
      [{ ..p, max: p.min, }],
      [{ ..p, min: -1.0 / 0.0, }],
    ] {
    @test.assert_raise(() => {
      @lesson.Lesson::new(parameters, [@lesson.cue("a", "b", 1.0)])
    })
  }
  for
    cues in [
      [],
      [@lesson.cue("a", "b", 0.0)],
      [@lesson.cue("a", "b", 1.0 / 0.0)],
      [@lesson.cue("a", "b", 1.0, targets=[@lesson.to("unknown", 0.0)])],
      [
        @lesson.cue("a", "b", 1.0, targets=[
          @lesson.to("x", 0.0),
          @lesson.to("x", 1.0),
        ]),
      ],
      [@lesson.cue("a", "b", 1.0, targets=[@lesson.to("x", 4.0)])],
    ] {
    @test.assert_raise(() => @lesson.Lesson::new([p], cues))
  }
}
