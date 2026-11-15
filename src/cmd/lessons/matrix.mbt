///|
fn linear_algebra(
  scene : @scene.Scene,
  assets : @text.TexAsset,
  phase : Ref[String],
) -> Unit raise {
  let blue = @mobject.Color::blue()
  let yellow = yellow()
  let pink = @mobject.Color::pink()
  let origin = @math.Vec3::new(-2.0, -0.35)
  let plane = @coordinates.NumberPlane::new(
    x_min=-3.0,
    x_max=3.0,
    y_min=-2.0,
    y_max=2.0,
    transform=@math.Affine2::scaling(0.7, 0.7),
  )
  let group = scene.add({
    ..@mobject.ObjectState::group(),
    transform: @math.Affine2::translation(origin.x, origin.y),
  })
  ignore(
    scene.add({
      ..shape(plane.grid(step=0.5), white(), opacity=0.07, width=1.0),
      transform: @math.Affine2::translation(origin.x, origin.y),
    }),
  )
  let elements : Array[@mobject.ObjectId] = []
  for
    state in [
      shape(plane.grid(), blue, opacity=0.3, width=1.1),
      shape(plane.axes(), white(), opacity=0.65, width=1.5),
      shape(
        @geometry.polygon([
          plane.point(0.0, 0.0),
          plane.point(1.0, 0.0),
          plane.point(1.0, 1.0),
          plane.point(0.0, 1.0),
        ]),
        pink,
        fill=0.3,
        width=2.0,
      ),
      shape(
        @geometry.arrow(plane.point(0.0, 0.0), plane.point(1.0, 0.0)),
        yellow,
        width=4.0,
      ),
      shape(
        @geometry.arrow(plane.point(0.0, 0.0), plane.point(0.0, 1.0)),
        green(),
        width=4.0,
      ),
    ] {
    let id = scene.add(state)
    scene.reparent(id, Some(group))
    elements.push(id)
  }
  phase.val = "两根基向量确定整个坐标平面；粉色区域是一个单位正方形"
  scene.play_staggered(
    elements.map(id => @animation.create(id)),
    duration=2.0,
    lag_ratio=0.12,
  )
  let matrix = @text.Formula::new(
    scene,
    spec(
      assets,
      [
        ("name", "A", blue),
        ("eq", "=", white()),
        ("matrix", "\\begin{pmatrix}1&1\\\\0&1\\end{pmatrix}", white()),
      ],
      size=0.64,
    ),
    origin=@math.Vec3::new(2.25, 1.0),
  )
  matrix.write(duration=1.7)
  let determinant = label(
    scene,
    assets,
    "\\det A=1",
    3.9,
    -0.5,
    pink,
    size=0.54,
  )
  determinant.write(duration=1.0)
  hold(
    scene, phase, "矩阵的两列，就是两根基向量变换后的坐标", 0.8,
  )
  let shear : @math.Affine2 = { ..@math.Affine2::identity(), c: 1.0, }
  play(
    scene,
    phase,
    "剪切：竖直基向量向右倾斜，平行线仍然平行",
    [@animation.apply_affine(group, about(shear, origin.x, origin.y))],
    3.0,
  )
  hold(
    scene, phase, "正方形变为平行四边形；底和高不变，所以面积不变",
    1.8,
  )
  phase.val = "接着把竖直方向拉长到 3/2 倍"
  matrix.transition(
    spec(
      assets,
      [
        ("name", "B", blue),
        ("eq", "=", white()),
        ("matrix", "\\begin{pmatrix}1&1\\\\0&\\frac32\\end{pmatrix}", white()),
      ],
      size=0.64,
    ),
    origin=@math.Vec3::new(2.25, 1.0),
    duration=1.2,
  )
  determinant.transition(
    spec(assets, [("label", "\\det B=\\frac{3}{2}", pink)], size=0.54),
    origin=@math.Vec3::new(2.75, -0.5),
    duration=1.0,
  )
  play(
    scene,
    phase,
    "面积随高度增大到 3/2 倍，这正是行列式的几何意义",
    [
      @animation.apply_affine(
        group,
        about(@math.Affine2::scaling(1.0, 1.5), origin.x, origin.y),
      ),
    ],
    3.0,
  )
  hold(
    scene, phase, "网格、基向量和面积区域使用同一组矩阵变换",
    2.5,
  )
}
