///|
test "handles reject stale generations and foreign stores" {
  let store = @mobject.Store::new()
  let state = @mobject.ObjectState::shape(@geometry.square(2.0))
  let old = store.add(state)
  let other = @mobject.Store::new()
  let foreign = other.add(state)
  @test.assert_eq(old == foreign, false)
  @test.assert_raise(() => store.get(foreign))
  store.remove(old)
  let fresh = store.add(state)
  @test.assert_eq(old == fresh, false)
  @test.assert_eq(store.contains(old), false)
  @test.assert_eq(store.contains(fresh), true)
  @test.assert_raise(() => store.set(old, state))
}

///|
test "hierarchy composes transforms and opacity without changing snapshots" {
  let store = @mobject.Store::new()
  let base = @mobject.ObjectState::shape(@geometry.square(2.0))
  let parent = store.add({
    ..@mobject.ObjectState::group(),
    transform: @math.Affine2::translation(2.0, 3.0),
    style: { ..@mobject.Style::default(), opacity: 0.5, },
  })
  let child = store.add({
    ..base,
    transform: @math.Affine2::scaling(2.0, 2.0),
    style: { ..base.style, opacity: 0.4, },
  })
  store.reparent(child, Some(parent))
  let snapshot = store.drawables()
  @test.assert_eq(snapshot.length(), 1)
  @test.assert_eq(
    snapshot[0].transform.apply(@math.Vec3::new(1.0, 1.0)),
    @math.Vec3::new(4.0, 5.0),
  )
  @test.assert_eq(snapshot[0].style.opacity.is_close(0.2), true)
  store.set(child, base)
  @test.assert_eq(snapshot[0].style.opacity.is_close(0.2), true)
  @test.assert_eq(store.get(child), base)
}

///|
test "cycles fail atomically and subtree removal invalidates descendants" {
  let store = @mobject.Store::new()
  let parent = store.add(@mobject.ObjectState::group())
  let child = store.add(@mobject.ObjectState::shape(@geometry.circle(1.0)))
  store.reparent(child, Some(parent))
  @test.assert_raise(() => store.reparent(parent, Some(child)))
  @test.assert_eq(store.drawables().length(), 1)
  store.remove(parent)
  @test.assert_eq(store.length(), 0)
  @test.assert_eq(store.contains(child), false)
}

///|
test "draw order is stable across slot reuse" {
  let store = @mobject.Store::new()
  let state = @mobject.ObjectState::shape(@geometry.square(2.0))
  let a = store.add(state)
  let b = store.add(state)
  let behind = store.add({ ..state, z_index: -1, })
  store.remove(a)
  let c = store.add(state)
  let items = store.drawables()
  @test.assert_eq(items[0].id, behind)
  @test.assert_eq(items[1].id, b)
  @test.assert_eq(items[2].id, c)
}

///|
test "invalid styles cannot enter or overwrite the store" {
  let store = @mobject.Store::new()
  let state = @mobject.ObjectState::shape(@geometry.circle(1.0))
  let id = store.add(state)
  let invalid : @mobject.ObjectState = {
    ..state,
    style: { ..state.style, opacity: 1.5, },
  }
  @test.assert_raise(() => store.set(id, invalid))
  @test.assert_raise(() => store.add(invalid))
  @test.assert_eq(store.get(id), state)
  @test.assert_raise(() => @mobject.Color::rgb(-0.1, 0.0, 0.0))
}
