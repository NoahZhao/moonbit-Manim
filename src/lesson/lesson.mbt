///|
/// A bounded scalar is declared once for both playback and interactive controls.
pub(all) struct Parameter {
  key : String
  label : String
  initial : Double
  min : Double
  max : Double
  step : Double
  unit : String
}

///|
pub struct Target {
  key : String
  value : Double
  easing : @animation.Easing
}

///|
pub fn to(
  key : String,
  value : Double,
  easing~ : @animation.Easing = Smooth,
) -> Target {
  { key, value, easing, }
}

///|
pub struct Cue {
  title : String
  caption : String
  duration : Double
  targets : ReadOnlyArray[Target]
}

///|
pub fn cue(
  title : String,
  caption : String,
  duration : Double,
  targets~ : Array[Target] = [],
) -> Cue {
  { title, caption, duration, targets: ReadOnlyArray::from_array(targets), }
}

///|
priv struct Segment {
  start : Double
  cue : Cue
  from : ReadOnlyArray[Double]
  to : ReadOnlyArray[Double]
  easing : ReadOnlyArray[@animation.Easing]
}

///|
/// A finite, random-access scalar timeline. It does not serialize callbacks or
/// seek imperative Scene.play scripts. Geometry consumes its absolute samples.
pub struct Lesson {
  parameters : ReadOnlyArray[Parameter]
  duration : Double
  priv segments : ReadOnlyArray[Segment]
}

///|
pub struct Sample {
  time : Double
  progress : Double
  chapter : Int32
  title : String
  caption : String
  values : ReadOnlyArray[(String, Double)]
}

///|
pub fn Sample::get(
  self : Sample,
  key : String,
) -> Double raise @errors.EngineError {
  for (name, value) in self.values {
    if name == key {
      return value
    }
  }
  raise @errors.InvalidArgument("unknown lesson parameter: " + key)
}

///|
pub fn Lesson::new(
  parameters : Array[Parameter],
  cues : Array[Cue],
) -> Lesson raise @errors.EngineError {
  if parameters.is_empty() || cues.is_empty() {
    raise @errors.InvalidArgument("a lesson needs parameters and chapters")
  }
  let indices : Map[String, Int32] = Map([])
  let current : Array[Double] = []
  for i, p in parameters {
    if p.key == "" ||
      indices.contains(p.key) ||
      !@math.finite(p.initial) ||
      !@math.finite(p.min) ||
      !@math.finite(p.max) ||
      !@math.finite(p.step) ||
      p.min >= p.max ||
      p.initial < p.min ||
      p.initial > p.max ||
      p.step <= 0.0 {
      raise @errors.InvalidArgument("invalid or duplicate lesson parameter")
    }
    indices[p.key] = i
    current.push(p.initial)
  }
  let segments : Array[Segment] = []
  let mut duration = 0.0
  for cue in cues {
    let end = duration + cue.duration
    if !@math.finite(cue.duration) ||
      cue.duration <= 0.0 ||
      !@math.finite(end) ||
      end <= duration {
      raise @errors.InvalidArgument(
        "chapter duration must be finite and positive",
      )
    }
    let from = ReadOnlyArray::from_array(current)
    let easing = Array::make(parameters.length(), @animation.Easing::Linear)
    let seen : Map[String, Bool] = Map([])
    for target in cue.targets {
      let index = match indices.get(target.key) {
        Some(index) => index
        None => raise @errors.InvalidArgument("unknown chapter target")
      }
      let p = parameters[index]
      if seen.contains(target.key) ||
        !@math.finite(target.value) ||
        target.value < p.min ||
        target.value > p.max {
        raise @errors.InvalidArgument("invalid or repeated chapter target")
      }
      seen[target.key] = true
      current[index] = target.value
      easing[index] = target.easing
    }
    segments.push({
      start: duration,
      cue,
      from,
      to: ReadOnlyArray::from_array(current),
      easing: ReadOnlyArray::from_array(easing),
    })
    duration = end
  }
  {
    parameters: ReadOnlyArray::from_array(parameters),
    duration,
    segments: ReadOnlyArray::from_array(segments),
  }
}

