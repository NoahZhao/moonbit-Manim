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

///|
/// A small, deterministic CNN pass: a 5x5 input, a moving 3x3 kernel and a
/// 3x3 feature map. The scene makes the receptive field and weighted sum
/// visible without pretending to train a model.
fn cnn_demo(scene : @scene.Scene, phase : Ref[String]) -> Unit raise {
  let cyan = @mobject.Color::rgb(0.33, 0.82, 0.92)
  let teal = @mobject.Color::rgb(0.32, 0.88, 0.68)
  let amber = @mobject.Color::rgb(1.0, 0.72, 0.34)
  let pink = @mobject.Color::rgb(1.0, 0.43, 0.66)
  let input_x = -4.6
  let input_y = 1.35
  let output_x = 2.0
  let output_y = 1.75
  let cell = 0.62
  let gap = 0.07
  let stride = cell + gap
  let grid_line = (x, y, color, opacity) => {
    let state = shape(
      @geometry.square(cell),
      color,
      fill=0.0,
      transform=@math.Affine2::translation(x, y),
    )
    { ..state, style: { ..state.style, stroke_width: 1.5, opacity, }, }
  }
  let input_cells : Array[@mobject.ObjectId] = []
  for row in 0..<5 {
    for col in 0..<5 {
      let value = ((row * 5 + col) % 5).to_double() / 5.0
      let id = scene.add(
        grid_line(
          input_x + col.to_double() * stride,
          input_y - row.to_double() * stride,
          cyan,
          0.28 + value * 0.42,
        ),
      )
      input_cells.push(id)
    }
  }
  let output_cells : Array[@mobject.ObjectId] = []
  let output_targets : Array[@mobject.ObjectState] = []
  for row in 0..<3 {
    for col in 0..<3 {
      let target = grid_line(
        output_x + col.to_double() * stride,
        output_y - row.to_double() * stride,
        teal,
        1.0,
      )
      let id = scene.add({ ..target, style: { ..target.style, opacity: 0.0, }, })
      output_cells.push(id)
      output_targets.push(target)
    }
  }
  let kernel = scene.add({
    ..shape(
      @geometry.square(cell * 3.0 + gap * 2.0),
      amber,
      fill=0.08,
      transform=@math.Affine2::translation(input_x + stride, input_y - stride),
    ),
    z_index: 5,
    style: {
      ..@mobject.Style::default(),
      stroke: amber,
      fill: amber,
      stroke_width: 4.0,
      fill_opacity: 0.08,
    },
  })
  hold(scene, phase, "A pixel grid enters the convolution layer", 0.6)
  play(
    scene,
    phase,
    "Input: 5 × 5 activation map",
    input_cells.map(id => @animation.fade_in(id)),
    0.8,
  )
  hold(
    scene, phase, "The kernel reads only a local 3 × 3 receptive field", 0.7,
  )
  play(scene, phase, "Kernel: 3 × 3 weights", [@animation.create(kernel)], 0.8)
  let positions = [
    @math.Vec3::new(input_x + stride, input_y - stride),
    @math.Vec3::new(input_x + stride * 2.0, input_y - stride),
    @math.Vec3::new(input_x + stride * 3.0, input_y - stride),
    @math.Vec3::new(input_x + stride, input_y - stride * 2.0),
    @math.Vec3::new(input_x + stride * 2.0, input_y - stride * 2.0),
    @math.Vec3::new(input_x + stride * 3.0, input_y - stride * 2.0),
    @math.Vec3::new(input_x + stride, input_y - stride * 3.0),
    @math.Vec3::new(input_x + stride * 2.0, input_y - stride * 3.0),
    @math.Vec3::new(input_x + stride * 3.0, input_y - stride * 3.0),
  ]
  for index in 0..<positions.length() {
    let row = index / 3
    let col = index % 3
    play(
      scene,
      phase,
      "Slide window: local multiply + sum → feature map[" +
      index.to_string() +
      "]",
      [
        @animation.shift(
          kernel,
          positions[index].sub(positions[(index - 1).max(0)]),
          easing=Linear,
        ),
        @animation.transform(
          output_cells[row * 3 + col],
          output_targets[row * 3 + col],
        ),
      ],
      0.55,
    )
  }
  let connector = scene.add({
    ..shape(
      @geometry.line(
        @math.Vec3::new(input_x + stride * 4.0, input_y - stride * 2.0),
        @math.Vec3::new(output_x - 0.45, output_y - stride * 1.0),
      ),
      pink,
    ),
    style: {
      ..@mobject.Style::default(),
      stroke: pink,
      stroke_width: 2.5,
      opacity: 0.0,
    },
  })
  play(
    scene,
    phase,
    "The local responses assemble into a feature map",
    [@animation.fade_in(connector)],
    0.6,
  )
  hold(
    scene, phase, "Convolution preserves structure while detecting a pattern", 0.9,
  )
  play(
    scene,
    phase,
    "One layer: input → kernel → activation map",
    [@animation.fade_out(kernel), @animation.fade_out(connector)],
    0.7,
  )
  hold(scene, phase, "Complete", 0.4)
}

