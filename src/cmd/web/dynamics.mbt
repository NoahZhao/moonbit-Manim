///|
/// A single read-only browser snapshot uses the same tracker/updater scheduler
/// as offline playback. Rebuilding this pure scene makes progress scrubbing safe.
priv struct BrowserSink {}

///|
impl @render.Renderer for BrowserSink with fn render(_self, _frame) {
  ()
}

///|
fn dynamic_shape(
  path : @geometry.Path,
  color : @mobject.Color,
  width~ : Double = 3.0,
  opacity~ : Double = 1.0,
  fill~ : Double = 0.0,
) -> @mobject.ObjectState {
  @mobject.ObjectState::shape(path, style={
    ..@mobject.Style::default(),
    stroke: color,
    fill: color,
    stroke_width: width,
    opacity,
    fill_opacity: fill,
  })
}

///|
fn tangent_frame(t : Double, x : Double, initial_gap : Double) -> String raise {
  if x < -3.0 || x > 3.0 || initial_gap < 0.0 || initial_gap > 2.0 {
    raise @errors.InvalidArgument("invalid tangent position or gap")
  }
  let scene = @scene.Scene::new(BrowserSink::{ })
  let blue = @mobject.Color::rgb(0.49, 0.62, 1.0)
  let teal = @mobject.Color::rgb(0.36, 0.79, 0.74)
  let amber = @mobject.Color::rgb(0.93, 0.70, 0.46)
  let pink = @mobject.Color::pink()
  let plane = @coordinates.NumberPlane::new(
    x_min=-5.5,
    x_max=5.5,
    y_min=-1.0,
    y_max=7.0,
    transform=@math.Affine2::translation(-0.4, -2.3).compose(
      @math.Affine2::scaling(0.8, 0.8),
    ),
  )
  ignore(scene.add(dynamic_shape(plane.grid(), blue, width=0.8, opacity=0.16)))
  ignore(scene.add(dynamic_shape(plane.axes(), blue, width=1.3, opacity=0.4)))
  ignore(
    scene.add(
      dynamic_shape(plane.plot(x => Some(x * x / 4.0), samples=400), blue),
    ),
  )
  let position = scene.add_tracker(x)
  let gap = scene.add_tracker(initial_gap * (1.0 - t))
  let p = scene.add(
    dynamic_shape(@geometry.circle(0.09), pink, width=1.0, fill=1.0),
  )
  let q = scene.add(
    dynamic_shape(@geometry.circle(0.08), teal, width=1.0, fill=1.0),
  )
  let line = scene.add(
    dynamic_shape(@geometry.line(@math.Vec3::zero(), @math.Vec3::zero()), amber),
  )
  let guide = scene.add(
    dynamic_shape(
      @geometry.line(@math.Vec3::zero(), @math.Vec3::zero()),
      pink,
      width=1.2,
      opacity=0.4,
    ),
  )
  for id in [line, guide] {
    scene.set(id, { ..scene.get(id), z_index: -1, })
  }
  scene.set_updater(
    line,
    (context, state) => {
      let h = context.get_value(gap)
      let slope = (2.0 * context.get_value(position) + h) / 4.0
      let point = context.world_transform(p).apply(@math.Vec3::zero())
      let vector = @math.Vec3::new(1.0, slope)
      let direction = vector.normalized()
      let reach = (h * 0.8 * vector.length() + 0.3).max(1.7)
      {
        ..state,
        path: Some(
          @geometry.line(
            point.sub(direction.scale(1.7)),
            point.add(direction.scale(reach)),
          ),
        ),
      }
    },
    depends_on=[p],
    trackers=[position, gap],
  )
  scene.set_updater(
    guide,
    (context, state) => {
      let point = context.world_transform(p).apply(@math.Vec3::zero())
      {
        ..state,
        path: Some(
          @geometry.line(plane.point(context.get_value(position), 0.0), point),
        ),
      }
    },
    depends_on=[p],
    trackers=[position],
  )
  scene.set_updater(
    q,
    (context, state) => {
      let h = context.get_value(gap)
      let a = context.get_value(position) + h
      let point = plane.point(a, a * a / 4.0)
      {
        ..state,
        transform: @math.Affine2::translation(point.x, point.y),
        style: { ..state.style, opacity: (h / 0.25).min(1.0), },
      }
    },
    trackers=[position, gap],
  )
  scene.set_updater(
    p,
    (context, state) => {
      let a = context.get_value(position)
      let point = plane.point(a, a * a / 4.0)
      { ..state, transform: @math.Affine2::translation(point.x, point.y), }
    },
    trackers=[position],
  )
  scene.update()
  let camera = @render.Camera2D::new(
    pixel_width=960,
    pixel_height=600,
    frame_height=8.0,
    background=@mobject.Color::rgb(0.055, 0.071, 0.106),
  )
  @json.Json::object({
    "svg": @json.Json::string(@render.svg_frame(camera, scene.snapshot())),
    "values": @json.Json::object({
      "x": @json.Json::number(x),
      "y": @json.Json::number(x * x / 4.0),
      "gap": @json.Json::number(scene.get_value(gap)),
      "slope": @json.Json::number((2.0 * x + scene.get_value(gap)) / 4.0),
      "derivative": @json.Json::number(x / 2.0),
    }),
  }).stringify()
}
