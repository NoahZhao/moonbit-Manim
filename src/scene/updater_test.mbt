///|
priv struct DynamicRecorder {
  frames : Array[@render.Frame]
}

///|
impl @render.Renderer for DynamicRecorder with fn render(self, frame) {
  self.frames.push(frame)
}

///|
fn dynamic_scene(fps~ : Int32 = 4) -> (@scene.Scene, DynamicRecorder) raise {
  let sink : DynamicRecorder = { frames: [], }
  (@scene.Scene::new(sink, frame_rate=@timeline.FrameRate::new(fps)), sink)
}

///|
fn dynamic_dot(scene : @scene.Scene) -> @mobject.ObjectId raise {
  scene.add(@mobject.ObjectState::shape(@geometry.circle(0.1)))
}

///|
test "trackers drive a parabola on the same clock as object animations" {
  let (scene, sink) = dynamic_scene()
  let x = scene.add_tracker(-2.0)
  let dot = dynamic_dot(scene)
  let independent = dynamic_dot(scene)
  scene.set_updater(
    dot,
    (context, state) => {
      let value = context.get_value(x)
      { ..state, transform: @math.Affine2::translation(value, value * value), }
    },
    trackers=[x],
  )
  // These descriptors must capture their initial values at actual playback time.
  let there = @scene.value_to(x, 2.0, easing=Linear)
  let back = @scene.value_to(x, 0.0, easing=Linear)
  scene.play(
    [@animation.shift(independent, @math.Vec3::new(4.0, 0.0), easing=Linear)],
    values=[there],
    duration=1.0,
  )
  for i in 0..<4 {
    let expected = i.to_double() - 2.0
    @test.assert_eq(sink.frames[i].items[0].transform.tx, expected)
    @test.assert_eq(sink.frames[i].items[0].transform.ty, expected * expected)
    @test.assert_eq(sink.frames[i].items[1].transform.tx, i.to_double())
  }
  @test.assert_eq(scene.get_value(x), 2.0)
  @test.assert_eq(scene.get(dot).transform.ty, 4.0)
  scene.play([], values=[back], duration=1.0)
  @test.assert_eq(sink.frames[5].items[0].transform.tx, 1.5)
  @test.assert_eq(scene.get_value(x), 0.0)
  @test.assert_eq(sink.frames[0].items[0].transform.tx, -2.0)
  @test.assert_eq(scene.contains(dot), true)
}

///|
test "wait and exact endpoints integrate quantized time without duplicate dt" {
  let (scene, sink) = dynamic_scene()
  let dot = dynamic_dot(scene)
  let times : Array[(Double, Double)] = []
  scene.set_updater(dot, (context, state) => {
    times.push((context.time, context.dt))
    {
      ..state,
      transform: @math.Affine2::translation(
        state.transform.tx + context.dt,
        0.0,
      ),
    }
  })
  scene.wait(0.3)
  @test.assert_eq(times, [(0.0, 0.0), (0.25, 0.25), (0.5, 0.25)])
  scene.wait(0.25)
  @test.assert_eq(times[3], (0.5, 0.0))
  @test.assert_eq(times[4], (0.75, 0.25))
  @test.assert_eq(scene.get(dot).transform.tx, 0.75)
  scene.wait(0.0)
  scene.update()
  @test.assert_eq(times[5], (0.75, 0.0))
  @test.assert_eq(times[6], (0.75, 0.0))
  @test.assert_eq(sink.frames.length(), 3)
  ignore(scene.snapshot())
  @test.assert_eq(times.length(), 7)
}

