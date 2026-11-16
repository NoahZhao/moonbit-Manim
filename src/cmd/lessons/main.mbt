///|
fn main raise {
  run() catch {
    @errors.InvalidArgument(message) => abort(message)
    error => raise error
  }
}

///|
fn run() -> Unit raise {
  let args = @env.args()
  let name = if args.length() > 1 { args[1] } else { "formula" }
  if name != "formula" &&
    name != "matrix" &&
    name != "pythagoras" &&
    name != "riemann" {
    raise @errors.InvalidArgument(
      "expected formula, matrix, pythagoras or riemann",
    )
  }
  let phase : Ref[String] = { val: "Ready", }
  let camera = @render.Camera2D::new(
    background=@mobject.Color::rgb(0.024, 0.035, 0.055),
  )
  println(
    @json.Json::object({
      "type": @json.Json::string("start"),
      "scene": @json.Json::string(name),
      "width": @json.Json::number(1280.0),
      "height": @json.Json::number(720.0),
      "fps": @json.Json::number(60.0),
    }).stringify(),
  )
  let renderer = @render.SvgRenderer::new(camera, (index, svg) => {
    println(
      @json.Json::object({
        "type": @json.Json::string("frame"),
        "index": @json.Json::number(index.to_double()),
        "phase": @json.Json::string(phase.val),
        "svg": @json.Json::string(svg),
      }).stringify(),
    )
  })
  let scene = @scene.Scene::new(renderer)
  let assets = @text.TexAsset::parse(@teaching.tex_assets())
  try {
    match name {
      "formula" => quadratic(scene, assets, phase)
      "matrix" => linear_algebra(scene, assets, phase)
      "pythagoras" => pythagoras(scene, assets, phase)
      _ => riemann(scene, assets, phase)
    }
  } catch {
    @errors.InvalidArgument(message) => abort(phase.val + ": " + message)
    error => raise error
  }
  println(
    @json.Json::object({
      "type": @json.Json::string("end"),
      "frames": @json.Json::number(scene.frame_index().to_double()),
      "duration": @json.Json::number(scene.time()),
    }).stringify(),
  )
}
