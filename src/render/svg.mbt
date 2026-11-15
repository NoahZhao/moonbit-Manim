///|
/// Reference vector backend for inspecting frames before a native raster backend is added.
pub struct SvgRenderer {
  priv camera : Camera2D
  priv output : (Int64, String) -> Unit raise
}

///|
/// Output is streamed per frame. The engine does not retain a full movie in memory.
pub fn SvgRenderer::new(
  camera : Camera2D,
  output : (Int64, String) -> Unit raise,
) -> SvgRenderer {
  { camera, output, }
}

///|
pub impl Renderer for SvgRenderer with fn render(self, frame) {
  (self.output)(frame.index, svg_frame(self.camera, frame))
}

///|
fn css(color : @mobject.Color) -> String {
  let r = (color.r * 255.0).round().to_int()
  let g = (color.g * 255.0).round().to_int()
  let b = (color.b * 255.0).round().to_int()
  "rgb(\{r},\{g},\{b})"
}

///|
/// All coordinates are projected into pixels before serialization, keeping stroke width constant.
pub fn svg_frame(
  camera : Camera2D,
  frame : Frame,
) -> String raise @errors.EngineError {
  let out = StringBuilder()
  out.write_string(
    "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"\{camera.pixel_width}\" height=\"\{camera.pixel_height}\" viewBox=\"0 0 \{camera.pixel_width} \{camera.pixel_height}\">\n",
  )
  out.write_string(
    "<rect width=\"100%\" height=\"100%\" fill=\"\{css(camera.background)}\"/>\n",
  )
  for item in frame.items {
    let d = StringBuilder()
    for contour in item.path.contours() {
      let segments = contour.segments()
      let start = camera.project(item.transform.apply(segments[0].p0))
      if !start.is_finite() {
        raise @errors.InvalidArgument("projected coordinates must be finite")
      }
      d.write_string("M \{start.x} \{start.y} ")
      for segment in segments {
        let a = camera.project(item.transform.apply(segment.p1))
        let b = camera.project(item.transform.apply(segment.p2))
        let end = camera.project(item.transform.apply(segment.p3))
        if !a.is_finite() || !b.is_finite() || !end.is_finite() {
          raise @errors.InvalidArgument("projected coordinates must be finite")
        }
        d.write_string("C \{a.x} \{a.y} \{b.x} \{b.y} \{end.x} \{end.y} ")
      }
      if contour.closed {
        d.write_string("Z ")
      }
    }
    let style = item.style
    let rule = match style.fill_rule {
      NonZero => "nonzero"
      EvenOdd => "evenodd"
    }
    out.write_string(
      "<path d=\"\{d.to_string()}\" fill=\"\{css(style.fill)}\" fill-opacity=\"\{style.fill_opacity}\" fill-rule=\"\{rule}\" stroke=\"\{css(style.stroke)}\" stroke-width=\"\{style.stroke_width}\" stroke-opacity=\"\{style.stroke_opacity}\" opacity=\"\{style.opacity}\" stroke-linecap=\"round\" stroke-linejoin=\"round\"/>\n",
    )
  }
  out.write_string("</svg>")
  out.to_string()
}
