///|
fn area(path : @geometry.Path) -> Double {
  let mut total = 0.0
  for c in path.contours()[0].segments() {
    total += c.p0.x * c.p3.y - c.p3.x * c.p0.y
  }
  total.abs() / 2.0
}

///|
fn inside(path : @geometry.Path, p : @math.Vec3) -> Bool {
  // All lesson polygons are convex and counter-clockwise.
  path.contours()[0]
  .segments()
  .all(c => c.p3.sub(c.p0).cross(p.sub(c.p0)).z > 0.0)
}

///|
test "Pythagoras tilings have equal area and cover the outer square without overlap" {
  for (a, b) in [(2.0, 3.0), (1.0, 1.0), (0.7, 2.3)] {
    let tiling = @teaching.Pythagoras::new(a, b)
    @test.assert_eq(area(tiling.c_square).is_close(a * a + b * b), true)
    @test.assert_eq(area(tiling.a_square).is_close(a * a), true)
    @test.assert_eq(area(tiling.b_square).is_close(b * b), true)
    let initial = tiling.triangles.iter().to_array()
    let target = initial.mapi((i, p) => {
      p.transformed(
        @math.Affine2::translation(tiling.offsets[i].x, tiling.offsets[i].y),
      )
    })
    initial.push(tiling.c_square)
    target.push(tiling.a_square)
    target.push(tiling.b_square)
    // Offset lattice avoids edges and vertices; independently checks coverage.
    for i in 0..<23 {
      for j in 0..<23 {
        let p = @math.Vec3::new(
          (i.to_double() + 0.217) / 23.0 * tiling.side,
          (j.to_double() + 0.393) / 23.0 * tiling.side,
        )
        @test.assert_eq(initial.filter(shape => inside(shape, p)).length(), 1)
        @test.assert_eq(target.filter(shape => inside(shape, p)).length(), 1)
      }
    }
  }
}

///|
test "committed TeX assets include nonempty fractions radicals and matrices" {
  let asset = @text.TexAsset::parse(@teaching.tex_assets())
  for
    tex in [
      "x^2", "\\frac{a^2+b^2}{c^2}", "\\sqrt{a^2+b^2}", "\\begin{pmatrix}1&1\\\\0&1\\end{pmatrix}",
      "y=x^2+6x-7",
    ] {
    let glyph = asset.glyph(tex)
    @test.assert_eq(glyph.path.segment_count() > 0, true)
    @test.assert_eq(glyph.path.is_finite(), true)
    @test.assert_eq(glyph.advance > 0.0, true)
    let store = @mobject.Store::new()
    let id = store.add({
      ..@mobject.ObjectState::shape(glyph.path),
      transform: @math.Affine2::scaling(0.65, 0.65),
    })
    let prepared = @animation.write(id).prepare(store)
    @test.assert_eq(prepared.sample(1.0), store.get(id))
  }
}
