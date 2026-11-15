///|
/// A phrase carries provider-neutral pacing and pause intent.
pub(all) struct SpeechBeat {
  text : String
  rate : Double
  pause_after : Double
  /// A provider-neutral delivery profile, such as "curious" or "reveal".
  style : String
  /// Semitone offset applied by the build-time voice provider.
  pitch : Double
  /// Relative loudness in dB, applied after synthesis.
  energy : Double
}

///|
/// A speech segment is also a subtitle and an explicit animation bookmark.
/// Durations come from measured audio, never from estimated word timestamps.
pub(all) struct Speech {
  key : String
  text : String
  beats : ReadOnlyArray[SpeechBeat]
}

///|
pub fn beat(
  text : String,
  rate~ : Double = 145.0,
  pause_after~ : Double = 0.2,
  style~ : String = "neutral",
  pitch~ : Double = 0.0,
  energy~ : Double = 0.0,
) -> SpeechBeat {
  { text, rate, pause_after, style, pitch, energy, }
}

///|
pub fn speech(
  key : String,
  text : String,
  beats~ : Array[SpeechBeat] = [],
) -> Speech {
  let beats = if beats.is_empty() { [beat(text)] } else { beats }
  { key, text, beats: ReadOnlyArray::from_array(beats), }
}

///|
pub struct NarrationCue {
  key : String
  text : String
  start : Double
  end : Double
}

///|
pub struct NarrationTrack {
  source : String
  language : String
  duration : Double
  cues : ReadOnlyArray[NarrationCue]
}

///|
pub fn NarrationTrack::new(
  source : String,
  language : String,
  speech : Array[Speech],
  durations : Array[Double],
) -> NarrationTrack raise @errors.EngineError {
  if source == "" ||
    language == "" ||
    speech.is_empty() ||
    speech.length() != durations.length() {
    raise @errors.InvalidArgument(
      "narration needs a source, language and measured durations",
    )
  }
  let keys : Map[String, Bool] = Map([])
  let cues : Array[NarrationCue] = []
  let mut start = 0.0
  for i, segment in speech {
    let end = start + durations[i]
    if segment.key == "" ||
      segment.text == "" ||
      keys.contains(segment.key) ||
      !@math.finite(durations[i]) ||
      durations[i] <= 0.0 ||
      !@math.finite(end) ||
      end <= start {
      raise @errors.InvalidArgument("invalid or duplicate narration segment")
    }
    cues.push({ key: segment.key, text: segment.text, start, end, })
    keys[segment.key] = true
    start = end
  }
  { source, language, duration: start, cues: ReadOnlyArray::from_array(cues), }
}

///|
pub fn NarrationTrack::bookmark(
  self : NarrationTrack,
  key : String,
) -> Double raise @errors.EngineError {
  for cue in self.cues {
    if cue.key == key {
      return cue.start
    }
  }
  raise @errors.InvalidArgument("unknown narration bookmark: " + key)
}

///|
/// Half-open intervals agree with lesson chapter boundaries. The final sample
/// retains the last subtitle; clients stop playback at the audio endpoint.
pub fn NarrationTrack::sample(
  self : NarrationTrack,
  time : Double,
) -> NarrationCue raise @errors.EngineError {
  if !@math.finite(time) {
    raise @errors.InvalidArgument("narration time must be finite")
  }
  let time = time.max(0.0).min(self.duration)
  for cue in self.cues {
    if time < cue.end {
      return cue
    }
  }
  self.cues[self.cues.length() - 1]
}

///|
pub fn NarrationTrack::describe(self : NarrationTrack) -> @json.Json {
  @json.Json::object({
    "source": @json.Json::string(self.source),
    "language": @json.Json::string(self.language),
    "duration": @json.Json::number(self.duration),
    "cues": @json.Json::array(
      self.cues
      .iter()
      .map(c => {
        @json.Json::object({
          "key": @json.Json::string(c.key),
          "text": @json.Json::string(c.text),
          "start": @json.Json::number(c.start),
          "end": @json.Json::number(c.end),
        })
      })
      .collect(),
    ),
  })
}
