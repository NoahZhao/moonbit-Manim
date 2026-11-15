///|
#derive(Eq, @debug.Debug)
pub(all) enum Easing {
  Linear
  Smooth
}

///|
/// Smooth uses quintic smoothstep with zero endpoint velocity and acceleration.
pub fn Easing::sample(self : Easing, alpha : Double) -> Double {
  let t = @math.clamp01(alpha)
  match self {
    Linear => t
    Smooth => @math.clamp01(t * t * t * (t * (t * 6.0 - 15.0) + 10.0))
  }
}

///|
/// Descriptors capture intent. The source snapshot is taken only by prepare().
pub(all) enum Animation {
  Transform(@mobject.ObjectId, @mobject.ObjectState, Easing)
  Shift(@mobject.ObjectId, @math.Vec3, Easing)
  Rotate(@mobject.ObjectId, Double, @math.Vec3, Easing)
  FadeIn(@mobject.ObjectId, Easing)
  FadeOut(@mobject.ObjectId, Easing)
  Create(@mobject.ObjectId, Easing)
  Write(@mobject.ObjectId, Easing)
  ApplyAffine(@mobject.ObjectId, @math.Affine2, Easing)
}

///|
pub fn transform(
  id : @mobject.ObjectId,
  target : @mobject.ObjectState,
  easing~ : Easing = Smooth,
) -> Animation {
  Transform(id, target, easing)
}

///|
pub fn shift(
  id : @mobject.ObjectId,
  offset : @math.Vec3,
  easing~ : Easing = Smooth,
) -> Animation {
  Shift(id, offset, easing)
}

///|
/// Pivot is expressed in the object's parent coordinate system.
pub fn rotate(
  id : @mobject.ObjectId,
  radians : Double,
  pivot~ : @math.Vec3 = @math.Vec3::zero(),
  easing~ : Easing = Smooth,
) -> Animation {
  Rotate(id, radians, pivot, easing)
}

///|
pub fn fade_in(id : @mobject.ObjectId, easing~ : Easing = Smooth) -> Animation {
  FadeIn(id, easing)
}

///|
pub fn fade_out(id : @mobject.ObjectId, easing~ : Easing = Smooth) -> Animation {
  FadeOut(id, easing)
}

///|
/// Reveal a leaf vector path in world arc-length order. Fill appears on completion.
pub fn create(id : @mobject.ObjectId, easing~ : Easing = Smooth) -> Animation {
  Create(id, easing)
}

///|
/// Draw vector outlines, then bring in the original fill. Suitable for TeX paths.
pub fn write(id : @mobject.ObjectId, easing~ : Easing = Smooth) -> Animation {
  Write(id, easing)
}

///|
/// Interpolate I -> matrix in parent coordinates, including for complete groups.
/// Singular intermediate matrices are intentional in linear algebra lessons.
pub fn apply_affine(
  id : @mobject.ObjectId,
  matrix : @math.Affine2,
  easing~ : Easing = Smooth,
) -> Animation {
  ApplyAffine(id, matrix, easing)
}

///|
pub fn Animation::object_id(self : Animation) -> @mobject.ObjectId {
  match self {
    Transform(id, _, _)
    | Shift(id, _, _)
    | Rotate(id, _, _, _)
    | FadeIn(id, _)
    | FadeOut(id, _)
    | Create(id, _)
    | Write(id, _)
    | ApplyAffine(id, _, _) => id
  }
}

///|
priv enum PreparedKind {
  Morph(@geometry.PathMorph)
  Translation(@math.Vec3)
  Rotation(Double, @math.Vec3)
  Opacity
  Reveal(@geometry.PathMeasure)
  Handwriting(@geometry.PathMeasure)
  Affine(@math.Affine2)
}

///|
/// Immutable animation state. Sampling order and frequency do not affect results.
pub struct PreparedAnimation {
  id : @mobject.ObjectId
  priv start : @mobject.ObjectState
  priv target : @mobject.ObjectState
  priv easing : Easing
  priv kind : PreparedKind
  remove_on_finish : Bool
}

///|
fn rotated(
  transform : @math.Affine2,
  radians : Double,
  pivot : @math.Vec3,
) -> @math.Affine2 {
  @math.Affine2::translation(pivot.x, pivot.y)
  .compose(@math.Affine2::rotation(radians))
  .compose(@math.Affine2::translation(-pivot.x, -pivot.y))
  .compose(transform)
}

