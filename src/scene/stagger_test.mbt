///|
priv struct LagRecorder {
  frames : Array[@render.Frame]
}

///|
impl @render.Renderer for LagRecorder with fn render(self, frame) {
  self.frames.push(frame)
}

///|
test "stagger total duration includes delayed starts and exact endpoints" {
  let sink : LagRecorder = { frames: [], }
  let scene = @scene.Scene::new(sink, frame_rate=@timeline.FrameRate::new(4))
  let a = scene.add(@mobject.ObjectState::shape(@geometry.square(1.0)))
  let b = scene.add(@mobject.ObjectState::shape(@geometry.square(1.0)))
  scene.play_staggered(
    [
      @animation.shift(a, @math.Vec3::new(2.0, 0.0), easing=Linear),
      @animation.shift(b, @math.Vec3::new(2.0, 0.0), easing=Linear),
    ],
    duration=2.0,
    lag_ratio=1.0,
  )
  @test.assert_eq(sink.frames.length(), 8)
  @test.assert_eq(sink.frames[2].items[0].transform.tx, 1.0)
  @test.assert_eq(sink.frames[2].items[1].transform.tx, 0.0)
  @test.assert_eq(sink.frames[6].items[0].transform.tx, 2.0)
  @test.assert_eq(sink.frames[6].items[1].transform.tx, 1.0)
  @test.assert_eq(scene.get(a).transform.tx, 2.0)
  @test.assert_eq(scene.get(b).transform.tx, 2.0)
  @test.assert_eq(scene.time(), 2.0)
}

///|
test "stagger conflicts and invalid lag fail before any frame or mutation" {
  let sink : LagRecorder = { frames: [], }
  let scene = @scene.Scene::new(sink)
  let a = scene.add(@mobject.ObjectState::shape(@geometry.square(1.0)))
  let before = scene.get(a)
  @test.assert_raise(() => {
    scene.play_staggered([@animation.fade_out(a)], duration=1.0, lag_ratio=-1.0)
  })
  @test.assert_raise(() => {
    scene.play_staggered(
      [@animation.fade_out(a), @animation.shift(a, @math.Vec3::zero())],
      duration=1.0,
    )
  })
  @test.assert_eq(scene.get(a), before)
  @test.assert_eq(sink.frames.length(), 0)
  scene.play_staggered(
    [@animation.shift(a, @math.Vec3::new(3.0, 0.0))],
    duration=0.0,
  )
  @test.assert_eq(scene.get(a).transform.tx, 3.0)
  @test.assert_eq(sink.frames.length(), 0)
}
