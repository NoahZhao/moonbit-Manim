///|
test "rotation preserves length instead of collapsing through matrix interpolation" {
  let store = @mobject.Store::new()
  let id = store.add(@mobject.ObjectState::shape(@geometry.square(2.0)))
  let animation = @animation.rotate(id, 3.141592653589793, easing=Linear).prepare(
    store,
  )
  let point = animation.sample(0.5).transform.apply(@math.Vec3::new(1.0, 0.0))
  @test.assert_eq(point.near(@math.Vec3::new(0.0, 1.0)), true)
  @test.assert_eq(point.length().is_close(1.0), true)
}

///|
test "descriptors capture source state at prepare time" {
  let store = @mobject.Store::new()
  let state = @mobject.ObjectState::shape(@geometry.square(2.0))
  let id = store.add(state)
  let descriptor = @animation.shift(
    id,
    @math.Vec3::new(2.0, 0.0),
    easing=Linear,
  )
  store.set(id, { ..state, transform: @math.Affine2::translation(3.0, 0.0), })
  let prepared = descriptor.prepare(store)
  @test.assert_eq(prepared.sample(0.5).transform.tx, 4.0)
  @test.assert_eq(prepared.sample(1.0).transform.tx, 5.0)
  @test.assert_eq(prepared.sample(0.5).transform.tx, 4.0)
  @test.assert_eq(store.get(id).transform.tx, 3.0)
}

///|
test "transformed morphs preserve both original endpoint states" {
  let store = @mobject.Store::new()
  let start : @mobject.ObjectState = {
    ..@mobject.ObjectState::shape(@geometry.square(2.0)),
    transform: @math.Affine2::translation(-2.0, 0.0),
  }
  let id = store.add(start)
  let target : @mobject.ObjectState = {
    ..@mobject.ObjectState::shape(@geometry.circle(1.0)),
    transform: @math.Affine2::translation(2.0, 0.0),
    style: { ..start.style, stroke: @mobject.Color::pink(), },
  }
  let prepared = @animation.transform(id, target).prepare(store)
  @test.assert_eq(prepared.sample(0.0), start)
  @test.assert_eq(prepared.sample(1.0), target)
  @test.assert_eq(prepared.sample(0.5).transform, @math.Affine2::identity())
  @test.assert_eq(store.get(id), start)
}