///|
/// Does not mutate the store. Unsupported morphs fail before playback emits frames.
pub fn Animation::prepare(
  self : Animation,
  store : @mobject.Store,
) -> PreparedAnimation raise @errors.EngineError {
  let id = self.object_id()
  let state = store.get(id)
  match self {
    Transform(_, target, easing) => {
      target.validate()
      if store.has_children(id) {
        raise @errors.UnsupportedMorph(
          "initial Transform supports leaf shapes only",
        )
      }
      let morph = match (state.path, target.path) {
        (Some(a), Some(b)) =>
          @geometry.PathMorph::new(
            a.transformed(state.transform),
            b.transformed(target.transform),
          )
        _ =>
          raise @errors.UnsupportedMorph("Transform requires two vector shapes")
      }
      {
        id,
        start: state,
        target,
        easing,
        kind: Morph(morph),
        remove_on_finish: false,
      }
    }
    Shift(_, offset, easing) => {
      if !offset.is_finite() || offset.z != 0.0 {
        raise @errors.InvalidArgument(
          "initial Shift requires a finite XY offset",
        )
      }
      let target : @mobject.ObjectState = {
        ..state,
        transform: @math.Affine2::translation(offset.x, offset.y).compose(
          state.transform,
        ),
      }
      target.validate()
      {
        id,
        start: state,
        target,
        easing,
        kind: Translation(offset),
        remove_on_finish: false,
      }
    }
    Rotate(_, radians, pivot, easing) => {
      if !@math.finite(radians) || !pivot.is_finite() || pivot.z != 0.0 {
        raise @errors.InvalidArgument(
          "initial Rotate requires finite XY parameters",
        )
      }
      let target : @mobject.ObjectState = {
        ..state,
        transform: rotated(state.transform, radians, pivot),
      }
      target.validate()
      {
        id,
        start: state,
        target,
        easing,
        kind: Rotation(radians, pivot),
        remove_on_finish: false,
      }
    }
    FadeIn(_, easing) => {
      let start : @mobject.ObjectState = {
        ..state,
        style: { ..state.style, opacity: 0.0, },
      }
      {
        id,
        start,
        target: state,
        easing,
        kind: Opacity,
        remove_on_finish: false,
      }
    }
    FadeOut(_, easing) => {
      let target : @mobject.ObjectState = {
        ..state,
        style: { ..state.style, opacity: 0.0, },
      }
      {
        id,
        start: state,
        target,
        easing,
        kind: Opacity,
        remove_on_finish: true,
      }
    }
    ApplyAffine(_, matrix, easing) => {
      if !matrix.is_finite() {
        raise @errors.InvalidArgument(
          "affine animation requires a finite matrix",
        )
      }
      let target : @mobject.ObjectState = {
        ..state,
        transform: matrix.compose(state.transform),
      }
      target.validate()
      {
        id,
        start: state,
        target,
        easing,
        kind: Affine(matrix),
        remove_on_finish: false,
      }
    }
    Create(_, easing) | Write(_, easing) => {
      if store.has_children(id) {
        raise @errors.InvalidArgument(
          "Create currently supports leaf vector shapes",
        )
      }
      let measure = match state.path {
        Some(path) =>
          path.measure(
            // Compound glyph paths need a practical global drawing tolerance.
            // 1e-4 world units is 0.009 pixels at the default 720p camera.
            tolerance=match self {
              Write(_, _) => 1.0e-4
              _ => 1.0e-6
            },
            metric_transform=store.world_transform(id),
          )
        None => raise @errors.InvalidArgument("Create requires vector geometry")
      }
      let start : @mobject.ObjectState = {
        ..state,
        path: Some(@geometry.Path::new([])),
        style: { ..state.style, fill_opacity: 0.0, },
      }
      {
        id,
        start,
        target: state,
        easing,
        kind: match self {
          Write(_, _) => Handwriting(measure)
          _ => Reveal(measure)
        },
        remove_on_finish: false,
      }
    }
  }
}

///|
/// Rigid rotations interpolate angles, never the entries of an affine matrix.
pub fn PreparedAnimation::sample(
  self : PreparedAnimation,
  alpha : Double,
) -> @mobject.ObjectState raise @errors.EngineError {
  if !@math.finite(alpha) {
    raise @errors.InvalidArgument("animation progress must be finite")
  }
  let t = self.easing.sample(alpha)
  if t == 0.0 {
    return self.start
  }
  if t == 1.0 {
    return self.target
  }
  match self.kind {
    Morph(morph) =>
      {
        ..self.start,
        path: Some(morph.sample(t)),
        transform: @math.Affine2::identity(),
        style: self.start.style.lerp(self.target.style, t),
      }
    Translation(offset) =>
      {
        ..self.start,
        transform: @math.Affine2::translation(offset.x * t, offset.y * t).compose(
          self.start.transform,
        ),
      }
    Rotation(radians, pivot) =>
      {
        ..self.start,
        transform: rotated(self.start.transform, radians * t, pivot),
      }
    Opacity =>
      { ..self.start, style: self.start.style.lerp(self.target.style, t), }
    Reveal(measure) => { ..self.start, path: Some(measure.partial(0.0, t)), }
    Handwriting(measure) => {
      let reveal = @math.clamp01(t / 0.75)
      let fill = @math.clamp01((t - 0.6) / 0.4)
      {
        ..self.target,
        path: Some(measure.partial(0.0, reveal)),
        style: {
          ..self.target.style,
          stroke: self.target.style.fill,
          stroke_width: self.target.style.stroke_width.max(1.2) * (1.0 - fill) +
          self.target.style.stroke_width * fill,
          stroke_opacity: 1.0 * (1.0 - fill) +
          self.target.style.stroke_opacity * fill,
          fill_opacity: self.target.style.fill_opacity * fill,
        },
      }
    }
    Affine(matrix) => {
      let partial : @math.Affine2 = {
        a: 1.0 + (matrix.a - 1.0) * t,
        b: matrix.b * t,
        c: matrix.c * t,
        d: 1.0 + (matrix.d - 1.0) * t,
        tx: matrix.tx * t,
        ty: matrix.ty * t,
      }
      { ..self.start, transform: partial.compose(self.start.transform), }
    }
  }
}
