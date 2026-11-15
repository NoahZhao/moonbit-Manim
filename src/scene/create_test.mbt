///|
priv struct CreateRecorder {
  frames : Array[@render.Frame]
}

///|
impl @render.Renderer for CreateRecorder with fn render(self, frame) {
  self.frames.push(frame)
}

///|
test "Create streams equal-distance frames and restores exact geometry and fill" {
  let recorder : CreateRecorder = { frames: [], }
  let scene = @scene.Scene::new(
    recorder,
    frame_rate=@timeline.FrameRate::new(4),
  )
  let origin = @math.Vec3::zero()
  let path = @geometry.Path::new([
    @geometry.Contour::new([
      { p0: origin, p1: origin, p2: origin, p3: @math.Vec3::new(8.0, 0.0), },
    ]),
  ])
  let state = @mobject.ObjectState::shape(path, style={
    ..@mobject.Style::default(),
    fill_opacity: 0.3,
  })
  let id = scene.add(state)
  scene.play([@animation.create(id, easing=Linear)], duration=1.0)
  @test.assert_eq(recorder.frames.length(), 4)
  @test.assert_eq(recorder.frames[0].items[0].path.segment_count(), 0)
  for i in 1..<4 {
    let item = recorder.frames[i].items[0]
    let end = item.path.contours()[0].segments()[0].p3
    @test.assert_eq(end.near(@math.Vec3::new(i.to_double() * 2.0, 0.0)), true)
    @test.assert_eq(item.id, id)
    @test.assert_eq(item.style.fill_opacity, 0.0)
  }
  @test.assert_eq(scene.get(id), state)
  scene.wait(0.25)
  @test.assert_eq(recorder.frames[4].items[0].path, path)
  @test.assert_eq(recorder.frames[4].items[0].style.fill_opacity, 0.3)
  // Previously delivered snapshots remain partial and unfilled.
  @test.assert_eq(recorder.frames[1].items[0].style.fill_opacity, 0.0)
}

///|
test "zero-duration Create commits the existing object without extra frames" {
  let recorder : CreateRecorder = { frames: [], }
  let scene = @scene.Scene::new(recorder)
  let state = @mobject.ObjectState::shape(@geometry.circle(1.0))
  let id = scene.add(state)
  scene.play([@animation.create(id)], duration=0.0)
  @test.assert_eq(recorder.frames.length(), 0)
  @test.assert_eq(scene.get(id), state)
  @test.assert_eq(scene.contains(id), true)
}

///|
test "invalid Create preflight does not partially begin another animation" {
  let recorder : CreateRecorder = { frames: [], }
  let scene = @scene.Scene::new(recorder)
  let state = @mobject.ObjectState::shape(@geometry.square(2.0))
  let shape = scene.add(state)
  let group = scene.add(@mobject.ObjectState::group())
  @test.assert_raise(() => {
    scene.play(
      [@animation.fade_in(shape), @animation.create(group)],
      duration=1.0,
    )
  })
  @test.assert_eq(scene.get(shape), state)
  @test.assert_eq(recorder.frames.length(), 0)
  scene.wait(0.0)
}