///|
test "dependency order uses current staged geometry and ancestor transforms" {
  let (scene, _) = dynamic_scene()
  let group = scene.add(@mobject.ObjectState::group())
  let dot = dynamic_dot(scene)
  scene.reparent(dot, Some(group))
  let follower = dynamic_dot(scene)
  let x = scene.add_tracker(3.0)
  let contexts : Array[@scene.UpdateContext] = []
  // Register in reverse order; reading dot implicitly depends on its group too.
  scene.set_updater(
    follower,
    (context, state) => {
      contexts.push(context)
      { ..state, transform: context.world_transform(dot), }
    },
    depends_on=[dot],
  )
  scene.set_updater(dot, (_context, state) => {
    ..state,
    transform: @math.Affine2::translation(1.0, 2.0),
  })
  scene.set_updater(
    group,
    (context, state) => {
      ..state,
      transform: @math.Affine2::translation(context.get_value(x), 0.0),
    },
    trackers=[x],
  )
  scene.update()
  @test.assert_eq(scene.get(follower).transform.tx, 4.0)
  @test.assert_eq(scene.get(follower).transform.ty, 2.0)
  scene.set_value(x, 5.0)
  scene.update()
  @test.assert_eq(scene.get(follower).transform.tx, 6.0)
  @test.assert_eq(contexts[0].world_transform(dot).tx, 4.0)
  @test.assert_eq(contexts[0].get(dot).transform.tx, 1.0)
}

///|
test "cycle rejection preserves the previous updater and hierarchy" {
  let (scene, sink) = dynamic_scene()
  let a = dynamic_dot(scene)
  let b = dynamic_dot(scene)
  scene.set_updater(a, (_context, state) => {
    ..state,
    transform: @math.Affine2::translation(1.0, 0.0),
  })
  scene.set_updater(
    b,
    (context, state) => { ..state, transform: context.get(a).transform, },
    depends_on=[a],
  )
  @test.assert_raise(() => {
    scene.set_updater(
      a,
      (context, state) => { ..state, transform: context.get(b).transform, },
      depends_on=[b],
    )
  })
  @test.assert_raise(() => scene.reparent(a, Some(b)))
  @test.assert_raise(() => {
    scene.set_updater(a, (_context, state) => state, depends_on=[a])
  })
  scene.update()
  @test.assert_eq(scene.get(b).transform.tx, 1.0)
  // A failed reparent did not place a under b (which would give world x=2).
  @test.assert_eq(scene.snapshot().items[0].transform.tx, 1.0)
  @test.assert_eq(sink.frames.length(), 0)
  scene.wait(0.25)
  @test.assert_eq(sink.frames.length(), 1)
}

///|
test "updater input arrays are copied and undeclared reads are rejected" {
  let (scene, _) = dynamic_scene()
  let source = dynamic_dot(scene)
  let target = dynamic_dot(scene)
  let tracker = scene.add_tracker(2.0)
  let dependencies = [source]
  let trackers = [tracker]
  scene.set_updater(
    target,
    (context, state) => {
      @test.assert_raise(() => context.get(target))
      @test.assert_raise(() => context.world_transform(target))
      @test.assert_eq(context.get_value(tracker), 2.0)
      { ..state, transform: context.get(source).transform, }
    },
    depends_on=dependencies,
    trackers~,
  )
  dependencies.clear()
  trackers.clear()
  scene.update()
}

///|
test "animated subtrees suspend their updaters while followers keep updating" {
  let (scene, sink) = dynamic_scene()
  let group = scene.add(@mobject.ObjectState::group())
  let dot = dynamic_dot(scene)
  let follower = dynamic_dot(scene)
  scene.reparent(dot, Some(group))
  let calls : Ref[Int32] = { val: 0, }
  scene.set_updater(dot, (_context, state) => {
    calls.val = calls.val + 1
    { ..state, transform: @math.Affine2::translation(10.0, 0.0), }
  })
  scene.set_updater(
    follower,
    (context, state) => { ..state, transform: context.world_transform(dot), },
    depends_on=[dot],
  )
  scene.play(
    [@animation.shift(group, @math.Vec3::new(4.0, 0.0), easing=Linear)],
    duration=1.0,
  )
  @test.assert_eq(calls.val, 0)
  @test.assert_eq(sink.frames[2].items[1].transform.tx, 2.0)
  @test.assert_eq(scene.get(follower).transform.tx, 4.0)
  scene.wait(0.0)
  @test.assert_eq(calls.val, 1)
  @test.assert_eq(scene.get(follower).transform.tx, 14.0)
  scene.clear_updater(dot)
  scene.wait(0.25)
  @test.assert_eq(calls.val, 1)
}

