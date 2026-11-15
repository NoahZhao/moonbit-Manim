///|
test "audio bookmarks, subtitles and random seeking share exact boundaries" {
  let speech : Array[@narration.Speech] = [
    @narration.speech("observe", "观察", beats=[
      @narration.beat("观察", rate=132.0),
    ]),
    @narration.speech("approach", "靠近", beats=[
      @narration.beat("靠近", rate=158.0),
    ]),
  ]
  let durations = [1.5, 2.25]
  let track = @narration.NarrationTrack::new(
    "lesson.m4a", "zh-CN", speech, durations,
  )
  durations[0] = 99.0
  speech.clear()
  @test.assert_eq(track.duration, 3.75)
  @test.assert_eq(track.bookmark("approach"), 1.5)
  @test.assert_eq(track.sample(1.499).key, "observe")
  @test.assert_eq(track.sample(1.5).key, "approach")
  @test.assert_eq(track.sample(-1.0).key, "observe")
  @test.assert_eq(track.sample(99.0).text, "靠近")
  @test.assert_eq(track.sample(0.2).text, "观察")
  @test.assert_raise(() => track.sample(0.0 / 0.0))
  @test.assert_raise(() => track.bookmark("missing"))
}

///|
test "narration rejects incomplete and ambiguous audio timing" {
  let a : @narration.Speech = @narration.speech("a", "a")
  for speech in [[], [a, a], [{ ..a, key: "", }], [{ ..a, text: "", }]] {
    @test.assert_raise(() => {
      @narration.NarrationTrack::new("audio", "en", speech, [1.0])
    })
  }
  @test.assert_raise(() => {
    @narration.NarrationTrack::new("audio", "en", [a, a], [1.0, 1.0])
  })
  for duration in [0.0, -1.0, 1.0 / 0.0] {
    @test.assert_raise(() => {
      @narration.NarrationTrack::new("audio", "en", [a], [duration])
    })
  }
}
