///|
/// Stream complete engine frames as JSONL. The external demo exporter only
/// rasterizes SVG, adds presentation labels and encodes the resulting pixels.
fn main raise {
  let args = @env.args()
  let name = if args.length() > 1 { args[1] } else { "morph" }
  if name != "morph" && name != "create" && name != "groups" {
    raise @errors.InvalidArgument("expected morph, create or groups")
  }
  let phase : Ref[String] = { val: "Ready", }
  let camera = @render.Camera2D::new(
    pixel_width=1280,
    pixel_height=720,
    frame_height=8.0,
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
  add_grid(scene)
  match name {
    "morph" => morph_demo(scene, phase)
    "create" => create_demo(scene, phase)
    _ => groups_demo(scene, phase)
  }
  println(
    @json.Json::object({
      "type": @json.Json::string("end"),
      "frames": @json.Json::number(scene.frame_index().to_double()),
      "duration": @json.Json::number(scene.time()),
    }).stringify(),
  )
}
