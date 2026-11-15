///|
/// Semantic keys distinguish repeated symbols (for example left-x and right-x).
pub(all) struct TexPart {
  key : String
  glyph : TexGlyph
  color : @mobject.Color
}

///|
pub struct MathTex {
  priv parts : ReadOnlyArray[TexPart]
  priv font_size : Double
  priv gap : Double
  width : Double
}

///|
/// Horizontal baseline layout. Fractions, roots and scripts are laid out inside
/// fragments by the asset compiler; spacing between fragments is explicit.
pub fn MathTex::new(
  parts : Array[TexPart],
  font_size~ : Double = 0.6,
  gap~ : Double = 0.12,
) -> MathTex raise @errors.EngineError {
  if !@math.finite(font_size) ||
    font_size <= 0.0 ||
    !@math.finite(gap) ||
    gap < 0.0 {
    raise @errors.InvalidArgument(
      "formula size must be positive and gap nonnegative",
    )
  }
  let mut width = 0.0
  for i in 0..<parts.length() {
    if parts[i].key.is_empty() {
      raise @errors.InvalidArgument("formula keys cannot be empty")
    }
    for j in 0..<i {
      if parts[i].key == parts[j].key {
        raise @errors.InvalidArgument("formula keys must be unique")
      }
    }
    width += parts[i].glyph.advance * font_size
  }
  width += (parts.length() - 1).max(0).to_double() * gap
  if !@math.finite(width) {
    raise @errors.InvalidArgument("formula layout exceeds finite precision")
  }
  { parts: ReadOnlyArray::from_array(parts), font_size, gap, width, }
}

///|
fn MathTex::layout(
  self : MathTex,
  origin : @math.Vec3,
) -> Array[@mobject.ObjectState] raise @errors.EngineError {
  if !origin.is_finite() || origin.z != 0.0 {
    raise @errors.InvalidArgument("formula baseline must be a finite XY point")
  }
  let states : Array[@mobject.ObjectState] = []
  let mut x = origin.x
  for part in self.parts {
    let state : @mobject.ObjectState = {
      ..@mobject.ObjectState::shape(part.glyph.path, style={
        ..@mobject.Style::default(),
        fill: part.color,
        stroke: part.color,
        fill_opacity: 1.0,
        stroke_width: 0.0,
      }),
      transform: @math.Affine2::translation(x, origin.y).compose(
        @math.Affine2::scaling(self.font_size, self.font_size),
      ),
      z_index: 20,
    }
    state.validate()
    states.push(state)
    x += part.glyph.advance * self.font_size + self.gap
  }
  states
}

///|
priv struct FormulaEntry {
  key : String
  id : @mobject.ObjectId
}

///|
pub struct Formula {
  root : @mobject.ObjectId
  priv scene : @scene.Scene
  priv mut entries : Array[FormulaEntry]
}

///|
pub fn Formula::new(
  scene : @scene.Scene,
  formula : MathTex,
  origin~ : @math.Vec3 = @math.Vec3::zero(),
) -> Formula raise @errors.EngineError {
  let states = formula.layout(origin)
  let root = scene.add(@mobject.ObjectState::group())
  let entries : Array[FormulaEntry] = []
  for i in 0..<states.length() {
    let id = scene.add(states[i])
    scene.reparent(id, Some(root))
    entries.push({ key: formula.parts[i].key, id, })
  }
  { root, scene, entries, }
}

///|
pub fn Formula::part(
  self : Formula,
  key : String,
) -> @mobject.ObjectId raise @errors.EngineError {
  for entry in self.entries {
    if entry.key == key {
      return entry.id
    }
  }
  raise @errors.InvalidArgument("unknown formula key: " + key)
}

///|
pub fn Formula::write(
  self : Formula,
  duration~ : Double = 1.5,
  lag_ratio~ : Double = 0.15,
) -> Unit raise {
  self.scene.play_staggered(
    self.entries.map(e => @animation.write(e.id)),
    duration~,
    lag_ratio~,
  )
}

///|
/// Equal keys AND equal glyph geometry retain object identity and move/recolor.
/// New/changed fragments fade in; removed fragments fade out. This deliberately
/// avoids inventing a geometric correspondence between unrelated glyph contours.
/// Origin is in root-local coordinates, so a moved root remains a moved root.
pub fn Formula::transition(
  self : Formula,
  target : MathTex,
  origin~ : @math.Vec3 = @math.Vec3::zero(),
  duration~ : Double = 1.2,
) -> Unit raise {
  let states = target.layout(origin)
  // Resolve old handles and validate timing before adding target fragments.
  self.scene.validate_duration(duration)
  ignore(self.scene.get(self.root))
  for entry in self.entries {
    ignore(self.scene.get(entry.id))
  }
  let entries : Array[FormulaEntry] = []
  let animations : Array[@animation.Animation] = []
  let retained : Array[@mobject.ObjectId] = []
  for i in 0..<states.length() {
    let key = target.parts[i].key
    let mut matched : @mobject.ObjectId? = None
    for entry in self.entries {
      if entry.key == key && self.scene.get(entry.id).path == states[i].path {
        matched = Some(entry.id)
      }
    }
    let id = match matched {
      Some(id) => {
        retained.push(id)
        animations.push(@animation.transform(id, states[i]))
        id
      }
      None => {
        let id = self.scene.add(states[i])
        self.scene.reparent(id, Some(self.root))
        animations.push(@animation.fade_in(id))
        id
      }
    }
    entries.push({ key, id, })
  }
  for entry in self.entries {
    if !retained.contains(entry.id) {
      animations.push(@animation.fade_out(entry.id))
    }
  }
  self.scene.play(animations, duration~)
  self.entries = entries
}
