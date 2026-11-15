///|
/// Run natively and redirect stdout to an SVG contact sheet.
/// Every intermediate frame is evaluated; the sink retains only six checkpoints.
fn main raise {
  let checkpoints = [29L, 60L, 90L, 149L, 179L, 210L]
  let tiles : Array[String] = []
  let camera = @render.Camera2D::new(
    pixel_width=480,
    pixel_height=270,
    frame_height=5.0,
  )
  let renderer = @render.SvgRenderer::new(camera, (index, svg) => {
    if checkpoints.contains(index) {
      tiles.push(svg)
    }
  })
  let scene = @scene.Scene::new(renderer)
  let square = scene.add(@mobject.ObjectState::shape(@geometry.square(2.0)))
  let target = @mobject.ObjectState::shape(@geometry.circle(1.0), style={
    ..@mobject.Style::default(),
    stroke: @mobject.Color::pink(),
    fill: @mobject.Color::pink(),
    fill_opacity: 0.3,
  })
  scene.play([@animation.fade_in(square)], duration=0.5)
  scene.play([@animation.transform(square, target)], duration=2.0)
  scene.play(
    [@animation.shift(square, @math.Vec3::new(1.0, 0.5))],
    duration=0.5,
  )
  scene.play([@animation.fade_out(square)], duration=0.5)
  scene.wait(0.25)
  let labels = [
    "Square", "Transform: 25%", "Transform: 50%", "Circle", "Shift", "Fade out",
  ]
  let out = StringBuilder()
  out.write_string(
    "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"1440\" height=\"608\" viewBox=\"0 0 1440 608\">\n",
  )
  out.write_string("<rect width=\"100%\" height=\"100%\" fill=\"#11151e\"/>\n")
  for i in 0..<tiles.length() {
    let x = i % 3 * 480
    let y = i / 3 * 304
    out.write_string(
      "<g transform=\"translate(\{x} \{y})\">\{tiles[i]}<text x=\"18\" y=\"292\" fill=\"#c8d4e5\" font-family=\"monospace\" font-size=\"16\">\{labels[i]}</text></g>\n",
    )
  }
  out.write_string("</svg>")
  println(out.to_string())
}
