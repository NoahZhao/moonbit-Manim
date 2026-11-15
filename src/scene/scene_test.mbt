///|
/// Test sinks retain frames so that later scene mutations can be checked for aliasing.
priv struct Recorder {
  frames : Array[@render.Frame]
}

///|
impl @render.Renderer for Recorder with fn render(self, frame) {
  self.frames.push(frame)
}

///|
test "play advances exact frame times and commits an unencoded exact endpoint" {
  let recorder : Recorder = { frames: [], }
  let scene = @scene.Scene::new(
    recorder,
    frame_rate=@timeline.FrameRate::new(4),
  )
  let state = @mobject.ObjectState::shape(@geometry.square(2.0))
  let id = scene.add(state)
  scene.play(
    [@animation.shift(id, @math.Vec3::new(2.0, 0.0), easing=Linear)],
    duration=1.0,
  )
  @test.assert_eq(recorder.frames.length(), 4)
  @test.assert_eq(recorder.frames[0].time, 0.0)
  @test.assert_eq(recorder.frames[3].time, 0.75)
  @test.assert_eq(recorder.frames[1].items[0].transform.tx, 0.5)
  @test.assert_eq(scene.get(id).transform.tx, 2.0)
  @test.assert_eq(scene.time(), 1.0)
  scene.wait(0.5)
  @test.assert_eq(recorder.frames.length(), 6)
  @test.assert_eq(recorder.frames[4].time, 1.0)
  @test.assert_eq(recorder.frames[0].items[0].transform.tx, 0.0)
  @test.assert_eq(scene.snapshot().index, 6L)
}

///|
test "sequential plays take new starting snapshots and preserve source identity" {
  let recorder : Recorder = { frames: [], }
  let scene = @scene.Scene::new(
    recorder,
    frame_rate=@timeline.FrameRate::new(2),
  )
  let id = scene.add(@mobject.ObjectState::shape(@geometry.square(2.0)))
  // Create both descriptors before playback to exercise lazy source capture.
  let first = @animation.shift(id, @math.Vec3::new(1.0, 0.0), easing=Linear)
  let second = @animation.shift(id, @math.Vec3::new(1.0, 0.0), easing=Linear)
  scene.play([first], duration=1.0)
  scene.play([second], duration=1.0)
  @test.assert_eq(recorder.frames[2].items[0].transform.tx, 1.0)
  @test.assert_eq(recorder.frames[3].items[0].transform.tx, 1.5)
  @test.assert_eq(scene.get(id).transform.tx, 2.0)
  @test.assert_eq(scene.contains(id), true)
}

///|
test "parallel animations share one clock and conflicts fail before mutation" {
  let recorder : Recorder = { frames: [], }
  let scene = @scene.Scene::new(
    recorder,
    frame_rate=@timeline.FrameRate::new(2),
  )
  let state = @mobject.ObjectState::shape(@geometry.square(2.0))
  let a = scene.add(state)
  let b = scene.add(state)
  scene.play(
    [
      @animation.shift(a, @math.Vec3::new(2.0, 0.0), easing=Linear),
      @animation.shift(b, @math.Vec3::new(-2.0, 0.0), easing=Linear),
    ],
    duration=1.0,
  )
  @test.assert_eq(recorder.frames.length(), 2)
  @test.assert_eq(recorder.frames[1].items[0].transform.tx, 1.0)
  @test.assert_eq(recorder.frames[1].items[1].transform.tx, -1.0)
  let before = scene.get(a)
  @test.assert_raise(() => {
    scene.play(
      [@animation.fade_out(a), @animation.rotate(a, 1.0)],
      duration=1.0,
    )
  })
  @test.assert_eq(scene.get(a), before)
  @test.assert_eq(recorder.frames.length(), 2)
  // A preflight error does not poison the scene.
  scene.wait(0.5)
  @test.assert_eq(recorder.frames.length(), 3)
}

