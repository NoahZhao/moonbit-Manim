///|
fn pythagoras(
  scene : @scene.Scene,
  assets : @text.TexAsset,
  phase : Ref[String],
) -> Unit raise {
  let tiling = @teaching.Pythagoras::new(2.0, 3.0)
  let blue = @mobject.Color::blue()
  let yellow = yellow()
  let pink = @mobject.Color::pink()
  let white = white()
  let scale = 0.8
  let placement = @math.Affine2::translation(-5.8, -1.9).compose(
    @math.Affine2::scaling(scale, scale),
  )
  let outer = scene.add(
    shape(
      @geometry.rectangle(tiling.side, tiling.side)
      .transformed(
        @math.Affine2::translation(tiling.side / 2.0, tiling.side / 2.0),
      )
      .transformed(placement),
      white,
      width=2.0,
    ),
  )
  play(
    scene,
    phase,
    "构造边长 a + b 的大正方形，放入四个全等直角三角形",
    [@animation.create(outer)],
    1.0,
  )
  let triangles : Array[@mobject.ObjectId] = []
  let colors = [blue, green(), blue, green()]
  for i in 0..<4 {
    triangles.push(
      scene.add(
        shape(
          tiling.triangles[i].transformed(placement),
          colors[i],
          fill=0.28,
          width=2.0,
        ),
      ),
    )
  }
  scene.play_staggered(
    triangles.map(id => @animation.create(id)),
    duration=1.8,
    lag_ratio=0.2,
  )
  let c_square = scene.add(
    shape(tiling.c_square.transformed(placement), pink, fill=0.2, width=2.5),
  )
  play(
    scene,
    phase,
    "中间的四条边都是斜边 c；四个角都是直角，所以中间是面积 c² 的正方形",
    [@animation.fade_in(c_square)],
    1.0,
  )
  let c_label = label(scene, assets, "c^2", -3.8, -0.05, pink, size=0.62)
  c_label.write(duration=1.0)
  hold(
    scene, phase, "大正方形面积 = 四个三角形面积 + 中间正方形面积",
    1.0,
  )
  let equation = @text.Formula::new(
    scene,
    spec(
      assets,
      [
        ("outer", "(a+b)^2", white),
        ("eq", "=", white),
        ("triangles", "4\\cdot\\frac{ab}{2}", blue),
        ("right-plus", "+", white),
        ("c2", "c^2", pink),
      ],
      size=0.44,
      gap=0.10,
    ),
    origin=@math.Vec3::new(0.1, 1.0),
  )
  phase.val = "把同一幅面积图写成等式"
  equation.write(duration=2.0)
  play(
    scene,
    phase,
    "只平移三角形，既不旋转缩放，也不改变面积",
    [@animation.fade_out(c_square), @animation.fade_out(c_label.root)],
    0.8,
  )
  play(
    scene,
    phase,
    "四个三角形重新拼合，留出边长分别为 a、b 的两个正方形",
    triangles.mapi((i, id) => {
      @animation.shift(id, tiling.offsets[i].scale(scale))
    }),
    3.0,
  )
  let a_square = scene.add(
    shape(tiling.a_square.transformed(placement), yellow, fill=0.24, width=2.5),
  )
  let b_square = scene.add(
    shape(tiling.b_square.transformed(placement), pink, fill=0.18, width=2.5),
  )
  play(
    scene,
    phase,
    "相同的大正方形，减去相同的四个三角形，剩余面积必然相等",
    [@animation.fade_in(a_square), @animation.fade_in(b_square)],
    1.0,
  )
  let a_label = label(scene, assets, "a^2", -5.0, -1.3, yellow, size=0.55)
  let b_label = label(scene, assets, "b^2", -3.0, 0.55, pink, size=0.65)
  a_label.write(duration=0.7)
  b_label.write(duration=0.8)
  phase.val = "展开等式左边，并合并右边的四个三角形面积"
  equation.transition(
    spec(
      assets,
      [
        ("a2", "a^2", yellow),
        ("left-plus", "+", white),
        ("left-cross", "2ab", blue),
        ("mid-plus", "+", white),
        ("b2", "b^2", pink),
        ("eq", "=", white),
        ("right-cross", "2ab", blue),
        ("right-plus", "+", white),
        ("c2", "c^2", pink),
      ],
      size=0.42,
      gap=0.08,
    ),
    origin=@math.Vec3::new(0.1, 1.0),
    duration=1.5,
  )
  hold(scene, phase, "等式两边消去同样的 2ab", 1.2)
  equation.transition(
    spec(
      assets,
      [
        ("a2", "a^2", yellow),
        ("mid-plus", "+", white),
        ("b2", "b^2", pink),
        ("eq", "=", white),
        ("c2", "c^2", pink),
      ],
      size=0.65,
      gap=0.14,
    ),
    origin=@math.Vec3::new(0.6, 0.9),
    duration=1.5,
  )
  hold(
    scene, phase, "勾股定理：a² + b² = c²；同一重排对任意正的 a、b 成立",
    3.0,
  )
}
