///|
priv struct ArcSpan {
  contour : Int32
  segment : Int32
  curve : Cubic
  t0 : Double
  t1 : Double
  start : Double
  end : Double
}

///|
priv struct Location {
  contour : Int32
  segment : Int32
  t : Double
}

///|
/// Prepared adaptive arc-length index. Geometry stays in source coordinates.
/// metric_transform only defines the coordinate system in which length is measured.
pub struct PathMeasure {
  priv path : Path
  priv spans : ReadOnlyArray[ArcSpan]
  length : Double
  uncertainty : Double
}

///|
fn length_bounds(curve : Cubic) -> (Double, Double) {
  let chord = curve.p3.sub(curve.p0).length()
  let polygon = curve.p1.sub(curve.p0).length() +
    curve.p2.sub(curve.p1).length() +
    curve.p3.sub(curve.p2).length()
  (chord, polygon.max(chord))
}

///|
/// Accumulate a global absolute error budget across all accepted leaves.
/// The chord/control-polygon bracket bounds subdivision error in exact arithmetic;
/// floating-point roundoff is not a certified interval bound.
fn append_spans(
  curve : Cubic,
  contour : Int32,
  segment : Int32,
  t0 : Double,
  t1 : Double,
  budget : Double,
  depth : Int32,
  spans : Array[ArcSpan],
  total : Ref[Double],
  uncertainty : Ref[Double],
) -> Unit raise @errors.EngineError {
  let (lower, upper) = length_bounds(curve)
  if !@math.finite(lower) || !@math.finite(upper) {
    raise @errors.InvalidArgument("arc length exceeds finite precision")
  }
  let error = (upper - lower) * 0.5
  if error <= budget {
    if spans.length() >= 65536 {
      raise @errors.InvalidArgument("arc-length index exceeds 65536 spans")
    }
    let estimate = lower * 0.5 + upper * 0.5
    let next = total.val + estimate
    if !@math.finite(next) {
      raise @errors.InvalidArgument("path length exceeds finite precision")
    }
    spans.push({ contour, segment, curve, t0, t1, start: total.val, end: next, })
    total.val = next
    uncertainty.val = uncertainty.val + error
  } else {
    if depth == 0 {
      raise @errors.InvalidArgument(
        "arc-length tolerance not reached at maximum depth",
      )
    }
    let (left, right) = curve.split(0.5)
    let middle = t0 * 0.5 + t1 * 0.5
    append_spans(
      left,
      contour,
      segment,
      t0,
      middle,
      budget * 0.5,
      depth - 1,
      spans,
      total,
      uncertainty,
    )
    append_spans(
      right,
      contour,
      segment,
      middle,
      t1,
      budget * 0.5,
      depth - 1,
      spans,
      total,
      uncertainty,
    )
  }
}

///|
/// Absolute tolerance is in metric-space world units. Work is bounded by depth
/// (1..30) and a hard 65536-span limit; failure is explicit rather than silent.
pub fn Path::measure(
  self : Path,
  tolerance~ : Double = 1.0e-6,
  max_depth~ : Int32 = 30,
  metric_transform~ : @math.Affine2 = @math.Affine2::identity(),
) -> PathMeasure raise @errors.EngineError {
  if !@math.finite(tolerance) ||
    tolerance <= 0.0 ||
    max_depth < 1 ||
    max_depth > 30 ||
    !self.is_finite() ||
    !metric_transform.is_finite() {
    raise @errors.InvalidArgument(
      "invalid arc-length tolerance, depth or geometry",
    )
  }
  let spans : Array[ArcSpan] = []
  let total : Ref[Double] = { val: 0.0, }
  let uncertainty : Ref[Double] = { val: 0.0, }
  let count = self.segment_count()
  let budget = tolerance / count.max(1).to_double()
  for ci in 0..<self.contours().length() {
    let segments = self.contours()[ci].segments()
    for si in 0..<segments.length() {
      let curve = segments[si].transformed(metric_transform)
      if !curve.is_finite() {
        raise @errors.InvalidArgument(
          "transformed path coordinates must be finite",
        )
      }
      append_spans(
        curve, ci, si, 0.0, 1.0, budget, max_depth, spans, total, uncertainty,
      )
    }
  }
  {
    path: self,
    spans: ReadOnlyArray::from_array(spans),
    length: total.val,
    uncertainty: uncertainty.val,
  }
}

