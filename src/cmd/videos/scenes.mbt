///|
fn morph_demo(scene : @scene.Scene, phase : Ref[String]) -> Unit raise {
  let blue = @mobject.Color::blue()
  let pink = @mobject.Color::pink()
  let yellow = @mobject.Color::rgb(1.0, 0.83, 0.36)
  hold(scene, phase, "One object, continuous geometric transformations", 0.4)
  let square = shape(@geometry.square(2.6), blue, fill=0.08)
  let object = scene.add(square)
  play(
    scene,
    phase,
    "Create: draw the square boundary",
    [@animation.create(object)],
    1.4,
  )
  hold(scene, phase, "Square", 0.35)
  play(
    scene,
    phase,
    "Transform: square to circle",
    [
      @animation.transform(
        object,
        shape(@geometry.circle(1.3), pink, fill=0.15),
      ),
    ],
    1.7,
  )
  hold(scene, phase, "Circle", 0.35)
  play(
    scene,
    phase,
    "Transform: circle to triangle",
    [@animation.transform(object, shape(triangle(1.65), yellow, fill=0.12))],
    1.7,
  )
  hold(scene, phase, "Triangle", 0.35)
  play(
    scene,
    phase,
    "Rotate: a full turn with rigid geometry",
    [@animation.rotate(object, 6.283185307179586, easing=Linear)],
    2.0,
  )
  play(
    scene,
    phase,
    "Transform: return to the original square",
    [@animation.transform(object, square)],
    1.4,
  )
  play(
    scene,
    phase,
    "Fade out and remove the object",
    [@animation.fade_out(object)],
    0.7,
  )
  hold(scene, phase, "Complete", 0.4)
}

///|
fn create_demo(scene : @scene.Scene, phase : Ref[String]) -> Unit raise {
  let yellow = @mobject.Color::rgb(1.0, 0.83, 0.36)
  let start = @math.Vec3::new(-4.0, 1.7)
  let paths = [
    @geometry.Path::new([
      @geometry.Contour::new([
        { p0: start, p1: start, p2: start, p3: @math.Vec3::new(4.0, 1.7), },
      ]),
    ]),
    @geometry.Path::new([
      @geometry.Contour::new([
        {
          p0: @math.Vec3::new(-4.0, 0.0),
          p1: @math.Vec3::new(-2.0, 2.0),
          p2: @math.Vec3::new(2.0, -2.0),
          p3: @math.Vec3::new(4.0, 0.0),
        },
      ]),
    ]),
    @geometry.Path::new([
      @geometry.Contour::new([
        {
          p0: @math.Vec3::new(-4.0, -1.7),
          p1: @math.Vec3::new(-3.0, -0.5),
          p2: @math.Vec3::new(-2.0, -2.9),
          p3: @math.Vec3::new(-1.0, -1.7),
        },
      ]),
      @geometry.Contour::new([
        {
          p0: @math.Vec3::new(1.0, -1.7),
          p1: @math.Vec3::new(2.0, -0.5),
          p2: @math.Vec3::new(3.0, -2.9),
          p3: @math.Vec3::new(4.0, -1.7),
        },
      ]),
    ]),
  ]
  let colors = [yellow, @mobject.Color::blue(), @mobject.Color::pink()]
  let states : Array[@mobject.ObjectState] = []
  for i in 0..<paths.length() {
    let state = shape(paths[i], colors[i])
    states.push(state)
    ignore(
      scene.add({
        ..state,
        style: { ..state.style, opacity: 0.14, stroke_width: 2.0, },
      }),
    )
  }
  hold(scene, phase, "Straight, curved and disconnected vector paths", 0.4)
  let first = states.map(state => scene.add(state))
  play(
    scene,
    phase,
    "Linear: equal arc length in equal time",
    first.map(id => @animation.create(id, easing=Linear)),
    2.8,
  )
  hold(
    scene, phase, "No connector is added across the gap in the pink path", 0.5,
  )
  play(
    scene,
    phase,
    "Reset the foreground strokes",
    first.map(id => @animation.fade_out(id)),
    0.5,
  )
  let second = states.map(state => scene.add(state))
  play(
    scene,
    phase,
    "Smooth: accelerate and decelerate along the same geometry",
    second.map(id => @animation.create(id)),
    2.8,
  )
  hold(scene, phase, "Exact original paths restored on completion", 0.8)
  play(scene, phase, "Fade out", second.map(id => @animation.fade_out(id)), 0.6)
  hold(scene, phase, "Complete", 0.4)
}

