///|
#derive(@json.FromJson)
priv struct WireContour {
  closed : Bool
  segments : Array[Array[Double]]
}

///|
#derive(@json.FromJson)
priv struct WireGlyph {
  tex : String
  advance : Double
  contours : Array[WireContour]
}

///|
#derive(@json.FromJson)
priv struct WireAsset {
  version : Int32
  glyphs : Array[WireGlyph]
}

///|
/// One independently addressable TeX fragment in em units, with baseline y=0.
pub struct TexGlyph {
  tex : String
  advance : Double
  path : @geometry.Path
}

///|
/// Backend-independent vector assets; no browser, TeX process or font at runtime.
pub struct TexAsset {
  priv glyphs : ReadOnlyArray[TexGlyph]
}

///|
pub fn TexAsset::parse(source : String) -> TexAsset raise {
  let wire : WireAsset = @json.from_json(@json.parse(source))
  if wire.version != 1 {
    raise @errors.InvalidArgument("unsupported TeX asset version")
  }
  let glyphs : Array[TexGlyph] = []
  for glyph in wire.glyphs {
    if glyph.tex.is_empty() ||
      !@math.finite(glyph.advance) ||
      glyph.advance <= 0.0 ||
      glyphs.any(g => g.tex == glyph.tex) {
      raise @errors.InvalidArgument(
        "TeX assets require unique sources and positive finite advances",
      )
    }
    let contours : Array[@geometry.Contour] = []
    for contour in glyph.contours {
      let segments : Array[@geometry.Cubic] = []
      for c in contour.segments {
        if c.length() != 8 {
          raise @errors.InvalidArgument(
            "asset cubics require eight coordinates",
          )
        }
        segments.push({
          p0: @math.Vec3::new(c[0], c[1]),
          p1: @math.Vec3::new(c[2], c[3]),
          p2: @math.Vec3::new(c[4], c[5]),
          p3: @math.Vec3::new(c[6], c[7]),
        })
      }
      contours.push(@geometry.Contour::new(segments, closed=contour.closed))
    }
    glyphs.push({
      tex: glyph.tex,
      advance: glyph.advance,
      path: @geometry.Path::new(contours),
    })
  }
  { glyphs: ReadOnlyArray::from_array(glyphs), }
}

///|
pub fn TexAsset::glyph(
  self : TexAsset,
  tex : String,
) -> TexGlyph raise @errors.EngineError {
  for glyph in self.glyphs {
    if glyph.tex == tex {
      return glyph
    }
  }
  raise @errors.InvalidArgument(
    "TeX fragment is absent from the compiled asset: " + tex,
  )
}
