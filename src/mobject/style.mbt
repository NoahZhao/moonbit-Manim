///|
/// Straight-alpha sRGB color channels; conversion is a renderer responsibility.
#derive(Eq, @debug.Debug)
pub struct Color {
  r : Double
  g : Double
  b : Double
}

///|
pub fn Color::rgb(
  r : Double,
  g : Double,
  b : Double,
) -> Color raise @errors.EngineError {
  if !unit_interval(r) || !unit_interval(g) || !unit_interval(b) {
    raise @errors.InvalidArgument(
      "color channels must be finite and within [0,1]",
    )
  }
  { r, g, b, }
}

///|
pub fn Color::blue() -> Color {
  { r: 0.345, g: 0.769, b: 0.867, }
}

///|
pub fn Color::pink() -> Color {
  { r: 0.82, g: 0.278, b: 0.741, }
}

///|
pub fn Color::black() -> Color {
  { r: 0.0, g: 0.0, b: 0.0, }
}

///|
/// Explicit sRGB-channel interpolation in the initial style policy.
pub fn Color::lerp(self : Color, target : Color, alpha : Double) -> Color {
  let t = @math.clamp01(alpha)
  {
    r: self.r * (1.0 - t) + target.r * t,
    g: self.g * (1.0 - t) + target.g * t,
    b: self.b * (1.0 - t) + target.b * t,
  }
}

///|
fn unit_interval(value : Double) -> Bool {
  @math.finite(value) && value >= 0.0 && value <= 1.0
}

///|
#derive(Eq, @debug.Debug)
pub(all) enum FillRule {
  NonZero
  EvenOdd
}

///|
/// stroke_width is in output pixels and does not scale with the object or camera.
#derive(Eq, @debug.Debug)
pub(all) struct Style {
  stroke : Color
  fill : Color
  stroke_width : Double
  stroke_opacity : Double
  fill_opacity : Double
  opacity : Double
  fill_rule : FillRule
}

///|
pub fn Style::default() -> Style {
  {
    stroke: Color::blue(),
    fill: Color::blue(),
    stroke_width: 3.0,
    stroke_opacity: 1.0,
    fill_opacity: 0.0,
    opacity: 1.0,
    fill_rule: NonZero,
  }
}

///|
pub fn Style::validate(self : Style) -> Unit raise @errors.EngineError {
  if !@math.finite(self.stroke_width) ||
    self.stroke_width < 0.0 ||
    !unit_interval(self.stroke_opacity) ||
    !unit_interval(self.fill_opacity) ||
    !unit_interval(self.opacity) {
    raise @errors.InvalidArgument("invalid stroke width or opacity")
  }
}

///|
/// Fill rule switches only at completion; it is a discrete property.
pub fn Style::lerp(self : Style, target : Style, alpha : Double) -> Style {
  let t = @math.clamp01(alpha)
  if t == 0.0 {
    return self
  }
  if t == 1.0 {
    return target
  }
  {
    stroke: self.stroke.lerp(target.stroke, t),
    fill: self.fill.lerp(target.fill, t),
    stroke_width: self.stroke_width * (1.0 - t) + target.stroke_width * t,
    stroke_opacity: self.stroke_opacity * (1.0 - t) + target.stroke_opacity * t,
    fill_opacity: self.fill_opacity * (1.0 - t) + target.fill_opacity * t,
    opacity: self.opacity * (1.0 - t) + target.opacity * t,
    fill_rule: self.fill_rule,
  }
}