///|
fn groups_demo(scene : @scene.Scene, phase : Ref[String]) -> Unit raise {
  let blue = @mobject.Color::blue()
  let pink = @mobject.Color::pink()
  let yellow = @mobject.Color::rgb(1.0, 0.83, 0.36)
  let green = @mobject.Color::rgb(0.45, 0.84, 0.62)
  let ring = shape(@geometry.circle(2.2), blue)
  ignore(
    scene.add({
      ..ring,
      style: { ..ring.style, opacity: 0.12, stroke_width: 1.0, },
    }),
  )
  hold(scene, phase, "Several objects share one parent transform", 0.4)
  let group = scene.add(@mobject.ObjectState::group())
  let nested = scene.add({
    ..@mobject.ObjectState::group(),
    transform: @math.Affine2::translation(2.2, 0.0)
    .compose(@math.Affine2::rotation(0.35))
    .compose(@math.Affine2::scaling(0.8, 0.8)),
  })
  scene.reparent(nested, Some(group))
  let nodes : Array[@mobject.ObjectId] = []
  let positions = [
    @math.Vec3::new(2.2, 0.0),
    @math.Vec3::new(0.0, 2.2),
    @math.Vec3::new(-2.2, 0.0),
    @math.Vec3::new(0.0, -2.2),
  ]
  for position in positions {
    let spoke = shape(@geometry.line(@math.Vec3::zero(), position), blue)
    let id = scene.add({
      ..spoke,
      style: { ..spoke.style, opacity: 0.38, stroke_width: 1.5, },
    })
    scene.reparent(id, Some(group))
    nodes.push(id)
  }
  let satellite = scene.add(shape(@geometry.square(1.0), pink, fill=0.1))
  let inner = scene.add(shape(@geometry.circle(0.26), yellow))
  scene.reparent(satellite, Some(nested))
  scene.reparent(inner, Some(nested))
  nodes.push(satellite)
  nodes.push(inner)
  let outer_states = [
    shape(
      @geometry.circle(0.45),
      blue,
      fill=0.12,
      transform=@math.Affine2::translation(0.0, 2.2),
    ),
    shape(
      triangle(0.58),
      yellow,
      fill=0.1,
      transform=@math.Affine2::translation(-2.2, 0.0),
    ),
    shape(
      @geometry.square(0.8),
      green,
      fill=0.1,
      transform=@math.Affine2::translation(0.0, -2.2).compose(
        @math.Affine2::rotation(0.7853981633974483),
      ),
    ),
    shape(@geometry.circle(0.16), yellow, fill=0.2),
  ]
  for state in outer_states {
    let id = scene.add(state)
    scene.reparent(id, Some(group))
    nodes.push(id)
  }
  play(
    scene,
    phase,
    "Create sibling paths in parallel, including a nested group",
    nodes.map(id => @animation.create(id)),
    2.0,
  )
  play(
    scene,
    phase,
    "Rotate the parent: all children retain their relative geometry",
    [@animation.rotate(group, 6.283185307179586, easing=Linear)],
    3.2,
  )
  hold(scene, phase, "Nested transforms compose with the parent transform", 0.4)
  play(
    scene,
    phase,
    "Shift the complete group to the left",
    [@animation.shift(group, @math.Vec3::new(-1.8, 0.0))],
    1.2,
  )
  play(
    scene,
    phase,
    "Rotate around the translated group center",
    [
      @animation.rotate(
        group,
        -3.141592653589793,
        pivot=@math.Vec3::new(-1.8, 0.0),
      ),
    ],
    1.4,
  )
  play(
    scene,
    phase,
    "Shift the complete group to the right",
    [@animation.shift(group, @math.Vec3::new(3.6, 0.0))],
    1.2,
  )
  play(
    scene,
    phase,
    "Parent opacity fades the entire subtree",
    [@animation.fade_out(group)],
    0.8,
  )
  hold(scene, phase, "Complete", 0.4)
}