///|
test "removed dependencies unbind callbacks and never attach to reused slots" {
  let (scene, _) = dynamic_scene()
  let group = scene.add(@mobject.ObjectState::group())
  let source = dynamic_dot(scene)
  scene.reparent(source, Some(group))
  let follower = dynamic_dot(scene)
  let tracker = scene.add_tracker(1.0)
  let calls : Ref[Int32] = { val: 0, }
  scene.set_updater(
    follower,
    (_context, state) => {
      calls.val = calls.val + 1
      state
    },
    depends_on=[source],
  )
  scene.play([@animation.fade_out(group)], duration=0.0)
  @test.assert_eq(calls.val, 1)
  ignore(dynamic_dot(scene))
  scene.wait(0.25)
  @test.assert_eq(calls.val, 1)
  scene.set_updater(
    follower,
    (_context, state) => {
      calls.val = calls.val + 1
      state
    },
    trackers=[tracker],
  )
  scene.remove_tracker(tracker)
  ignore(scene.add_tracker(7.0))
  @test.assert_raise(() => scene.get_value(tracker))
  scene.update()
  @test.assert_eq(calls.val, 1)
  scene.set_updater(follower, (_context, state) => state)
  scene.remove(follower)
  scene.update()
}

///|
test "scalar preflight errors are atomic and scene scoped" {
  let (scene, sink) = dynamic_scene()
  let (other, _) = dynamic_scene()
  let tracker = scene.add_tracker(0.0)
  let foreign = other.add_tracker(0.0)
  let dot = dynamic_dot(scene)
  let before = scene.get(dot)
  let invalid_values = [
    [@scene.value_to(tracker, 2.0), @scene.value_to(tracker, 3.0)],
    [@scene.value_to(tracker, 1.0 / 0.0)],
    [@scene.value_to(foreign, 1.0)],
  ]
  for values in invalid_values {
    @test.assert_raise(() => {
      scene.play([@animation.fade_out(dot)], values~, duration=1.0)
    })
    @test.assert_eq(scene.get(dot), before)
    @test.assert_eq(scene.get_value(tracker), 0.0)
    @test.assert_eq(sink.frames.length(), 0)
  }
  @test.assert_raise(() => scene.set_value(tracker, 0.0 / 0.0))
  @test.assert_raise(() => scene.add_tracker(1.0 / 0.0))
  @test.assert_raise(() => {
    scene.set_updater(dot, (_context, state) => state, trackers=[foreign])
  })
  scene.play([], values=[@scene.value_to(tracker, 9.0)], duration=0.0)
  @test.assert_eq(scene.get_value(tracker), 9.0)
  @test.assert_eq(scene.time(), 0.0)
}

///|
test "failed updater passes commit no partial geometry and poison the scene" {
  let (scene, sink) = dynamic_scene()
  let a = dynamic_dot(scene)
  let b = dynamic_dot(scene)
  let before = scene.get(a)
  scene.set_updater(a, (_context, state) => {
    ..state,
    transform: @math.Affine2::translation(100.0, 0.0),
  })
  scene.set_updater(
    b,
    (_context, state) => { ..state, style: { ..state.style, opacity: 2.0, }, },
    depends_on=[a],
  )
  @test.assert_raise(() => scene.wait(1.0))
  @test.assert_eq(scene.get(a), before)
  @test.assert_eq(scene.frame_index(), 0L)
  @test.assert_eq(sink.frames.length(), 0)
  let error = @test.expect_error(() => scene.update())
  @test.assert_eq(error is @errors.SceneFailed, true)
}

///|
test "updater callbacks cannot bypass scene mutation guards" {
  let (scene, _) = dynamic_scene()
  let tracker = scene.add_tracker(0.0)
  let dot = dynamic_dot(scene)
  scene.set_updater(dot, (_context, state) => {
    @test.assert_raise(() => scene.set_value(tracker, 5.0))
    @test.assert_raise(() => scene.remove_tracker(tracker))
    @test.assert_raise(() => scene.clear_updater(dot))
    @test.assert_raise(() => scene.set_updater(dot, (_context, state) => state))
    @test.assert_raise(() => scene.update())
    @test.assert_raise(() => scene.play([], duration=0.0))
    state
  })
  scene.wait(0.25)
  @test.assert_eq(scene.get_value(tracker), 0.0)
  scene.set_value(tracker, 2.0)
}

