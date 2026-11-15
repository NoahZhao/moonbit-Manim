///|
/// Stateless updaters consume absolute lesson samples; no frames are emitted here.
priv struct LessonSink {}

///|
impl @render.Renderer for LessonSink with fn render(_self, _frame) {
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
/// Geometry, parameter schema and narration are shared by video and browser.
pub struct Tangent {
  lesson : @lesson.Lesson
  narration : @narration.NarrationTrack
  priv scene : @scene.Scene
  priv position : @scene.ValueTracker
  priv gap : @scene.ValueTracker
  priv camera : @render.Camera2D
}

///|
pub fn Tangent::new() -> Tangent raise {
  let lesson = @lesson.Lesson::new(
    [
      {
        key: "x",
        label: "观察位置 x",
        initial: -1.5,
        min: -3.0,
        max: 3.0,
        step: 0.05,
        unit: "",
      },
      {
        key: "h",
        label: "两点间距 h",
        initial: 2.0,
        min: 0.0,
        max: 2.0,
        step: 0.01,
        unit: "",
      },
    ],
    [
      @lesson.cue(
        "01 · 两点确定割线", "粉色点 P 与绿色点 Q 确定割线；h 是两点的横向间距。",
        1.0,
      ),
      @lesson.cue(
        "02 · 让 h 趋近零",
        "绿色点逐渐靠近粉色点，割线的斜率趋近导数。",
        3.0,
        targets=[@lesson.to("h", 0.0)],
      ),
      @lesson.cue(
        "03 · 沿曲线观察切线",
        "沿曲线移动，观察切线斜率由负变正。",
        3.0,
        targets=[@lesson.to("x", 2.6, easing=Linear)],
      ),
      @lesson.cue(
        "04 · 换一个观察位置",
        "回到下降区间，再比较割线与切线。",
        1.0,
        targets=[@lesson.to("x", -1.5)],
      ),
      @lesson.cue(
        "05 · 再次分开两点",
        "拉开两点，看割线的斜率与导数产生差距。",
        1.0,
        targets=[@lesson.to("h", 2.0)],
      ),
      @lesson.cue(
        "06 · 在同一画面继续探索",
        "再次让 h 趋近零。随时切换自由探索，亲手改变 x 和 h。",
        3.0,
        targets=[@lesson.to("h", 0.0)],
      ),
    ],
  )
  let durations = narration_durations()
  let narration = @narration.NarrationTrack::new(
    "assets/narration/tangent.m4a",
    "zh-CN",
    narration_script(),
    durations,
  )
  let lesson = lesson.retime(durations)
  let scene = @scene.Scene::new(LessonSink::{ })
  let blue = @mobject.Color::rgb(0.49, 0.62, 1.0)
  let teal = @mobject.Color::rgb(0.36, 0.79, 0.74)
  let amber = @mobject.Color::rgb(0.93, 0.70, 0.46)
  let pink = @mobject.Color::pink()
  let plane = @coordinates.NumberPlane::new(
    x_min=-5.5,
    x_max=5.5,
    y_min=-1.0,
    y_max=7.0,
    transform=@math.Affine2::translation(-0.4, -1.55).compose(
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
  let position = scene.add_tracker(-1.5)
  let gap = scene.add_tracker(2.0)
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
  let assets = @text.TexAsset::parse(@teaching.tex_assets())
  for
    (tex, origin, color, size) in [
      ("y=\\frac{x^2}{4}", @math.Vec3::new(-6.1, 2.25), blue, 0.45),
      ("f'(x)=\\frac{x}{2}", @math.Vec3::new(3.8, 2.25), amber, 0.45),
      (
        "\\frac{f(x+h)-f(x)}{h}\\longrightarrow f'(x)",
        @math.Vec3::new(-2.6, -2.8),
        amber,
        0.38,
      ),
    ] {
    ignore(
      @text.Formula::new(
        scene,
        @text.MathTex::new(
          [{ key: "formula", glyph: assets.glyph(tex), color, }],
          font_size=size,
        ),
        origin~,
      ),
    )
  }
  let camera = @render.Camera2D::new(
    background=@mobject.Color::rgb(0.055, 0.071, 0.106),
  )
  { lesson, narration, scene, position, gap, camera, }
}

///|
pub fn Tangent::at(self : Tangent, time : Double) -> @json.Json raise {
  self.draw(self.lesson.sample(time))
}

///|
pub fn Tangent::manual(
  self : Tangent,
  x : Double,
  h : Double,
) -> @json.Json raise {
  self.draw(self.lesson.explore([("x", x), ("h", h)]))
}

///|
fn Tangent::draw(self : Tangent, sample : @lesson.Sample) -> @json.Json raise {
  let x = sample.get("x")
  let h = sample.get("h")
  self.scene.set_value(self.position, x)
  self.scene.set_value(self.gap, h)
  self.scene.update()
  @json.Json::object({
    "type": "frame",
    "index": @json.Json::number((sample.time * 60.0).round()),
    "time": @json.Json::number(sample.time),
    "progress": @json.Json::number(sample.progress),
    "chapter": @json.Json::number(sample.chapter.to_double()),
    "title": @json.Json::string(sample.title),
    "phase": @json.Json::string(
      if sample.chapter < 0 {
        sample.caption
      } else {
        self.narration.sample(sample.time).text
      },
    ),
    "bookmark": @json.Json::string(
      if sample.chapter < 0 {
        ""
      } else {
        self.narration.sample(sample.time).key
      },
    ),
    "svg": @json.Json::string(
      @render.svg_frame(self.camera, self.scene.snapshot()),
    ),
    "values": @json.Json::object({
      "x": @json.Json::number(x),
      "y": @json.Json::number(x * x / 4.0),
      "gap": @json.Json::number(h),
      "slope": @json.Json::number((2.0 * x + h) / 4.0),
      "derivative": @json.Json::number(x / 2.0),
    }),
  })
}