///|
/// End intervals are left-biased; start/point intervals are right-biased at
/// pen-up boundaries. Zero-length spans do not consume drawing progress.
fn PathMeasure::locate(
  self : PathMeasure,
  distance : Double,
  ending : Bool,
) -> Location {
  let mut low = 0
  let mut high = self.spans.length() - 1
  while low < high {
    let middle = low + (high - low) / 2
    let end = self.spans[middle].end
    if end < distance || (!ending && end == distance) {
      low = middle + 1
    } else {
      high = middle
    }
  }
  let span = self.spans[low]
  let desired = distance - span.start
  let length = span.end - span.start
  let t = if desired <= 0.0 {
    span.t0
  } else if desired >= length {
    span.t1
  } else {
    // A straight cubic can have a highly nonlinear parameterization. Invert its
    // prefix lengths instead of interpolating t between table entries.
    let mut a = 0.0
    let mut b = 1.0
    for _ in 0..<48 {
      let u = a * 0.5 + b * 0.5
      let (prefix, _) = span.curve.split(u)
      let (lower, upper) = length_bounds(prefix)
      let estimate = lower * 0.5 + upper * 0.5
      if estimate < desired {
        a = u
      } else {
        b = u
      }
    }
    span.t0 + (span.t1 - span.t0) * (a * 0.5 + b * 0.5)
  }
  { contour: span.contour, segment: span.segment, t, }
}

///|
/// Return a point in source coordinates at a fraction of measured arc length.
/// Empty paths return None. On an entirely zero-length path, interior fractions
/// return its first point; fraction 1 returns its last point.
pub fn PathMeasure::point_at(
  self : PathMeasure,
  fraction : Double,
) -> @math.Vec3? raise @errors.EngineError {
  validate_interval(fraction, fraction)
  let contours = self.path.contours()
  if contours.is_empty() {
    return None
  }
  if fraction == 1.0 {
    let segments = contours[contours.length() - 1].segments()
    return Some(segments[segments.length() - 1].p3)
  }
  if fraction == 0.0 || self.length == 0.0 {
    return Some(contours[0].segments()[0].p0)
  }
  let location = self.locate(fraction * self.length, false)
  Some(
    contours[location.contour].segments()[location.segment].point(location.t),
  )
}

///|
/// Extract an arc-length interval using exact cubic subdivision. Disconnected
/// contours stay disconnected; a contour stays closed only if selected in full.
/// Equal fractions return an empty path. [0,1] preserves the original exactly.
pub fn PathMeasure::partial(
  self : PathMeasure,
  start : Double,
  end : Double,
) -> Path raise @errors.EngineError {
  validate_interval(start, end)
  if start == end {
    return Path::new([])
  }
  if start == 0.0 && end == 1.0 {
    return self.path
  }
  if self.length == 0.0 {
    return Path::new([])
  }
  let first = self.locate(start * self.length, false)
  let last = self.locate(end * self.length, true)
  let contours : Array[Contour] = []
  for ci in first.contour..<=last.contour {
    let source = self.path.contours()[ci]
    let segments = source.segments()
    let begin = if ci == first.contour { first.segment } else { 0 }
    let finish = if ci == last.contour {
      last.segment
    } else {
      segments.length() - 1
    }
    let pieces : Array[Cubic] = []
    let mut whole = begin == 0 && finish == segments.length() - 1
    for si in begin..<=finish {
      let a = if ci == first.contour && si == first.segment {
        first.t
      } else {
        0.0
      }
      let b = if ci == last.contour && si == last.segment {
        last.t
      } else {
        1.0
      }
      if a != 0.0 || b != 1.0 {
        whole = false
      }
      if a < b {
        pieces.push(cubic_portion(segments[si], a, b))
      }
    }
    if !pieces.is_empty() {
      contours.push(Contour::new(pieces, closed=source.closed && whole))
    }
  }
  Path::new(contours)
}