///|
/// Finite times are clamped. A boundary belongs to the following chapter;
/// the exact final endpoint belongs to the last chapter.
pub fn Lesson::sample(
  self : Lesson,
  time : Double,
) -> Sample raise @errors.EngineError {
  if !@math.finite(time) {
    raise @errors.InvalidArgument("lesson time must be finite")
  }
  let time = time.max(0.0).min(self.duration)
  let mut chapter = self.segments.length() - 1
  for i, segment in self.segments {
    if time < segment.start + segment.cue.duration {
      chapter = i
      break
    }
  }
  let segment = self.segments[chapter]
  let alpha = @math.clamp01((time - segment.start) / segment.cue.duration)
  let values : Array[(String, Double)] = []
  for i, p in self.parameters {
    let t = segment.easing[i].sample(alpha)
    let value = if t == 0.0 {
      segment.from[i]
    } else if t == 1.0 {
      segment.to[i]
    } else {
      segment.from[i] * (1.0 - t) + segment.to[i] * t
    }
    values.push((p.key, value))
  }
  {
    time,
    progress: time / self.duration,
    chapter,
    title: segment.cue.title,
    caption: segment.cue.caption,
    values: ReadOnlyArray::from_array(values),
  }
}

///|
/// Manual values use the same bounds, but need not lie on the UI step lattice.
pub fn Lesson::explore(
  self : Lesson,
  overrides : Array[(String, Double)],
) -> Sample raise @errors.EngineError {
  let supplied : Map[String, Double] = Map([])
  for (key, value) in overrides {
    if supplied.contains(key) || !@math.finite(value) {
      raise @errors.InvalidArgument("invalid or repeated manual parameter")
    }
    supplied[key] = value
  }
  let values : Array[(String, Double)] = []
  for p in self.parameters {
    let value = supplied.get(p.key).unwrap_or(p.initial)
    if value < p.min || value > p.max {
      raise @errors.InvalidArgument("manual parameter outside declared range")
    }
    values.push((p.key, value))
    supplied.remove(p.key) |> ignore
  }
  if !supplied.is_empty() {
    raise @errors.InvalidArgument("unknown manual parameter")
  }
  {
    time: 0.0,
    progress: 0.0,
    chapter: -1,
    title: "自由探索",
    caption: "调整参数，观察同一个数学模型。",
    values: ReadOnlyArray::from_array(values),
  }
}

///|
pub fn Lesson::describe(self : Lesson) -> @json.Json {
  let parameters = self.parameters.map(p => {
    @json.Json::object({
      "key": @json.Json::string(p.key),
      "label": @json.Json::string(p.label),
      "initial": @json.Json::number(p.initial),
      "min": @json.Json::number(p.min),
      "max": @json.Json::number(p.max),
      "step": @json.Json::number(p.step),
      "unit": @json.Json::string(p.unit),
    })
  })
  let chapters = self.segments.map(s => {
    @json.Json::object({
      "start": @json.Json::number(s.start),
      "duration": @json.Json::number(s.cue.duration),
      "title": @json.Json::string(s.cue.title),
      "caption": @json.Json::string(s.cue.caption),
    })
  })
  @json.Json::object({
    "duration": @json.Json::number(self.duration),
    "parameters": @json.Json::array(parameters.iter().collect()),
    "chapters": @json.Json::array(chapters.iter().collect()),
  })
}

///|
/// Recompile chapter timings after audio measurement, retaining scalar targets.
pub fn Lesson::retime(
  self : Lesson,
  durations : Array[Double],
) -> Lesson raise @errors.EngineError {
  if durations.length() != self.segments.length() {
    raise @errors.InvalidArgument(
      "one measured duration is required per chapter",
    )
  }
  let cues : Array[Cue] = []
  for i, segment in self.segments {
    cues.push({ ..segment.cue, duration: durations[i], })
  }
  Lesson::new(self.parameters.iter().collect(), cues)
}

///|
/// Preserve exact published chapter boundaries when converting UI progress
/// back to seconds; division followed by multiplication can lose one ULP.
pub fn Lesson::sample_progress(
  self : Lesson,
  progress : Double,
) -> Sample raise @errors.EngineError {
  if !@math.finite(progress) {
    raise @errors.InvalidArgument("progress must be finite")
  }
  let progress = @math.clamp01(progress)
  for segment in self.segments {
    if progress == segment.start / self.duration {
      return self.sample(segment.start)
    }
  }
  self.sample(progress * self.duration)
}
