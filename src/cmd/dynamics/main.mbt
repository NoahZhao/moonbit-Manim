///|
/// Two scalar tracks drive points, a secant/tangent, and a projection guide.
/// Every geometric dependency is evaluated by Scene, including during waits.
fn main raise {
  let phase : Ref[String] = {
    val: "从抛物线上的点，观察局部变化率",
  }
  let camera = @render.Camera2D::new(
    background=@mobject.Color::rgb(0.024, 0.035, 0.055),
  )
  println(
    @json.Json::object({
      "type": "start",
      "scene": "tangent",
      "width": 1280,
      "height": 720,
      "fps": 60,
    }).stringify(),
  )
  let renderer = @render.SvgRenderer::new(camera, (index, svg) => {
    println(
      @json.Json::object({
        "type": "frame",
        "index": @json.Json::number(index.to_double()),
        "phase": @json.Json::string(phase.val),
        "svg": @json.Json::string(svg),
      }).stringify(),
    )
  })
  let scene = @scene.Scene::new(renderer)
  tangent(scene, phase)
  println(
    @json.Json::object({
      "type": "end",
      "frames": @json.Json::number(scene.frame_index().to_double()),
      "duration": @json.Json::number(scene.time()),
    }).stringify(),
  )
}

///|
fn shape(
  path : @geometry.Path,
  color : @mobject.Color,
  width~ : Double = 3.0,
  fill~ : Double = 0.0,
  opacity~ : Double = 1.0,
) -> @mobject.ObjectState {
  @mobject.ObjectState::shape(path, style={
    ..@mobject.Style::default(),
    stroke: color,
    fill: color,
    stroke_width: width,
    fill_opacity: fill,
    opacity,
  })
}

///|
fn formula(
  scene : @scene.Scene,
  assets : @text.TexAsset,
  tex : String,
  position : @math.Vec3,
  color : @mobject.Color,
  size~ : Double = 0.45,
) -> @text.Formula raise {
  @text.Formula::new(
    scene,
    @text.MathTex::new(
      [{ key: "formula", glyph: assets.glyph(tex), color, }],
      font_size=size,
    ),
    origin=position,
  )
}

///|
fn tangent(scene : @scene.Scene, phase : Ref[String]) -> Unit raise {
  let blue = @mobject.Color::blue()
  let pink = @mobject.Color::pink()
  let yellow = @mobject.Color::rgb(1.0, 0.83, 0.36)
  let green = @mobject.Color::rgb(0.45, 0.84, 0.62)
  let plane = @coordinates.NumberPlane::new(
    x_min=-5.8,
    x_max=5.8,
    y_min=-1.3,
    y_max=3.35,
    transform=@math.Affine2::translation(0.0, -1.25),
  )
  ignore(scene.add(shape(plane.grid(step=0.5), blue, width=0.7, opacity=0.13)))
  let axes = scene.add(shape(plane.axes(), blue, width=1.3, opacity=0.5))
  let graph = scene.add(
    shape(plane.plot(x => Some(x * x / 4.0), samples=800), blue, width=3.5),
  )
  let assets = @text.TexAsset::parse(@teaching.tex_assets())
  ignore(
    formula(scene, assets, "y=\\frac{x^2}{4}", @math.Vec3::new(-5.5, 1.9), blue),
  )
  ignore(
    formula(
      scene,
      assets,
      "f'(x)=\\frac{x}{2}",
      @math.Vec3::new(3.4, 1.9),
      yellow,
    ),
  )
  let limit = formula(
    scene,
    assets,
    "\\frac{f(x+h)-f(x)}{h}\\longrightarrow f'(x)",
    @math.Vec3::new(-2.6, -2.7),
    yellow,
    size=0.38,
  )
  scene.set(limit.root, {
    ..scene.get(limit.root),
    style: { ..scene.get(limit.root).style, opacity: 0.0, },
  })
  scene.play([@animation.create(axes), @animation.create(graph)], duration=1.5)
  let x = scene.add_tracker(-3.2)
  let h = scene.add_tracker(0.0)
  let p = scene.add(shape(@geometry.circle(0.09), pink, fill=1.0, width=1.5))
  let q = scene.add(shape(@geometry.circle(0.075), green, fill=1.0, width=1.5))
  let line = scene.add(
    shape(@geometry.line(@math.Vec3::zero(), @math.Vec3::zero()), yellow),
  )
  let guide = scene.add(
    shape(
      @geometry.line(@math.Vec3::zero(), @math.Vec3::zero()),
      pink,
      width=1.5,
      opacity=0.4,
    ),
  )
  // Draw the line and guide under both points, regardless of updater order.
  for id in [line, guide] {
    scene.set(id, { ..scene.get(id), z_index: -1, })
  }
  scene.set_updater(
    guide,
    (context, state) => {
      let point = context.world_transform(p).apply(@math.Vec3::zero())
      { ..state, path: Some(@geometry.line(plane.point(point.x, 0.0), point)), }
    },
    depends_on=[p],
  )
  scene.set_updater(
    line,
    (context, state) => {
      let a = context.get_value(x)
      let step = context.get_value(h)
      let point = context.world_transform(p).apply(@math.Vec3::zero())
      // Exact secant slope for f(x)=x²/4, with a stable analytic limit at h=0.
      let slope = (2.0 * a + step) / 4.0
      let direction = @math.Vec3::new(1.0, slope).normalized().scale(1.9)
      {
        ..state,
        path: Some(@geometry.line(point.sub(direction), point.add(direction))),
      }
    },
    depends_on=[p],
    trackers=[x, h],
  )
  scene.set_updater(
    q,
    (context, state) => {
      let step = context.get_value(h)
      let a = context.get_value(x) + step
      let point = plane.point(a, a * a / 4.0)
      {
        ..state,
        transform: @math.Affine2::translation(point.x, point.y),
        style: { ..state.style, opacity: (step.abs() / 0.4).min(1.0), },
      }
    },
    trackers=[x, h],
  )
  scene.set_updater(
    p,
    (context, state) => {
      let a = context.get_value(x)
      let point = plane.point(a, a * a / 4.0)
      { ..state, transform: @math.Affine2::translation(point.x, point.y), }
    },
    trackers=[x],
  )
  scene.update()
  scene.play(
    [@animation.fade_in(p), @animation.fade_in(line), @animation.fade_in(guide)],
    duration=0.5,
  )
  phase.val = "点沿曲线移动，黄色切线的斜率随 x 连续改变"
  scene.play([], values=[@scene.value_to(x, 2.6, easing=Linear)], duration=3.0)
  scene.wait(0.5)
  scene.play([], values=[@scene.value_to(x, -1.5)], duration=0.75)
  phase.val = "加入第二个点：割线连接 f(x) 与 f(x+h)"
  scene.set(limit.root, {
    ..scene.get(limit.root),
    style: { ..scene.get(limit.root).style, opacity: 1.0, },
  })
  scene.play([], values=[@scene.value_to(h, 2.0)], duration=0.75)
  phase.val = "让 h 趋近于 0：绿色点靠近粉色点，割线趋近切线"
  scene.play([], values=[@scene.value_to(h, 0.0)], duration=2.0)
  phase.val = "导数 f′(x) = x/2：x < 0 时斜率为负，x > 0 时斜率为正"
  scene.play([], values=[@scene.value_to(x, 2.5, easing=Linear)], duration=2.0)
  scene.wait(1.0)
}
