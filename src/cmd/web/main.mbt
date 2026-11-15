///|
/// The browser supplies parameters; all geometry and SVG projection stay in MoonBit.
fn frame(
  mode : String,
  progress : Double,
  first : Double,
  second : Double,
  third : Double,
) -> String raise {
  let store = @mobject.Store::new()
  let blue = @mobject.Color::rgb(0.49, 0.62, 1.0)
  let teal = @mobject.Color::rgb(0.36, 0.79, 0.74)
  let amber = @mobject.Color::rgb(0.93, 0.70, 0.46)
  let muted = @mobject.Color::rgb(0.42, 0.47, 0.57)
  let white = @mobject.Color::rgb(0.90, 0.93, 0.98)
  let t = @math.clamp01(progress)
  let plane = @coordinates.NumberPlane::new(
    x_min=-6.0,
    x_max=6.0,
    y_min=-4.0,
    y_max=4.0,
  )
  let add = (path, color, fill, opacity, width, transform) => {
    ignore(
      store.add({
        ..@mobject.ObjectState::shape(path, style={
          ..@mobject.Style::default(),
          stroke: color,
          fill: color,
          fill_opacity: fill,
          opacity,
          stroke_width: width,
        }),
        transform,
      }),
    )
  }
  let identity = @math.Affine2::identity()
  add(plane.grid(), muted, 0.0, 0.14, 1.0, identity)
  add(plane.axes(), muted, 0.0, 0.35, 1.0, identity)
  let values : Map[String, @json.Json] = Map([])
  match mode {
    "matrix" => {
      let target = @math.Affine2::rotation(third * 3.141592653589793 / 180.0).compose({
          ..identity,
          c: first,
          d: second,
        },
      )
      let matrix : @math.Affine2 = {
        a: 1.0 + (target.a - 1.0) * t,
        b: target.b * t,
        c: target.c * t,
        d: 1.0 + (target.d - 1.0) * t,
        tx: 0.0,
        ty: 0.0,
      }
      add(plane.grid(), blue, 0.0, 0.34, 1.1, matrix)
      let unit = @geometry.polygon([
        @math.Vec3::zero(),
        @math.Vec3::new(1.0, 0.0),
        @math.Vec3::new(1.0, 1.0),
        @math.Vec3::new(0.0, 1.0),
      ])
      add(unit, white, 0.03, 0.25, 1.5, identity)
      add(unit, blue, 0.20, 1.0, 2.5, matrix)
      add(
        @geometry.arrow(@math.Vec3::zero(), @math.Vec3::new(1.0, 0.0)),
        teal,
        0.0,
        1.0,
        3.5,
        matrix,
      )
      add(
        @geometry.arrow(@math.Vec3::zero(), @math.Vec3::new(0.0, 1.0)),
        amber,
        0.0,
        1.0,
        3.5,
        matrix,
      )
      values["determinant"] = @json.Json::number(
        matrix.a * matrix.d - matrix.b * matrix.c,
      )
      values["a"] = @json.Json::number(matrix.a)
      values["b"] = @json.Json::number(matrix.b)
      values["c"] = @json.Json::number(matrix.c)
      values["d"] = @json.Json::number(matrix.d)
    }
    "bezier" => {
      let curve : @geometry.Cubic = {
        p0: @math.Vec3::new(-4.0, 0.0),
        p1: @math.Vec3::new(-2.5, first),
        p2: @math.Vec3::new(2.5, second),
        p3: @math.Vec3::new(4.0, 0.0),
      }
      let path = @geometry.Path::new([@geometry.Contour::new([curve])])
      let measure = path.measure()
      let polygon = @geometry.Path::new([
        @geometry.Contour::new([
          @geometry.Cubic::line(curve.p0, curve.p1),
          @geometry.Cubic::line(curve.p1, curve.p2),
          @geometry.Cubic::line(curve.p2, curve.p3),
        ]),
      ])
      add(polygon, muted, 0.0, 0.55, 1.5, identity)
      add(path, white, 0.0, 0.18, 3.0, identity)
      add(measure.partial(0.0, t), teal, 0.0, 1.0, 4.0, identity)
      for point in [curve.p0, curve.p1, curve.p2, curve.p3] {
        add(
          @geometry.circle(0.065),
          blue,
          1.0,
          1.0,
          1.0,
          @math.Affine2::translation(point.x, point.y),
        )
      }
      if measure.point_at(t) is Some(point) {
        add(
          @geometry.circle(0.10),
          teal,
          1.0,
          1.0,
          1.0,
          @math.Affine2::translation(point.x, point.y),
        )
      }
      values["length"] = @json.Json::number(measure.length)
      values["drawn"] = @json.Json::number(measure.length * t)
    }
    "pythagoras" => {
      let tiling = @teaching.Pythagoras::new(first, second)
      let scale = 5.4 / tiling.side
      let placement = @math.Affine2::translation(-2.7, -2.7).compose(
        @math.Affine2::scaling(scale, scale),
      )
      let eased = @animation.Easing::Smooth.sample(t)
      add(
        @geometry.rectangle(tiling.side, tiling.side),
        white,
        0.0,
        0.6,
        1.5,
        @math.Affine2::scaling(scale, scale),
      )
      add(
        tiling.c_square,
        blue,
        0.18,
        (1.0 - eased) * (1.0 - eased),
        2.5,
        placement,
      )
      add(tiling.a_square, teal, 0.22, eased * eased, 2.5, placement)
      add(tiling.b_square, blue, 0.22, eased * eased, 2.5, placement)
      let colors = [amber, teal, amber, teal]
      for i in 0..<4 {
        let offset = tiling.offsets[i].scale(eased)
        add(
          tiling.triangles[i],
          colors[i],
          0.20,
          0.95,
          2.0,
          placement.compose(@math.Affine2::translation(offset.x, offset.y)),
        )
      }
      values["a2"] = @json.Json::number(first * first)
      values["b2"] = @json.Json::number(second * second)
      values["c2"] = @json.Json::number(tiling.c * tiling.c)
    }
    "morph" => {
      let rotation = @math.Affine2::rotation(third)
      let morph = @geometry.PathMorph::new(
        @geometry.square(3.4),
        @geometry.circle(1.95),
      )
      add(@geometry.circle(2.8), muted, 0.0, 0.35, 1.0, identity)
      add(@geometry.circle(1.1), muted, 0.0, 0.26, 1.0, identity)
      add(morph.sample(t), blue, 0.12, 1.0, 2.0, rotation)
      add(
        morph.sample(1.0 - t),
        teal,
        0.06,
        0.9,
        1.8,
        @math.Affine2::rotation(-third).compose(
          @math.Affine2::scaling(0.65, 0.65),
        ),
      )
      for i in 0..<4 {
        let angle = third + i.to_double() * 1.5707963267948966
        let point = @math.Affine2::rotation(angle).apply(
          @math.Vec3::new(2.8, 0.0),
        )
        add(
          @geometry.circle(0.055),
          teal,
          1.0,
          1.0,
          1.0,
          @math.Affine2::translation(point.x, point.y),
        )
      }
    }
    _ => abort("unknown browser scene")
  }
  let camera = @render.Camera2D::new(
    pixel_width=960,
    pixel_height=600,
    frame_height=8.0,
    background=@mobject.Color::rgb(0.055, 0.071, 0.106),
  )
  let svg = @render.svg_frame(camera, {
    index: 0L,
    time: t,
    items: store.drawables(),
  })
  @json.Json::object({
    "svg": @json.Json::string(svg),
    "values": @json.Json::object(values),
  }).stringify()
}

///|
fn render(
  mode : String,
  progress : Double,
  first : Double,
  second : Double,
  third : Double,
) -> String {
  frame(mode, progress, first, second, third) catch {
    _ => "{\"error\":\"Invalid scene parameters\"}"
  }
}

///|
#cfg(target="js")
extern "js" fn install(
  callback : (String, Double, Double, Double, Double) -> String,
) -> Unit =
  #| (callback) => { globalThis.MoonManim = Object.freeze({ render: callback }); }

///|
#cfg(target="js")
fn main {
  install(render)
}

///|
#cfg(not(target="js"))
fn main {
  println(render("matrix", 1.0, 0.8, 1.2, 0.0))
}
