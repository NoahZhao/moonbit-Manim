///|
/// Complete the square, then check both real roots against the plotted polynomial.
fn quadratic(
  scene : @scene.Scene,
  assets : @text.TexAsset,
  phase : Ref[String],
) -> Unit raise {
  let blue = @mobject.Color::blue()
  let pink = @mobject.Color::pink()
  let yellow = yellow()
  let white = white()
  let plane = @coordinates.NumberPlane::new(
    x_min=-8.5,
    x_max=2.5,
    y_min=-18.0,
    y_max=24.0,
    transform=@math.Affine2::translation(1.8, -1.0).compose(
      @math.Affine2::scaling(0.62, 0.06),
    ),
  )
  let axes = scene.add(shape(plane.axes(), white, opacity=0.35, width=1.5))
  let graph = scene.add(
    shape(plane.plot(x => Some(x * x + 6.0 * x - 7.0)), blue, width=3.5),
  )
  play(
    scene,
    phase,
    "把方程的两个根，看成抛物线与横轴的交点",
    [@animation.create(axes), @animation.create(graph)],
    2.0,
  )
  let curve_label = label(
    scene,
    assets,
    "y=x^2+6x-7",
    0.1,
    -2.4,
    blue,
    size=0.33,
  )
  curve_label.write(duration=0.8)
  let initial = spec(assets, [
    ("x2", "x^2", blue),
    ("plus6", "+", white),
    ("sixx", "6x", blue),
    ("eq", "=", white),
    ("rhs", "7", yellow),
  ])
  let equation = @text.Formula::new(
    scene,
    initial,
    origin=@math.Vec3::new(-initial.width / 2.0, 1.65),
  )
  phase.val = "配方法：从 x² + 6x = 7 开始"
  equation.write(duration=1.8)
  hold(scene, phase, "等式两边同时加 9，保持等式成立", 1.0)
  let completed = spec(assets, [
    ("x2", "x^2", blue),
    ("plus6", "+", white),
    ("sixx", "6x", blue),
    ("plus9", "+", yellow),
    ("nine", "9", yellow),
    ("eq", "=", white),
    ("rhs", "16", yellow),
  ])
  equation.transition(
    completed,
    origin=@math.Vec3::new(-completed.width / 2.0, 1.65),
    duration=1.5,
  )
  hold(scene, phase, "左边成为完全平方：x² + 6x + 9 = (x + 3)²", 1.4)
  let square = spec(assets, [
    ("square", "(x+3)^2", blue),
    ("eq", "=", white),
    ("rhs", "16", yellow),
  ])
  equation.transition(
    square,
    origin=@math.Vec3::new(-square.width / 2.0, 1.65),
    duration=1.5,
  )
  hold(scene, phase, "开平方时，必须保留正负两种可能", 1.4)
  let root = spec(assets, [
    ("left", "x+3", blue),
    ("eq", "=", white),
    ("rhs", "\\pm4", yellow),
  ])
  equation.transition(
    root,
    origin=@math.Vec3::new(-root.width / 2.0, 1.65),
    duration=1.5,
  )
  hold(scene, phase, "再减去 3，得到两个解", 1.2)
  let result = spec(
    assets,
    [
      ("x-left", "x", blue),
      ("eq", "=", white),
      ("positive", "1", yellow),
      ("or", "\\text{or}", white),
      ("x-right", "x", blue),
      ("eq-right", "=", white),
      ("negative", "-7", pink),
    ],
    gap=0.18,
  )
  equation.transition(
    result,
    origin=@math.Vec3::new(-result.width / 2.0, 1.65),
    duration=1.5,
  )
  let roots : Array[@animation.Animation] = []
  for (x, color) in [(1.0, yellow), (-7.0, pink)] {
    let p = plane.point(x, 0.0)
    let dot = scene.add({
      ..shape(@geometry.circle(0.09), color, fill=1.0, width=1.5),
      transform: @math.Affine2::translation(p.x, p.y),
    })
    roots.push(@animation.fade_in(dot))
    let tag = label(
      scene,
      assets,
      if x == 1.0 {
        "1"
      } else {
        "-7"
      },
      p.x,
      p.y - 0.48,
      color,
      size=0.38,
    )
    roots.push(@animation.fade_in(tag.root))
  }
  play(
    scene, phase, "代回验证：1² + 6·1 − 7 = 0；(−7)² + 6·(−7) − 7 = 0",
    roots, 1.2,
  )
  hold(scene, phase, "代数推导与图像交点给出一致的结果", 2.5)
}