///|
test "scalar tracks use the full clock during staggered object playback" {
  let (scene, sink) = dynamic_scene()
  let tracker = scene.add_tracker(-1.0e308)
  let a = dynamic_dot(scene)
  let b = dynamic_dot(scene)
  let c = dynamic_dot(scene)
  scene.set_updater(
    b,
    (context, state) => {
      ..state,
      transform: @math.Affine2::translation(
        context.get_value(tracker) / 1.0e308,
        0.0,
      ),
    },
    trackers=[tracker],
  )
  scene.play_staggered(
    [@animation.fade_in(a), @animation.fade_in(c)],
    values=[@scene.value_to(tracker, 1.0e308, easing=Linear)],
    duration=1.0,
    lag_ratio=1.0,
  )
  @test.assert_eq(sink.frames[2].items[1].transform.tx, 0.0)
  @test.assert_eq(scene.get_value(tracker), 1.0e308)
  @test.assert_eq(scene.get(b).transform.tx, 1.0)
}

///|
priv struct DynamicCallbackRenderer {
  callback : () -> Unit raise
}

///|
impl @render.Renderer for DynamicCallbackRenderer with fn render(self, _frame) {
  (self.callback)()
}

///|
test "renderer callbacks cannot mutate trackers or updater bindings" {
  let scenes : Array[@scene.Scene] = []
  let trackers : Array[@scene.ValueTracker] = []
  let objects : Array[@mobject.ObjectId] = []
  let sink : DynamicCallbackRenderer = {
    callback: () => {
      let scene = scenes[0]
      @test.assert_raise(() => scene.add_tracker(1.0))
      @test.assert_raise(() => scene.set_value(trackers[0], 1.0))
      @test.assert_raise(() => scene.remove_tracker(trackers[0]))
      @test.assert_raise(() => scene.clear_updater(objects[0]))
      @test.assert_raise(() => scene.update())
    },
  }
  let scene = @scene.Scene::new(sink, frame_rate=@timeline.FrameRate::new(1))
  scenes.push(scene)
  trackers.push(scene.add_tracker(0.0))
  objects.push(dynamic_dot(scene))
  scene.wait(1.0)
  @test.assert_eq(scene.get_value(trackers[0]), 0.0)
}

///|
test "rational frame rate and zero duration retain exact dynamic endpoints" {
  let sink : DynamicRecorder = { frames: [], }
  let rate = @timeline.FrameRate::new(30000, denominator=1001)
  let scene = @scene.Scene::new(sink, frame_rate=rate)
  let tracker = scene.add_tracker(0.0)
  let dot = dynamic_dot(scene)
  let captured : Array[@scene.UpdateContext] = []
  scene.set_updater(
    dot,
    (context, state) => {
      captured.push(context)
      {
        ..state,
        transform: @math.Affine2::translation(
          context.get_value(tracker),
          state.transform.ty + context.dt,
        ),
      }
    },
    trackers=[tracker],
  )
  scene.play(
    [],
    values=[@scene.value_to(tracker, 3.0, easing=Linear)],
    duration=0.1,
  )
  @test.assert_eq(sink.frames.length(), 3)
  @test.assert_eq(sink.frames[2].time, rate.time(2L))
  @test.assert_eq(scene.get(dot).transform.tx, 3.0)
  @test.assert_eq(scene.get(dot).transform.ty, rate.time(3L))
  scene.play([], values=[@scene.value_to(tracker, 7.0)], duration=0.0)
  @test.assert_eq(scene.get(dot).transform.tx, 7.0)
  @test.assert_eq(scene.get(dot).transform.ty, rate.time(3L))
  @test.assert_eq(sink.frames.length(), 3)
  @test.assert_eq(captured[0].get_value(tracker), 0.0)
  @test.assert_eq(captured[3].get_value(tracker), 3.0)
}