///|
/// Continue a convolution pass through ReLU and 2x2 max pooling. The signed
/// response values are fixed so each visual selection has a reproducible result.
fn cnn_pool_demo(scene : @scene.Scene, phase : Ref[String]) -> Unit raise {
  let cyan = @mobject.Color::rgb(0.33, 0.82, 0.92)
  let teal = @mobject.Color::rgb(0.32, 0.88, 0.68)
  let amber = @mobject.Color::rgb(1.0, 0.72, 0.34)
  let pink = @mobject.Color::rgb(1.0, 0.43, 0.66)
  let muted = @mobject.Color::rgb(0.34, 0.43, 0.54)
  let cell = 0.54
  let gap = 0.08
  let stride = cell + gap
  let input_x = -5.5
  let input_y = 1.65
  let response_x = -0.65
  let response_y = 1.35
  let pooled_x = 4.0
  let pooled_y = 0.95
  let responses = [
    -1.0, 0.4, 1.2, -0.3, 0.2, 2.4, -1.3, 0.8, -0.6, 1.1, 3.1, 0.4, 0.7, -0.5, 0.9,
    2.2,
  ]
  let pooling_regions = [
    [0, 1, 4, 5],
    [2, 3, 6, 7],
    [8, 9, 12, 13],
    [10, 11, 14, 15],
  ]
  let pooled_values : Array[Double] = []
  for region in pooling_regions {
    let mut maximum = responses[region[0]]
    for index in 1..<region.length() {
      maximum = maximum.max(responses[region[index]])
    }
    pooled_values.push(maximum.max(0.0))
  }
  let activation = (x, y, value, color) => {
    let absolute = if value < 0.0 { -value } else { value }
    let magnitude = (absolute / 3.2).min(1.0)
    let state = shape(
      @geometry.square(cell),
      color,
      fill=0.12 + magnitude * 0.48,
      transform=@math.Affine2::translation(x, y),
    )
    { ..state, style: { ..state.style, opacity: 0.68 + magnitude * 0.32, }, }
  }
  let inputs : Array[@mobject.ObjectId] = []
  for row in 0..<6 {
    for col in 0..<6 {
      let intensity = ((row * 5 + col * 3) % 8).to_double() / 8.0
      let state = shape(
        @geometry.square(cell),
        cyan,
        fill=0.08 + intensity * 0.5,
        transform=@math.Affine2::translation(
          input_x + col.to_double() * stride,
          input_y - row.to_double() * stride,
        ),
      )
      let id = scene.add(state)
      inputs.push(id)
    }
  }
  let response_ids : Array[@mobject.ObjectId] = []
  let zero_states : Array[@mobject.ObjectState] = []
  let response_states : Array[@mobject.ObjectState] = []
  for index in 0..<responses.length() {
    let row = index / 4
    let col = index % 4
    let value = responses[index]
    let x = response_x + col.to_double() * stride
    let y = response_y - row.to_double() * stride
    let state = activation(x, y, value, if value < 0.0 { pink } else { teal })
    let zero_base = activation(x, y, 0.0, muted)
    let zero = {
      ..zero_base,
      style: { ..zero_base.style, opacity: 0.2, fill_opacity: 0.0, },
    }
    let id = scene.add({ ..state, style: { ..state.style, opacity: 0.0, }, })
    response_ids.push(id)
    zero_states.push(zero)
    response_states.push(state)
  }
  let pooled_ids : Array[@mobject.ObjectId] = []
  let pooled_states : Array[@mobject.ObjectState] = []
  for index in 0..<pooled_values.length() {
    let row = index / 2
    let col = index % 2
    let state = activation(
      pooled_x + col.to_double() * (cell + 0.22),
      pooled_y - row.to_double() * (cell + 0.22),
      pooled_values[index],
      teal,
    )
    let id = scene.add({ ..state, style: { ..state.style, opacity: 0.0, }, })
    pooled_ids.push(id)
    pooled_states.push(state)
  }
  hold(scene, phase, "卷积之后：查看带正负号的局部响应", 0.45)
  play(
    scene,
    phase,
    "输入：6 × 6 像素区域",
    inputs.map(id => @animation.fade_in(id)),
    0.65,
  )
  let conv_arrow = scene.add(
    shape(
      @geometry.arrow(@math.Vec3::new(-2.0, 0.0), @math.Vec3::new(-1.2, 0.0)),
      pink,
    ),
  )
  let show_responses : Array[@animation.Animation] = []
  show_responses.push(@animation.create(conv_arrow))
  for index in 0..<response_ids.length() {
    show_responses.push(
      @animation.transform(response_ids[index], response_states[index]),
    )
  }
  play(
    scene, phase, "卷积：每个位置产生一个有符号响应值", show_responses,
    0.8,
  )
  let relu_animations : Array[@animation.Animation] = []
  for index in 0..<responses.length() {
    if responses[index] < 0.0 {
      relu_animations.push(
        @animation.transform(response_ids[index], zero_states[index]),
      )
    }
  }
  play(
    scene, phase, "ReLU：max(0, z) 将负响应变为 0", relu_animations, 0.8,
  )
  let pool_arrow = scene.add(
    shape(
      @geometry.arrow(@math.Vec3::new(1.7, 0.0), @math.Vec3::new(3.35, 0.0)),
      pink,
    ),
  )
  play(
    scene,
    phase,
    "激活特征进入下采样",
    [@animation.create(pool_arrow)],
    0.3,
  )
  let window_size = cell * 2.0 + gap
  for index in 0..<pooling_regions.length() {
    let row = index / 2
    let col = index % 2
    let window_x = response_x + (col * 2).to_double() * stride + stride * 0.5
    let window_y = response_y - (row * 2).to_double() * stride - stride * 0.5
    let window = scene.add({
      ..shape(
        @geometry.square(window_size),
        amber,
        fill=0.025,
        transform=@math.Affine2::translation(window_x, window_y),
      ),
      z_index: 5,
    })
    let region = pooling_regions[index]
    let mut chosen = region[0]
    for candidate in region {
      if responses[candidate] > responses[chosen] {
        chosen = candidate
      }
    }
    let chosen_state = response_states[chosen]
    let highlighted = {
      ..chosen_state,
      style: { ..chosen_state.style, stroke: amber, stroke_width: 4.0, },
    }
    play(
      scene,
      phase,
      "最大池化：选出每个 2 × 2 窗口中的最大值",
      [
        @animation.create(window),
        @animation.transform(response_ids[chosen], highlighted),
        @animation.transform(pooled_ids[index], pooled_states[index]),
      ],
      0.45,
    )
    play(
      scene,
      phase,
      "步长为 2，每个窗口保留一个局部最大值",
      [
        @animation.fade_out(window),
        @animation.transform(response_ids[chosen], chosen_state),
      ],
      0.25,
    )
  }
  hold(scene, phase, "4 × 4 响应图压缩为 2 × 2 池化特征图", 1.2)
  let cleanup : Array[@animation.Animation] = []
  for id in inputs {
    cleanup.push(@animation.fade_out(id))
  }
  for id in response_ids {
    cleanup.push(@animation.fade_out(id))
  }
  play(scene, phase, "卷积 → ReLU → 最大池化", cleanup, 0.7)
  hold(scene, phase, "演示完成", 0.35)
}
