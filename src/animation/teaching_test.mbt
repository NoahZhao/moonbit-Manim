///|
test "apply affine interpolates basis vectors and preserves child local geometry" {
  let store = @mobject.Store::new()
  let root = store.add(@mobject.ObjectState::group())
  let child = store.add(@mobject.ObjectState::shape(@geometry.square(1.0)))
  store.reparent(child, Some(root))
  let shear : @math.Affine2 = { ..@math.Affine2::identity(), c: 2.0, }
  let prepared = @animation.apply_affine(root, shear, easing=Linear).prepare(
    store,
  )
  let midway = prepared.sample(0.5)
  @test.assert_eq(
    midway.transform.apply(@math.Vec3::new(0.0, 1.0)),
    @math.Vec3::new(1.0, 1.0),
  )
  store.set(root, prepared.sample(1.0))
  @test.assert_eq(store.world_transform(child), shear)
  @test.assert_eq(store.get(child).transform, @math.Affine2::identity())
  @test.assert_eq(prepared.sample(0.5), midway)
}

///|
test "write draws filled vector outlines and restores exact style at completion" {
  let store = @mobject.Store::new()
  let state = @mobject.ObjectState::shape(@geometry.rectangle(2.0, 1.0), style={
    ..@mobject.Style::default(),
    fill_opacity: 0.8,
    stroke_width: 0.0,
  })
  let id = store.add(state)
  let prepared = @animation.write(id, easing=Linear).prepare(store)
  @test.assert_eq(prepared.sample(0.0).path.unwrap().segment_count(), 0)
  let halfway = prepared.sample(0.5)
  @test.assert_eq(halfway.style.fill_opacity, 0.0)
  @test.assert_eq(halfway.style.stroke_width > 0.0, true)
  @test.assert_eq(prepared.sample(0.9).style.fill_opacity > 0.0, true)
  @test.assert_eq(prepared.sample(1.0), state)
  @test.assert_eq(store.get(id), state)
}
