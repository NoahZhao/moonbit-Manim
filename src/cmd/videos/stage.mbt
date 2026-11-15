///|
fn add_grid(scene : @scene.Scene) -> Unit raise {
  for i in 0..<29 {
    let x = (i - 14).to_double() * 0.5
    let major = i % 2 == 0
    ignore(
      scene.add(
        @mobject.ObjectState::shape(
          @geometry.line(@math.Vec3::new(x, -4.0), @math.Vec3::new(x, 4.0)),
          style={
            ..@mobject.Style::default(),
            stroke_width: 1.0,
            opacity: if x == 0.0 {
              0.28
            } else if major {
              0.11
            } else {
              0.045
            },
          },
        ),
      ),
    )
  }
  for i in 0..<17 {
    let y = (i - 8).to_double() * 0.5
    ignore(
      scene.add(
        @mobject.ObjectState::shape(
          @geometry.line(@math.Vec3::new(-7.2, y), @math.Vec3::new(7.2, y)),
          style={
            ..@mobject.Style::default(),
            stroke_width: 1.0,
            opacity: if y == 0.0 {
              0.28
            } else if i % 2 == 0 {
              0.11
            } else {
              0.045
            },
          },
        ),
      ),
    )
  }
}

///|
fn shape(
  path : @geometry.Path,
  color : @mobject.Color,
  fill~ : Double = 0.0,
  transform~ : @math.Affine2 = @math.Affine2::identity(),
) -> @mobject.ObjectState {
  {
    ..@mobject.ObjectState::shape(path, style={
      ..@mobject.Style::default(),
      stroke: color,
      fill: color,
      stroke_width: 3.5,
      fill_opacity: fill,
    }),
    transform,
  }
}

///|
fn triangle(radius : Double) -> @geometry.Path raise {
  let a = @math.Vec3::new(radius, 0.0)
  let b = @math.Vec3::new(-radius * 0.5, radius * 0.8660254037844386)
  let c = @math.Vec3::new(-radius * 0.5, -radius * 0.8660254037844386)
  @geometry.Path::new([
    @geometry.Contour::new(
      [
        @geometry.Cubic::line(a, b),
        @geometry.Cubic::line(b, c),
        @geometry.Cubic::line(c, a),
      ],
      closed=true,
    ),
  ])
}

///|
fn play(
  scene : @scene.Scene,
  phase : Ref[String],
  label : String,
  animations : Array[@animation.Animation],
  duration : Double,
) -> Unit raise {
  phase.val = label
  scene.play(animations, duration~)
}

///|
fn hold(
  scene : @scene.Scene,
  phase : Ref[String],
  label : String,
  duration : Double,
) -> Unit raise {
  phase.val = label
  scene.wait(duration)
}
