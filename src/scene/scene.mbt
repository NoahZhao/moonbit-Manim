///|
/// Imperative scene runner. Each play completes before the next user statement.
/// A scene owns its store; render callbacks may inspect it but cannot mutate or reenter.
pub struct Scene {
  priv store : @mobject.Store
  priv renderer : &@render.Renderer
  priv rate : @timeline.FrameRate
  priv mut frame_index : Int64
  priv mut busy : Bool
  priv mut failed : Bool
}

///|
pub fn Scene::new(
  renderer : &@render.Renderer,
  frame_rate~ : @timeline.FrameRate = @timeline.FrameRate::fps60(),
) -> Scene {
  {
    store: @mobject.Store::new(),
    renderer,
    rate: frame_rate,
    frame_index: 0L,
    busy: false,
    failed: false,
  }
}

///|
fn Scene::ensure_idle(self : Scene) -> Unit raise @errors.EngineError {
  if self.busy {
    raise @errors.SceneBusy
  }
  if self.failed {
    raise @errors.SceneFailed
  }
}

///|
fn Scene::end_play(self : Scene) -> Unit {
  self.busy = false
}

///|
fn Scene::mark_failed(self : Scene) -> Unit {
  self.failed = true
}

///|
pub fn Scene::add(
  self : Scene,
  state : @mobject.ObjectState,
) -> @mobject.ObjectId raise @errors.EngineError {
  self.ensure_idle()
  self.store.add(state)
}

///|
pub fn Scene::get(
  self : Scene,
  id : @mobject.ObjectId,
) -> @mobject.ObjectState raise @errors.EngineError {
  self.store.get(id)
}

///|
pub fn Scene::set(
  self : Scene,
  id : @mobject.ObjectId,
  state : @mobject.ObjectState,
) -> Unit raise @errors.EngineError {
  self.ensure_idle()
  self.store.set(id, state)
}

///|
pub fn Scene::remove(
  self : Scene,
  id : @mobject.ObjectId,
) -> Unit raise @errors.EngineError {
  self.ensure_idle()
  self.store.remove(id)
}

///|
pub fn Scene::reparent(
  self : Scene,
  child : @mobject.ObjectId,
  parent : @mobject.ObjectId?,
) -> Unit raise @errors.EngineError {
  self.ensure_idle()
  self.store.reparent(child, parent)
}

///|
pub fn Scene::contains(self : Scene, id : @mobject.ObjectId) -> Bool {
  self.store.contains(id)
}

///|
/// Number of frames successfully delivered to the renderer.
pub fn Scene::frame_index(self : Scene) -> Int64 {
  self.frame_index
}

///|
/// Encoded timeline time: each positive play is quantized up to whole frames.
pub fn Scene::time(self : Scene) -> Double {
  self.rate.time(self.frame_index)
}

///|
/// Preflight for higher-level animations that need to add temporary objects.
pub fn Scene::validate_duration(
  self : Scene,
  duration : Double,
) -> Unit raise @errors.EngineError {
  self.ensure_idle()
  let count = self.rate.frame_count(duration)
  if self.frame_index + count > 9007199254740991L {
    raise @errors.InvalidArgument("scene exceeds the supported frame range")
  }
}

///|
/// Capturing a final state does not implicitly emit a duplicate endpoint frame.
pub fn Scene::snapshot(self : Scene) -> @render.Frame raise @errors.EngineError {
  { index: self.frame_index, time: self.time(), items: self.store.drawables(), }
}

///|
/// Conservative initial conflict policy: one animation per node/subtree at a time.
/// Preflight validation is atomic. After renderer failure the scene is poisoned:
/// already-written output cannot be rolled back, so retry with a fresh scene.
pub fn Scene::play(
  self : Scene,
  animations : Array[@animation.Animation],
  duration~ : Double,
) -> Unit raise {
  self.play_staggered(animations, duration~, lag_ratio=0.0)
}

///|
/// Total duration includes all staggered starts. A ratio of 1 is sequential;
/// 0 shares one clock. All descriptors are prepared before the first frame.
pub fn Scene::play_staggered(
  self : Scene,
  animations : Array[@animation.Animation],
  duration~ : Double,
  lag_ratio~ : Double = 0.15,
) -> Unit raise {
  self.validate_duration(duration)
  if lag_ratio.is_nan() || lag_ratio.is_inf() || lag_ratio < 0.0 {
    raise @errors.InvalidArgument("lag ratio must be finite and nonnegative")
  }
  let factor = 1.0 + lag_ratio * (animations.length() - 1).max(0).to_double()
  if factor.is_inf() {
    raise @errors.InvalidArgument("staggered timing exceeds finite precision")
  }
  let count = self.rate.frame_count(duration)
  let prepared : Array[@animation.PreparedAnimation] = []
  for animation in animations {
    let id = animation.object_id()
    for previous in prepared {
      if self.store.related(id, previous.id) {
        raise @errors.AnimationConflict
      }
    }
    prepared.push(animation.prepare(self.store))
  }
  self.busy = true
  defer self.end_play()
  errdefer self.mark_failed()
  for offset = 0L; offset < count; offset = offset + 1L {
    for i in 0..<prepared.length() {
      let animation = prepared[i]
      let alpha = self.rate.time(offset) / duration * factor -
        i.to_double() * lag_ratio
      self.store.set(animation.id, animation.sample(alpha))
    }
    self.renderer.render(self.snapshot())
    self.frame_index = self.frame_index + 1L
  }
  // Commit the exact requested endpoint, even for zero-duration animations.
  for animation in prepared {
    self.store.set(animation.id, animation.sample(1.0))
  }
  for animation in prepared {
    if animation.remove_on_finish {
      self.store.remove(animation.id)
    }
  }
}

///|
/// Wait advances logical output time. Updaters and static-frame reuse are future work.
pub fn Scene::wait(self : Scene, duration : Double) -> Unit raise {
  self.play([], duration~)
}
