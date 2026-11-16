///|
test "camera maps world origin and up direction to output pixels" {
  let camera = @render.Camera2D::new(
    pixel_width=800,
    pixel_height=400,
    frame_height=4.0,
  )
  @test.assert_eq(
    camera.project(@math.Vec3::zero()),
    @math.Vec3::new(400.0, 200.0),
  )
  @test.assert_eq(
    camera.project(@math.Vec3::new(0.0, 1.0)),
    @math.Vec3::new(400.0, 100.0),
  )
  @test.assert_eq(
    camera.project(@math.Vec3::new(4.0, 0.0)),
    @math.Vec3::new(800.0, 200.0),
  )
  @test.assert_raise(() => @render.Camera2D::new(pixel_height=0))
}

///|
test "perspective camera makes nearby points larger" {
  let camera = @render.Perspective3D::new(focal_length=4.0)
  let near = camera.project(@math.Vec3::new(1.0, 0.0, z=2.0))
  let far = camera.project(@math.Vec3::new(1.0, 0.0, z=-2.0))
  @test.assert_eq(near.x > far.x, true)
  @test.assert_eq(near.z > far.z, true)
}

///|
test "perspective camera preserves rotated depth" {
  let camera = @render.Perspective3D::new(yaw=1.5707963267948966)
  let view = camera.rotate(@math.Vec3::new(1.0, 0.0))
  @test.assert_eq(view.z < -0.99, true)
  @test.assert_eq(view.x.abs() < 1.0e-9, true)
}

///|
test "SVG preserves contour closure, fill rule, opacity and pixel stroke width" {
  let store = @mobject.Store::new()
  ignore(
    store.add({
      ..@mobject.ObjectState::shape(@geometry.square(2.0)),
      transform: @math.Affine2::scaling(2.0, 2.0),
      style: {
        ..@mobject.Style::default(),
        fill_opacity: 0.3,
        opacity: 0.5,
        fill_rule: EvenOdd,
        stroke_width: 4.0,
      },
    }),
  )
  let svg = @render.svg_frame(@render.Camera2D::new(), {
    index: 0L,
    time: 0.0,
    items: store.drawables(),
  })
  @test.assert_eq(svg.contains("fill-rule=\"evenodd\""), true)
  @test.assert_eq(svg.contains("stroke-width=\"4\""), true)
  @test.assert_eq(svg.contains("opacity=\"0.5\""), true)
  @test.assert_eq(svg.contains("Z "), true)
  @test.assert_eq(
    svg.contains("<svg xmlns=\"http://www.w3.org/2000/svg\""),
    true,
  )
}

///|
test "renderer rejects overflowing projected geometry" {
  let store = @mobject.Store::new()
  ignore(
    store.add({
      ..@mobject.ObjectState::shape(@geometry.circle(1.0)),
      transform: @math.Affine2::scaling(1.0e308, 1.0e308),
    }),
  )
  let camera = @render.Camera2D::new(frame_height=0.001)
  @test.assert_raise(() => {
    @render.svg_frame(camera, {
      index: 0L,
      time: 0.0,
      items: store.drawables(),
    })
  })
}
