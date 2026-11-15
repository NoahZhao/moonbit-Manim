///|
/// Scene-owned scalar handle. Slots are never reused, so removed handles stay invalid.
#derive(@debug.Debug)
pub struct ValueTracker {
  priv owner : Array[Unit]
  priv slot : Int32
}

///|
pub impl Eq for ValueTracker with fn equal(self, other) {
  physical_equal(self.owner, other.owner) && self.slot == other.slot
}

///|
pub fn Scene::add_tracker(
  self : Scene,
  value : Double,
) -> ValueTracker raise @errors.EngineError {
  self.ensure_idle()
  validate_value(value)
  let slot = self.trackers.length()
  self.trackers.push(Some(value))
  { owner: self.tracker_owner, slot, }
}

///|
fn validate_value(value : Double) -> Unit raise @errors.EngineError {
  if !@math.finite(value) {
    raise @errors.InvalidArgument("tracker value must be finite")
  }
}

///|
fn Scene::contains_tracker(self : Scene, tracker : ValueTracker) -> Bool {
  physical_equal(self.tracker_owner, tracker.owner) &&
  tracker.slot >= 0 &&
  tracker.slot < self.trackers.length() &&
  self.trackers[tracker.slot] is Some(_)
}

///|
pub fn Scene::get_value(
  self : Scene,
  tracker : ValueTracker,
) -> Double raise @errors.EngineError {
  if !self.contains_tracker(tracker) {
    raise @errors.InvalidHandle
  }
  self.trackers[tracker.slot].unwrap()
}

///|
/// Call update() afterwards to refresh dependent geometry without advancing time.
pub fn Scene::set_value(
  self : Scene,
  tracker : ValueTracker,
  value : Double,
) -> Unit raise @errors.EngineError {
  self.ensure_idle()
  ignore(self.get_value(tracker))
  validate_value(value)
  self.trackers[tracker.slot] = Some(value)
}

///|
/// Unregister updaters that read this tracker; their objects remain in the scene.
pub fn Scene::remove_tracker(
  self : Scene,
  tracker : ValueTracker,
) -> Unit raise @errors.EngineError {
  self.ensure_idle()
  ignore(self.get_value(tracker))
  self.trackers[tracker.slot] = None
  self.prune_updaters()
}

///|
/// A lazy scalar animation. The initial value is captured when playback starts.
pub struct ValueAnimation {
  priv tracker : ValueTracker
  priv target : Double
  priv easing : @animation.Easing
}

///|
pub fn value_to(
  tracker : ValueTracker,
  target : Double,
  easing~ : @animation.Easing = Smooth,
) -> ValueAnimation {
  { tracker, target, easing, }
}

///|
priv struct PreparedValue {
  tracker : ValueTracker
  start : Double
  target : Double
  easing : @animation.Easing
}

///|
fn PreparedValue::sample(self : PreparedValue, alpha : Double) -> Double {
  let t = self.easing.sample(alpha)
  if t == 0.0 {
    self.start
  } else if t == 1.0 {
    self.target
  } else {
    self.start * (1.0 - t) + self.target * t
  }
}

///|
fn Scene::prepare_values(
  self : Scene,
  values : Array[ValueAnimation],
) -> Array[PreparedValue] raise @errors.EngineError {
  let prepared : Array[PreparedValue] = []
  for value in values {
    let start = self.get_value(value.tracker)
    validate_value(value.target)
    if prepared.any(previous => previous.tracker == value.tracker) {
      raise @errors.AnimationConflict
    }
    prepared.push({
      tracker: value.tracker,
      start,
      target: value.target,
      easing: value.easing,
    })
  }
  prepared
}
