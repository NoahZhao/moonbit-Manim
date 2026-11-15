///|
/// Immutable visual state. None geometry denotes a group.
#derive(Eq, @debug.Debug)
pub(all) struct ObjectState {
  path : @geometry.Path?
  transform : @math.Affine2
  style : Style
  z_index : Int32
}

///|
pub fn ObjectState::shape(
  path : @geometry.Path,
  style~ : Style = Style::default(),
) -> ObjectState {
  { path: Some(path), transform: @math.Affine2::identity(), style, z_index: 0, }
}

///|
pub fn ObjectState::group() -> ObjectState {
  {
    path: None,
    transform: @math.Affine2::identity(),
    style: Style::default(),
    z_index: 0,
  }
}

///|
pub fn ObjectState::validate(
  self : ObjectState,
) -> Unit raise @errors.EngineError {
  self.style.validate()
  if !self.transform.is_finite() {
    raise @errors.InvalidArgument("object transform must be finite")
  }
  if self.path is Some(path) && !path.is_finite() {
    raise @errors.InvalidArgument("object path must be finite")
  }
}

///|
/// A handle is scoped to a store and generation, including when slots are reused.
#derive(@debug.Debug)
pub struct ObjectId {
  priv owner : Array[Unit]
  priv slot : Int32
  priv generation : Int64
}

///|
pub impl Eq for ObjectId with fn equal(self, other) {
  physical_equal(self.owner, other.owner) &&
  self.slot == other.slot &&
  self.generation == other.generation
}

///|
priv struct Entry {
  state : ObjectState
  parent : ObjectId?
  order : Int64
}

///|
priv struct Slot {
  mut generation : Int64
  mut entry : Entry?
}

///|
/// Owned tree; reparenting keeps the local transform unchanged.
pub struct Store {
  priv owner : Array[Unit]
  priv slots : Array[Slot]
  priv free : Array[Int32]
  priv mut next_order : Int64
  priv mut count : Int32
}

///|
pub fn Store::new() -> Store {
  { owner: [()], slots: [], free: [], next_order: 0L, count: 0, }
}

///|
pub fn Store::length(self : Store) -> Int32 {
  self.count
}

///|
fn Store::entry(self : Store, id : ObjectId) -> Entry raise @errors.EngineError {
  if !physical_equal(self.owner, id.owner) ||
    id.slot < 0 ||
    id.slot >= self.slots.length() {
    raise @errors.InvalidHandle
  }
  let slot = self.slots[id.slot]
  if slot.generation != id.generation {
    raise @errors.InvalidHandle
  }
  match slot.entry {
    Some(entry) => entry
    None => raise @errors.InvalidHandle
  }
}

///|
pub fn Store::contains(self : Store, id : ObjectId) -> Bool {
  if !physical_equal(self.owner, id.owner) ||
    id.slot < 0 ||
    id.slot >= self.slots.length() {
    return false
  }
  self.slots[id.slot].generation == id.generation &&
  self.slots[id.slot].entry is Some(_)
}

///|
pub fn Store::add(
  self : Store,
  state : ObjectState,
) -> ObjectId raise @errors.EngineError {
  state.validate()
  let entry : Entry = { state, parent: None, order: self.next_order, }
  let index = match self.free.pop() {
    Some(index) => {
      self.slots[index].entry = Some(entry)
      index
    }
    None => {
      self.slots.push({ generation: 0L, entry: Some(entry), })
      self.slots.length() - 1
    }
  }
  self.next_order = self.next_order + 1L
  self.count = self.count + 1
  { owner: self.owner, slot: index, generation: self.slots[index].generation, }
}

///|
/// Safe to retain: paths and styles inside the returned state are immutable.
pub fn Store::get(
  self : Store,
  id : ObjectId,
) -> ObjectState raise @errors.EngineError {
  self.entry(id).state
}

///|
/// The owning parent, if any. Foreign and expired handles are rejected.
pub fn Store::parent(
  self : Store,
  id : ObjectId,
) -> ObjectId? raise @errors.EngineError {
  self.entry(id).parent
}

///|
/// Includes the node itself. Useful for ordering world-space dependencies.
pub fn Store::is_ancestor(
  self : Store,
  ancestor : ObjectId,
  node : ObjectId,
) -> Bool raise @errors.EngineError {
  ignore(self.entry(ancestor))
  let mut current = Some(node)
  while current is Some(id) {
    let entry = self.entry(id)
    if id == ancestor {
      return true
    }
    current = entry.parent
  }
  false
}

