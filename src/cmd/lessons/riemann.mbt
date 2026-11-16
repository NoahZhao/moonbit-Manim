///|
/// Show left-endpoint sums approaching the exact area under x^2 on [0, 2].
fn riemann(
  scene : @scene.Scene,
  assets : @text.TexAsset,
  phase : Ref[String],
) -> Unit raise {
  let blue = @mobject.Color::blue()
  let cyan = @mobject.Color::rgb(0.34, 0.82, 0.94)
  let amber = yellow()
  let white = white()
  let plane = @coordinates.NumberPlane::new(
    x_min=0.0,
    x_max=2.0,
    y_min=0.0,
    y_max=4.0,
    transform=@math.Affine2::translation(-4.3, -2.45).compose(
      @math.Affine2::scaling(2.15, 0.72),
    ),
  )
  let grid = scene.add(
    shape(plane.grid(step=0.5), cyan, opacity=0.12, width=1.0),
  )
  let axes = scene.add(shape(plane.axes(), white, opacity=0.32, width=1.5))
  let curve_segments : Array[@geometry.Cubic] = []
  for index in 0..<64 {
    let x0 = index.to_double() / 32.0
    let x1 = (index + 1).to_double() / 32.0
    curve_segments.push(
      @geometry.Cubic::line(plane.point(x0, x0 * x0), plane.point(x1, x1 * x1)),
    )
  }
  let curve = scene.add(
    shape(
      @geometry.Path::new([@geometry.Contour::new(curve_segments)]),
      cyan,
      width=4.0,
    ),
  )
  let area_points = [
    plane.point(0.0, 0.0),
    plane.point(2.0, 0.0),
    plane.point(2.0, 4.0),
  ]
  let area_segments : Array[@geometry.Cubic] = []
  for index in 0..<(area_points.length() - 1) {
    area_segments.push(
      @geometry.Cubic::line(area_points[index], area_points[index + 1]),
    )
  }
  for index in 0..<64 {
    let x0 = (64 - index).to_double() / 32.0
    let x1 = (63 - index).to_double() / 32.0
    area_segments.push(
      @geometry.Cubic::line(plane.point(x0, x0 * x0), plane.point(x1, x1 * x1)),
    )
  }
  let area = scene.add(
    shape(
      @geometry.Path::new([@geometry.Contour::new(area_segments, closed=true)]),
      blue,
      fill=0.18,
      opacity=0.0,
      width=1.0,
    ),
  )
  hold(scene, phase, "从曲线下面积，走向定积分", 0.35)
  play(
    scene,
    phase,
    "绘制坐标轴与函数 y = x²",
    [@animation.create(grid), @animation.create(axes), @animation.create(curve)],
    1.5,
  )
  play(
    scene,
    phase,
    "关注区间 [0, 2] 下方的面积",
    [@animation.fade_in(area)],
    0.6,
  )
  let equation = label(
    scene,
    assets,
    "\\Delta x=\\frac{2}{n}",
    2.7,
    1.55,
    amber,
    size=0.68,
  )
  phase.val = "把区间等分为 n 份，每份宽度为 Δx"
  equation.write(duration=1.2)
  let mut bars = riemann_bars(scene, plane, 4, amber)
  play(
    scene,
    phase,
    "左端点矩形求和：L₄ = 7/4",
    bars.map(id => @animation.create(id)),
    0.7,
  )
  hold(scene, phase, "每个矩形用左端点高度近似曲线", 0.6)
  let sum4 = riemann_sum(assets, 4, amber, white)
  equation.transition(
    sum4,
    origin=@math.Vec3::new(2.0 - sum4.width / 2.0, 1.55),
    duration=1.0,
  )
  bars = refine_riemann_bars(scene, phase, plane, bars, 4, amber, 16)
  hold(scene, phase, "L₁₆ = 155/64，阶梯更贴近曲线", 0.5)
  let sum16 = riemann_sum(assets, 16, amber, white)
  equation.transition(
    sum16,
    origin=@math.Vec3::new(2.0 - sum16.width / 2.0, 1.55),
    duration=0.8,
  )
  bars = refine_riemann_bars(scene, phase, plane, bars, 16, amber, 32)
  hold(scene, phase, "L₃₂ = 651/256，误差继续缩小", 0.7)
  let sum32 = riemann_sum(assets, 32, amber, white)
  equation.transition(
    sum32,
    origin=@math.Vec3::new(2.0 - sum32.width / 2.0, 1.55),
    duration=0.8,
  )
  let integral = spec(assets, [
    ("integral", "\\int_0^2 x^2\\,dx=\\frac83", cyan),
  ])
  equation.transition(
    integral,
    origin=@math.Vec3::new(2.0 - integral.width / 2.0, 1.55),
    duration=1.1,
  )
  hold(
    scene, phase, "原函数 x³/3 在端点相减，得到精确面积 8/3", 0.8,
  )
  let limit = spec(
    assets,
    [("limit", "\\lim_{n\\to\\infty}L_n=\\int_0^2 x^2\\,dx", cyan)],
    size=0.5,
  )
  equation.transition(limit, origin=@math.Vec3::new(0.65, 1.55), duration=1.2)
  hold(scene, phase, "黎曼和的极限，就是定积分", 1.8)
}