///|
test "ancestor descendant conflicts and invalid later animations are atomic" {
  let recorder : Recorder = { frames: [], }
  let scene = @scene.Scene::new(recorder)
  let parent = scene.add(@mobject.ObjectState::group())
  let child = scene.add(@mobject.ObjectState::shape(@geometry.square(2.0)))
  scene.reparent(child, Some(parent))
  @test.assert_raise(() => {
    scene.play(
      [@animation.fade_out(parent), @animation.rotate(child, 1.0)],
      duration=1.0,
    )
  })
  let before = scene.get(child)
  @test.assert_raise(() => {
    scene.play(
      [
        @animation.fade_in(child),
        @animation.transform(parent, @mobject.ObjectState::group()),
      ],
      duration=1.0,
    )
  })
  @test.assert_eq(scene.get(child), before)
  @test.assert_eq(recorder.frames.length(), 0)
}

///|
test "zero duration finishes without frames and fade out removes subtrees" {
  let recorder : Recorder = { frames: [], }
  let scene = @scene.Scene::new(recorder)
  let parent = scene.add(@mobject.ObjectState::group())
  let child = scene.add(@mobject.ObjectState::shape(@geometry.circle(1.0)))
  scene.reparent(child, Some(parent))
  scene.play(
    [@animation.shift(parent, @math.Vec3::new(2.0, 0.0))],
    duration=0.0,
  )
  @test.assert_eq(scene.get(parent).transform.tx, 2.0)
  @test.assert_eq(recorder.frames.length(), 0)
  scene.play([@animation.fade_out(parent)], duration=0.0)
  @test.assert_eq(scene.contains(parent), false)
  @test.assert_eq(scene.contains(child), false)
  @test.assert_eq(scene.time(), 0.0)
}

///|
test "fractional frame durations quantize per play without duplicate frame indices" {
  let recorder : Recorder = { frames: [], }
  let scene = @scene.Scene::new(
    recorder,
    frame_rate=@timeline.FrameRate::new(4),
  )
  scene.wait(0.3)
  scene.wait(0.3)
  @test.assert_eq(recorder.frames.length(), 4)
  @test.assert_eq(scene.time(), 1.0)
  for i in 0..<recorder.frames.length() {
    @test.assert_eq(recorder.frames[i].index, i.to_int64())
  }
}

///|
test "fade in samples from zero opacity to the original opacity" {
  let recorder : Recorder = { frames: [], }
  let scene = @scene.Scene::new(
    recorder,
    frame_rate=@timeline.FrameRate::new(2),
  )
  let state = @mobject.ObjectState::shape(@geometry.circle(1.0), style={
    ..@mobject.Style::default(),
    opacity: 0.6,
  })
  let id = scene.add(state)
  scene.play([@animation.fade_in(id, easing=Linear)], duration=1.0)
  @test.assert_eq(recorder.frames[0].items[0].style.opacity, 0.0)
  @test.assert_eq(recorder.frames[1].items[0].style.opacity, 0.3)
  @test.assert_eq(scene.get(id), state)
}

///|
priv struct CallbackRenderer {
  callback : () -> Unit raise
}

///|
impl @render.Renderer for CallbackRenderer with fn render(self, _frame) {
  (self.callback)()
}

///|
test "renderer callbacks cannot mutate or reenter the active scene" {
  let holder : Array[@scene.Scene] = []
  let renderer : CallbackRenderer = {
    callback: () => {
      @test.assert_raise(() => holder[0].add(@mobject.ObjectState::group()))
      @test.assert_raise(() => holder[0].wait(0.0))
    },
  }
  let scene = @scene.Scene::new(
    renderer,
    frame_rate=@timeline.FrameRate::new(1),
  )
  holder.push(scene)
  scene.wait(1.0)
  // Busy guard is cleared on successful return.
  ignore(scene.add(@mobject.ObjectState::group()))
}

///|
test "renderer failure stops output and poisons the scene" {
  let renderer : CallbackRenderer = {
    callback: () => raise @errors.InvalidArgument("simulated sink failure"),
  }
  let scene = @scene.Scene::new(renderer)
  @test.assert_raise(() => scene.wait(1.0))
  @test.assert_eq(scene.frame_index(), 0L)
  let error = @test.expect_error(() => scene.wait(0.0))
  @test.assert_eq(error is @errors.SceneFailed, true)
}
