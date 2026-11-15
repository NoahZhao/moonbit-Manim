///|
/// A curved stroke revealed in equal arc-length steps; the gray box is its
/// analytic bound and the faint line is the complete reference curve.
fn main raise {
  let checkpoints = [0L, 24L, 48L, 72L, 96L, 120L]
  let tiles : Array[String] = []
  let camera = @render.Camera2D::new(
    pixel_width=480,
    pixel_height=270,
    frame_height=4.5,
  )
  let renderer = @render.SvgRenderer::new(camera, (index, svg) => {
    if checkpoints.contains(index) {
      tiles.push(svg)
    }
  })
  let scene = @scene.Scene::new(renderer)
  let path = @geometry.Path::new([
    @geometry.Contour::new([
      {
        p0: @math.Vec3::new(-3.0, 0.0),
        p1: @math.Vec3::new(-1.0, 3.0),
        p2: @math.Vec3::new(1.0, -3.0),
        p3: @math.Vec3::new(3.0, 0.0),
      },
    ]),
  ])
  let bounds = path.bounds().unwrap()
  let center = bounds.center()
  ignore(
    scene.add({
      ..@mobject.ObjectState::shape(@geometry.square(2.0)),
      transform: @math.Affine2::translation(center.x, center.y).compose(
        @math.Affine2::scaling(
          (bounds.max.x - bounds.min.x) * 0.5,
          (bounds.max.y - bounds.min.y) * 0.5,
        ),
      ),
      style: {
        ..@mobject.Style::default(),
        stroke: @mobject.Color::rgb(0.55, 0.6, 0.7),
        stroke_width: 1.0,
        opacity: 0.35,
      },
      z_index: -1,
    }),
  )
  ignore(
    scene.add(
      @mobject.ObjectState::shape(path, style={
        ..@mobject.Style::default(),
        stroke_width: 2.0,
        opacity: 0.18,
      }),
    ),
  )
  let stroke = scene.add(@mobject.ObjectState::shape(path))
  scene.play([@animation.create(stroke, easing=Linear)], duration=2.0)
  // The next frame shows the exact final state, without duplicating a play endpoint.
  scene.wait(1.0 / 60.0)
  let out = StringBuilder()
  out.write_string(
    "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"1440\" height=\"608\" viewBox=\"0 0 1440 608\">\n",
  )
  out.write_string("<rect width=\"100%\" height=\"100%\" fill=\"#11151e\"/>\n")
  for i in 0..<tiles.length() {
    let x = i % 3 * 480
    let y = i / 3 * 304
    let progress = i * 20
    out.write_string(
      "<g transform=\"translate(\{x} \{y})\">\{tiles[i]}<text x=\"18\" y=\"292\" fill=\"#c8d4e5\" font-family=\"monospace\" font-size=\"16\">Create: \{progress}%</text></g>\n",
    )
  }
  out.write_string("</svg>")
  println(out.to_string())
}
