///|
fn white() -> @mobject.Color raise {
  @mobject.Color::rgb(0.92, 0.95, 0.99)
}

///|
fn yellow() -> @mobject.Color raise {
  @mobject.Color::rgb(1.0, 0.83, 0.36)
}

///|
fn green() -> @mobject.Color raise {
  @mobject.Color::rgb(0.45, 0.84, 0.62)
}

///|
fn shape(
  path : @geometry.Path,
  color : @mobject.Color,
  fill~ : Double = 0.0,
  opacity~ : Double = 1.0,
  width~ : Double = 3.0,
) -> @mobject.ObjectState {
  @mobject.ObjectState::shape(path, style={
    ..@mobject.Style::default(),
    stroke: color,
    fill: color,
    fill_opacity: fill,
    opacity,
    stroke_width: width,
  })
}

///|
fn spec(
  assets : @text.TexAsset,
  terms : Array[(String, String, @mobject.Color)],
  size~ : Double = 0.65,
  gap~ : Double = 0.12,
) -> @text.MathTex raise {
  @text.MathTex::new(
    terms.map(term => {
      let (key, tex, color) = term
      { key, glyph: assets.glyph(tex), color, }
    }),
    font_size=size,
    gap~,
  )
}

///|
fn label(
  scene : @scene.Scene,
  assets : @text.TexAsset,
  tex : String,
  x : Double,
  y : Double,
  color : @mobject.Color,
  size~ : Double = 0.5,
) -> @text.Formula raise {
  let text = spec(assets, [("label", tex, color)], size~)
  @text.Formula::new(
    scene,
    text,
    origin=@math.Vec3::new(x - text.width / 2.0, y),
  )
}

///|
fn hold(
  scene : @scene.Scene,
  phase : Ref[String],
  message : String,
  duration : Double,
) -> Unit raise {
  phase.val = message
  scene.wait(duration)
}

///|
fn play(
  scene : @scene.Scene,
  phase : Ref[String],
  message : String,
  animations : Array[@animation.Animation],
  duration : Double,
) -> Unit raise {
  phase.val = message
  scene.play(animations, duration~)
}

///|
fn about(matrix : @math.Affine2, x : Double, y : Double) -> @math.Affine2 {
  @math.Affine2::translation(x, y)
  .compose(matrix)
  .compose(@math.Affine2::translation(-x, -y))
}
