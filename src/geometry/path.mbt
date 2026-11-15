///|
/// Immutable, connected sequence. Construction defensively copies the input.
#derive(Eq, @debug.Debug)
pub struct Contour {
  priv segments : ReadOnlyArray[Cubic]
  closed : Bool
}

///|
pub fn Contour::new(
  segments : Array[Cubic],
  closed~ : Bool = false,
) -> Contour raise @errors.EngineError {
  if segments.is_empty() {
    raise @errors.InvalidArgument("a contour needs at least one cubic")
  }
  for i in 0..<segments.length() {
    if !segments[i].is_finite() {
      raise @errors.InvalidArgument("path coordinates must be finite")
    }
    if i > 0 && segments[i - 1].p3 != segments[i].p0 {
      raise @errors.InvalidArgument("adjacent cubics must share an endpoint")
    }
  }
  if closed && segments[segments.length() - 1].p3 != segments[0].p0 {
    raise @errors.InvalidArgument("a closed contour must return to its start")
  }
  { segments: ReadOnlyArray::from_array(segments), closed, }
}

///|
pub fn Contour::segments(self : Contour) -> ReadOnlyArray[Cubic] {
  self.segments
}

///|
pub fn Contour::transformed(
  self : Contour,
  transform : @math.Affine2,
) -> Contour {
  {
    segments: self.segments.map(c => c.transformed(transform)),
    closed: self.closed,
  }
}

///|
/// A path can contain multiple contours (including holes), or be empty.
#derive(Eq, @debug.Debug)
pub struct Path {
  priv contours : ReadOnlyArray[Contour]
}

///|
pub fn Path::new(contours : Array[Contour]) -> Path {
  { contours: ReadOnlyArray::from_array(contours), }
}

///|
pub fn Path::contours(self : Path) -> ReadOnlyArray[Contour] {
  self.contours
}

///|
pub fn Path::segment_count(self : Path) -> Int32 {
  self.contours.fold(init=0, (n, c) => n + c.segments.length())
}

///|
pub fn Path::transformed(self : Path, transform : @math.Affine2) -> Path {
  { contours: self.contours.map(c => c.transformed(transform)), }
}

///|
/// Validate transformed geometry before accepting it into a scene.
pub fn Path::is_finite(self : Path) -> Bool {
  self.contours.all(c => c.segments.all(segment => segment.is_finite()))
}

///|
/// Return a fresh contour with exactly count segments, preserving its geometry.
fn subdivide(contour : Contour, count : Int32) -> Contour {
  let source = contour.segments
  let result : Array[Cubic] = []
  for i in 0..<source.length() {
    let pieces = count / source.length() +
      (if i < count % source.length() { 1 } else { 0 })
    let mut remaining = source[i]
    for j in 0..<(pieces - 1) {
      let (left, right) = remaining.split(1.0 / (pieces - j).to_double())
      result.push(left)
      remaining = right
    }
    result.push(remaining)
  }
  { segments: ReadOnlyArray::from_array(result), closed: contour.closed, }
}

///|
/// Prepared once, then sampled without changing either input path.
/// Initial policy pairs contours and segments by order; it does not infer topology.
pub struct PathMorph {
  priv start : Path
  priv target : Path
  priv original_start : Path
  priv original_target : Path
}

///|
/// Different contour counts or open/closed states require an explicit future policy.
pub fn PathMorph::new(
  start : Path,
  target : Path,
) -> PathMorph raise @errors.EngineError {
  if !start.is_finite() || !target.is_finite() {
    raise @errors.InvalidArgument("morph coordinates must be finite")
  }
  if start.contours.length() != target.contours.length() {
    raise @errors.UnsupportedMorph("contour counts differ")
  }
  let left : Array[Contour] = []
  let right : Array[Contour] = []
  for i in 0..<start.contours.length() {
    let a = start.contours[i]
    let b = target.contours[i]
    if a.closed != b.closed {
      raise @errors.UnsupportedMorph(
        "open and closed contours cannot be paired",
      )
    }
    let count = a.segments.length().max(b.segments.length())
    left.push(subdivide(a, count))
    right.push(subdivide(b, count))
  }
  {
    start: Path::new(left),
    target: Path::new(right),
    original_start: start,
    original_target: target,
  }
}

///|
/// Exact original endpoints; intermediate curves use prepared correspondence.
pub fn PathMorph::sample(self : PathMorph, alpha : Double) -> Path {
  let t = @math.clamp01(alpha)
  if t == 0.0 {
    return self.original_start
  }
  if t == 1.0 {
    return self.original_target
  }
  {
    contours: self.start.contours.mapi((i, a) => {
      let b = self.target.contours[i]
      {
        segments: a.segments.mapi((j, segment) => segment.lerp(b.segments[j], t)),
        closed: a.closed,
      }
    }),
  }
}
