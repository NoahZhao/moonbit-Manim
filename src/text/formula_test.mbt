///|
fn asset() -> @text.TexAsset raise {
  let source =
    #|{"version":1,"glyphs":[
    #|{"tex":"x","advance":1,"contours":[{"closed":true,"segments":[[0,0,0.3,0,0.6,0,1,0],[1,0,0.6,0.3,0.3,0.6,0,1],[0,1,0,0.6,0,0.3,0,0]]}]},
    #|{"tex":"=","advance":1.2,"contours":[{"closed":false,"segments":[[0,0.5,0.3,0.5,0.6,0.5,1,0.5]]}]}
    #|]}
  @text.TexAsset::parse(source)
}

///|
priv struct TextRecorder {
  frames : Array[@render.Frame]
}

///|
impl @render.Renderer for TextRecorder with fn render(self, frame) {
  self.frames.push(frame)
}

///|
test "semantic formula matching retains repeated glyph identities across reordered terms" {
  let sink : TextRecorder = { frames: [], }
  let scene = @scene.Scene::new(sink, frame_rate=@timeline.FrameRate::new(4))
  let assets = asset()
  let x = assets.glyph("x")
  let equal = assets.glyph("=")
  let blue = @mobject.Color::blue()
  let pink = @mobject.Color::pink()
  let formula = @text.Formula::new(
    scene,
    @text.MathTex::new(
      [
        { key: "left", glyph: x, color: blue, },
        { key: "equal", glyph: equal, color: blue, },
        { key: "right", glyph: x, color: pink, },
      ],
      font_size=1.0,
      gap=0.1,
    ),
  )
  let left = formula.part("left")
  let right = formula.part("right")
  let removed = formula.part("equal")
  scene.play(
    [@animation.shift(formula.root, @math.Vec3::new(2.0, 0.0))],
    duration=0.0,
  )
  formula.transition(
    @text.MathTex::new(
      [
        { key: "right", glyph: x, color: pink, },
        { key: "left", glyph: x, color: pink, },
        { key: "new", glyph: equal, color: blue, },
      ],
      font_size=1.0,
      gap=0.1,
    ),
    duration=1.0,
  )
  @test.assert_eq(formula.part("left"), left)
  @test.assert_eq(formula.part("right"), right)
  @test.assert_eq(scene.contains(removed), false)
  @test.assert_eq(scene.get(left).transform.tx, 1.1)
  @test.assert_eq(scene.get(left).style.fill, pink)
  @test.assert_eq(scene.get(formula.root).transform.tx, 2.0)
  @test.assert_eq(sink.frames.length(), 4)
  @test.assert_eq(scene.snapshot().items.length(), 3)
}

///|
test "changed glyph for the same semantic key replaces rather than corrupts topology" {
  let sink : TextRecorder = { frames: [], }
  let scene = @scene.Scene::new(sink)
  let assets = asset()
  let formula = @text.Formula::new(
    scene,
    @text.MathTex::new([
      { key: "term", glyph: assets.glyph("x"), color: @mobject.Color::blue(), },
    ]),
  )
  let old = formula.part("term")
  formula.transition(
    @text.MathTex::new([
      { key: "term", glyph: assets.glyph("="), color: @mobject.Color::blue(), },
    ]),
    duration=0.0,
  )
  @test.assert_eq(formula.part("term") == old, false)
  @test.assert_eq(scene.contains(old), false)
  @test.assert_eq(scene.frame_index(), 0L)
}

///|
test "asset and formula validation reject malformed geometry and ambiguous keys" {
  @test.assert_raise(() => {
    @text.TexAsset::parse("{\"version\":2,\"glyphs\":[]}")
  })
  @test.assert_raise(() => {
    @text.TexAsset::parse(
      "{\"version\":1,\"glyphs\":[{\"tex\":\"x\",\"advance\":1,\"contours\":[{\"closed\":true,\"segments\":[[0,0]]}]}]}",
    )
  })
  let assets = asset()
  @test.assert_raise(() => assets.glyph("missing"))
  let part : @text.TexPart = {
    key: "x",
    glyph: assets.glyph("x"),
    color: @mobject.Color::blue(),
  }
  @test.assert_raise(() => @text.MathTex::new([part, part]))
}

///|
test "formula transition rejects an impossible duration before adding new fragments" {
  let sink : TextRecorder = { frames: [], }
  let scene = @scene.Scene::new(sink)
  let assets = asset()
  let part : @text.TexPart = {
    key: "old",
    glyph: assets.glyph("x"),
    color: @mobject.Color::blue(),
  }
  let formula = @text.Formula::new(scene, @text.MathTex::new([part]))
  let old = formula.part("old")
  @test.assert_raise(() => {
    formula.transition(
      @text.MathTex::new([{ ..part, key: "new", }]),
      duration=1.0e100,
    )
  })
  @test.assert_eq(scene.snapshot().items.length(), 1)
  @test.assert_eq(formula.part("old"), old)
  @test.assert_eq(scene.frame_index(), 0L)
}