///|
fn riemann_bars(
  scene : @scene.Scene,
  plane : @coordinates.NumberPlane,
  count : Int32,
  color : @mobject.Color,
) -> Array[@mobject.ObjectId] raise {
  let ids : Array[@mobject.ObjectId] = []
  for index in 0..<count {
    let state = riemann_bar_state(plane, index, count, color)
    ids.push(scene.add(state))
  }
  ids
}

///|
fn riemann_bar_state(
  plane : @coordinates.NumberPlane,
  index : Int32,
  count : Int32,
  color : @mobject.Color,
) -> @mobject.ObjectState raise {
  let dx = 2.0 / count.to_double()
  let x = index.to_double() * dx
  let exact_height = x * x
  let height = exact_height.max(0.025)
  let center = plane.point(x + dx / 2.0, height / 2.0)
  let state = shape(
    @geometry.rectangle(dx * 2.15, height * 0.72),
    color,
    fill=0.18,
    width=1.2,
  )
  { ..state, transform: @math.Affine2::translation(center.x, center.y), }
}

///|
/// Each old interval contracts into its leftmost child while new right
/// subintervals are drawn. Nested left samples preserve the old height.
fn refine_riemann_bars(
  scene : @scene.Scene,
  phase : Ref[String],
  plane : @coordinates.NumberPlane,
  previous : Array[@mobject.ObjectId],
  old_count : Int32,
  color : @mobject.Color,
  new_count : Int32,
) -> Array[@mobject.ObjectId] raise {
  let next : Array[@mobject.ObjectId] = []
  let animations : Array[@animation.Animation] = []
  let factor = new_count / old_count
  for index in 0..<old_count {
    let first = index * factor
    let left_state = riemann_bar_state(plane, first, new_count, color)
    animations.push(@animation.transform(previous[index], left_state))
    next.push(previous[index])
    for offset in 1..<factor {
      let child = first + offset
      let right_state = riemann_bar_state(plane, child, new_count, color)
      let right_id = scene.add(right_state)
      animations.push(@animation.create(right_id))
      next.push(right_id)
    }
  }
  play(
    scene,
    phase,
    if new_count == 16 {
      "4 个旧矩形收缩，右侧子区间逐一显现"
    } else {
      "16 个旧矩形继续二分，矩形宽度减半"
    },
    animations,
    1.15,
  )
  next
}

///|
fn riemann_sum(
  assets : @text.TexAsset,
  count : Int32,
  amber : @mobject.Color,
  white : @mobject.Color,
) -> @text.MathTex raise {
  let subscript = if count == 4 {
    "{}_4"
  } else if count == 16 {
    "{}_{16}"
  } else {
    "{}_{32}"
  }
  let fraction = if count == 4 {
    "\\frac74"
  } else if count == 16 {
    "\\frac{155}{64}"
  } else {
    "\\frac{651}{256}"
  }
  spec(
    assets,
    [
      ("sum", "L", amber),
      ("subscript", subscript, amber),
      ("equals", "=", white),
      ("value", fraction, amber),
    ],
    size=0.68,
    gap=0.05,
  )
}
