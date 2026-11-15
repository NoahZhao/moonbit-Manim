///|
test "Create uses world arc length while retaining local geometry and identity" {
  let store = @mobject.Store::new()
  let parent = store.add({
    ..@mobject.ObjectState::group(),
    transform: @math.Affine2::scaling(10.0, 1.0),
  })
  let path = @geometry.Path::new([
    @geometry.Contour::new([
      @geometry.Cubic::line(@math.Vec3::zero(), @math.Vec3::new(1.0, 0.0)),
      @geometry.Cubic::line(
        @math.Vec3::new(1.0, 0.0),
        @math.Vec3::new(1.0, 3.0),
      ),
    ]),
  ])
  let state = @mobject.ObjectState::shape(path, style={
    ..@mobject.Style::default(),
    fill_opacity: 0.5,
  })
  let id = store.add(state)
  store.reparent(id, Some(parent))
  let prepared = @animation.create(id, easing=Linear).prepare(store)
  let initial = prepared.sample(0.0)
  @test.assert_eq(initial.path.unwrap().segment_count(), 0)
  let halfway = prepared.sample(0.5)
  let end = halfway.path.unwrap().contours()[0].segments()[0].p3
  @test.assert_eq(end.near(@math.Vec3::new(0.65, 0.0)), true)
  @test.assert_eq(halfway.style.fill_opacity, 0.0)
  @test.assert_eq(halfway.transform, state.transform)
  @test.assert_eq(prepared.sample(1.0), state)
  @test.assert_eq(prepared.id, id)
  @test.assert_eq(store.get(id), state)
  @test.assert_raise(() => prepared.sample(0.0 / 0.0))
}

///|
test "Create rejects group geometry before mutating the store" {
  let store = @mobject.Store::new()
  let group = store.add(@mobject.ObjectState::group())
  @test.assert_raise(() => @animation.create(group).prepare(store))
  let shape = store.add(@mobject.ObjectState::shape(@geometry.circle(1.0)))
  store.reparent(group, Some(shape))
  @test.assert_raise(() => @animation.create(shape).prepare(store))
  @test.assert_eq(store.length(), 2)
}
