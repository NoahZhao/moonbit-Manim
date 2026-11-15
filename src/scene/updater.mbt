///|
/// Frozen inputs from declared dependencies, including updates earlier in this pass.
/// Retaining a context is safe; it never exposes the mutable scene store.
pub struct UpdateContext {
  time : Double
  dt : Double
  priv objects : ReadOnlyArray[ObjectInput]
  priv values : ReadOnlyArray[(ValueTracker, Double)]
}

///|
priv struct ObjectInput {
  id : @mobject.ObjectId
  state : @mobject.ObjectState
  world : @math.Affine2
}

///|
pub fn UpdateContext::get(
  self : UpdateContext,
  id : @mobject.ObjectId,
) -> @mobject.ObjectState raise @errors.EngineError {
  for object in self.objects {
    if object.id == id {
      return object.state
    }
  }
  raise @errors.InvalidArgument("updater read an undeclared object dependency")
}

///|
pub fn UpdateContext::world_transform(
  self : UpdateContext,
  id : @mobject.ObjectId,
) -> @math.Affine2 raise @errors.EngineError {
  for object in self.objects {
    if object.id == id {
      return object.world
    }
  }
  raise @errors.InvalidArgument("updater read an undeclared object dependency")
}

///|
pub fn UpdateContext::get_value(
  self : UpdateContext,
  tracker : ValueTracker,
) -> Double raise @errors.EngineError {
  for value in self.values {
    if value.0 == tracker {
      return value.1
    }
  }
  raise @errors.InvalidArgument("updater read an undeclared tracker dependency")
}

///|
priv struct Updater {
  target : @mobject.ObjectId
  dependencies : ReadOnlyArray[@mobject.ObjectId]
  trackers : ReadOnlyArray[ValueTracker]
  callback : (UpdateContext, @mobject.ObjectState) -> @mobject.ObjectState raise
}

///|
/// One updater per target; setting it again replaces the previous callback atomically.
/// Declare every object/tracker read through the context. Cycles include ancestors
/// of dependencies because world transforms read the complete parent chain.
pub fn Scene::set_updater(
  self : Scene,
  target : @mobject.ObjectId,
  callback : (UpdateContext, @mobject.ObjectState) -> @mobject.ObjectState raise,
  depends_on~ : Array[@mobject.ObjectId] = [],
  trackers~ : Array[ValueTracker] = [],
) -> Unit raise @errors.EngineError {
  self.ensure_idle()
  ignore(self.store.get(target))
  for dependency in depends_on {
    ignore(self.store.get(dependency))
  }
  for tracker in trackers {
    ignore(self.get_value(tracker))
  }
  let candidate = self.updaters.filter(updater => updater.target != target)
  candidate.push({
    target,
    dependencies: ReadOnlyArray::from_array(depends_on),
    trackers: ReadOnlyArray::from_array(trackers),
    callback,
  })
  self.updaters = self.order_updaters(candidate)
}

///|
pub fn Scene::clear_updater(
  self : Scene,
  target : @mobject.ObjectId,
) -> Unit raise @errors.EngineError {
  self.ensure_idle()
  ignore(self.store.get(target))
  self.updaters = self.updaters.filter(updater => updater.target != target)
}

///|
fn Scene::prune_updaters(self : Scene) -> Unit {
  self.updaters = self.updaters.filter(updater => {
    self.store.contains(updater.target) &&
    updater.dependencies.all(id => self.store.contains(id)) &&
    updater.trackers.all(tracker => self.contains_tracker(tracker))
  })
}

///|
fn Scene::depends_on_updater(
  self : Scene,
  reader : Updater,
  writer : Updater,
) -> Bool raise @errors.EngineError {
  if reader.target != writer.target &&
    self.store.is_ancestor(writer.target, reader.target) {
    return true
  }
  for dependency in reader.dependencies {
    if self.store.is_ancestor(writer.target, dependency) {
      return true
    }
  }
  false
}

///|
/// Stable topological order, recomputed only when bindings or hierarchy change.
fn Scene::order_updaters(
  self : Scene,
  entries : Array[Updater],
) -> Array[Updater] raise @errors.EngineError {
  let ordered : Array[Updater] = []
  let incoming = Array::make(entries.length(), 0)
  let edges : Array[Array[Int32]] = Array::makei(entries.length(), _ => [])
  for i in 0..<entries.length() {
    for j in 0..<entries.length() {
      if self.depends_on_updater(entries[i], entries[j]) {
        incoming[i] = incoming[i] + 1
        edges[j].push(i)
      }
    }
  }
  while ordered.length() < entries.length() {
    let mut found = false
    for i in 0..<entries.length() {
      if incoming[i] != 0 {
        continue
      }
      ordered.push(entries[i])
      incoming[i] = -1
      for reader in edges[i] {
        incoming[reader] = incoming[reader] - 1
      }
      found = true
      break
    }
    if !found {
      raise @errors.InvalidHierarchy("updater dependencies contain a cycle")
    }
  }
  ordered
}

///|
fn Scene::staged_state(
  self : Scene,
  id : @mobject.ObjectId,
  staged : Array[(@mobject.ObjectId, @mobject.ObjectState)],
) -> @mobject.ObjectState raise @errors.EngineError {
  for entry in staged {
    if entry.0 == id {
      return entry.1
    }
  }
  self.store.get(id)
}

///|
fn Scene::staged_world(
  self : Scene,
  id : @mobject.ObjectId,
  staged : Array[(@mobject.ObjectId, @mobject.ObjectState)],
) -> @math.Affine2 raise @errors.EngineError {
  let mut transform = self.staged_state(id, staged).transform
  let mut parent = self.store.parent(id)
  while parent is Some(ancestor) {
    transform = self.staged_state(ancestor, staged).transform.compose(transform)
    parent = self.store.parent(ancestor)
  }
  if !transform.is_finite() {
    raise @errors.InvalidArgument("composed updater transform must be finite")
  }
  transform
}

///|
/// Callbacks see staged dependencies; object changes commit only after all succeed.
fn Scene::run_updaters(
  self : Scene,
  active : Array[Updater],
  dt : Double,
) -> Unit raise {
  let staged : Array[(@mobject.ObjectId, @mobject.ObjectState)] = []
  for updater in active {
    let objects = updater.dependencies.map(id => {
      id,
      state: self.staged_state(id, staged),
      world: self.staged_world(id, staged),
    })
    let values = updater.trackers.map(tracker => {
      (tracker, self.get_value(tracker))
    })
    let context : UpdateContext = { time: self.time(), dt, objects, values, }
    let state = (updater.callback)(context, self.store.get(updater.target))
    state.validate()
    staged.push((updater.target, state))
  }
  for entry in staged {
    self.store.set(entry.0, entry.1)
  }
}

///|
/// Refresh dynamic geometry at the current time with dt=0, emitting no frames.
/// snapshot() itself stays read-only and never executes user callbacks.
pub fn Scene::update(self : Scene) -> Unit raise {
  self.ensure_idle()
  self.busy = true
  defer self.end_play()
  errdefer self.mark_failed()
  self.run_updaters(self.updaters, 0.0)
}