///|
/// Compose the node's transform with all ancestors, in world coordinates.
pub fn Store::world_transform(
  self : Store,
  id : ObjectId,
) -> @math.Affine2 raise @errors.EngineError {
  let entry = self.entry(id)
  let mut transform = entry.state.transform
  let mut parent = entry.parent
  while parent is Some(ancestor_id) {
    let ancestor = self.entry(ancestor_id)
    transform = ancestor.state.transform.compose(transform)
    parent = ancestor.parent
  }
  if !transform.is_finite() {
    raise @errors.InvalidArgument("composed transform exceeds finite precision")
  }
  transform
}

///|
pub fn Store::set(
  self : Store,
  id : ObjectId,
  state : ObjectState,
) -> Unit raise @errors.EngineError {
  let entry = self.entry(id)
  state.validate()
  self.slots[id.slot].entry = Some({ ..entry, state, })
}

///|
/// Reject foreign handles and cycles before changing any parent link.
pub fn Store::reparent(
  self : Store,
  child : ObjectId,
  parent : ObjectId?,
) -> Unit raise @errors.EngineError {
  let entry = self.entry(child)
  let mut ancestor = parent
  while ancestor is Some(id) {
    if id == child {
      raise @errors.InvalidHierarchy("reparenting would create a cycle")
    }
    ancestor = self.entry(id).parent
  }
  self.slots[child.slot].entry = Some({ ..entry, parent, })
}

///|
pub fn Store::has_children(
  self : Store,
  id : ObjectId,
) -> Bool raise @errors.EngineError {
  ignore(self.entry(id))
  self.slots.any(slot => slot.entry is Some(entry) && entry.parent == Some(id))
}

///|
/// True for the same node, or for an ancestor/descendant pair.
pub fn Store::related(
  self : Store,
  a : ObjectId,
  b : ObjectId,
) -> Bool raise @errors.EngineError {
  ignore(self.entry(a))
  ignore(self.entry(b))
  for start in [a, b] {
    let mut current = Some(start)
    let target = if start == a { b } else { a }
    while current is Some(id) {
      if id == target {
        return true
      }
      current = self.entry(id).parent
    }
  }
  false
}

///|
/// Removing a parent removes its entire subtree and invalidates all its handles.
pub fn Store::remove(
  self : Store,
  id : ObjectId,
) -> Unit raise @errors.EngineError {
  ignore(self.entry(id))
  let pending = [id]
  let mut cursor = 0
  while cursor < pending.length() {
    let current = pending[cursor]
    for i in 0..<self.slots.length() {
      if self.slots[i].entry is Some(entry) && entry.parent == Some(current) {
        pending.push({
          owner: self.owner,
          slot: i,
          generation: self.slots[i].generation,
        })
      }
    }
    cursor = cursor + 1
  }
  for current in pending {
    let slot = self.slots[current.slot]
    slot.entry = None
    slot.generation = slot.generation + 1L
    self.free.push(current.slot)
    self.count = self.count - 1
  }
}

///|
/// Backend-neutral drawable. transform is already composed through its ancestors.
#derive(Eq, @debug.Debug)
pub(all) struct DrawItem {
  id : ObjectId
  path : @geometry.Path
  transform : @math.Affine2
  style : Style
  z_index : Int32
  order : Int64
}

///|
/// Groups contribute transforms and multiplicative opacity, not inherited fill/stroke.
/// Stable ordering is (z_index, insertion_order).
pub fn Store::drawables(
  self : Store,
) -> ReadOnlyArray[DrawItem] raise @errors.EngineError {
  let items : Array[DrawItem] = []
  for i in 0..<self.slots.length() {
    if self.slots[i].entry is Some(entry) && entry.state.path is Some(path) {
      let mut transform = entry.state.transform
      let mut opacity = entry.state.style.opacity
      let mut parent = entry.parent
      while parent is Some(id) {
        let ancestor = self.entry(id)
        transform = ancestor.state.transform.compose(transform)
        opacity = opacity * ancestor.state.style.opacity
        parent = ancestor.parent
      }
      if !transform.is_finite() {
        raise @errors.InvalidArgument(
          "composed transform exceeds finite precision",
        )
      }
      items.push({
        id: {
          owner: self.owner,
          slot: i,
          generation: self.slots[i].generation,
        },
        path,
        transform,
        style: { ..entry.state.style, opacity, },
        z_index: entry.state.z_index,
        order: entry.order,
      })
    }
  }
  items.sort_by((a, b) => {
    let z = a.z_index.compare(b.z_index)
    if z != 0 {
      z
    } else {
      a.order.compare(b.order)
    }
  })
  ReadOnlyArray::from_array(items)
}
