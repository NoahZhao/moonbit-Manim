///|
/// The same authored speech feeds TTS, subtitles and animation bookmarks.
pub fn narration_script() -> Array[@narration.Speech] {
  [
    @narration.speech(
      "observe",
      "观察抛物线上的两个点。粉色点和绿色点，确定一条割线。",
      beats=[
        @narration.beat(
          "观察抛物线上的两个点。",
          rate=132.0,
          pause_after=0.34,
          style="curious",
        ),
        @narration.beat(
          "粉色点和绿色点，确定一条割线。",
          rate=151.0,
          pause_after=0.28,
          style="inviting",
        ),
      ],
    ),
    @narration.speech(
      "approach",
      "让绿色点逐渐靠近粉色点。当间距趋近零，割线就趋近切线。",
      beats=[
        @narration.beat(
          "让绿色点逐渐靠近粉色点。",
          rate=138.0,
          pause_after=0.38,
          style="curious",
        ),
        @narration.beat(
          "当间距趋近零，割线就趋近切线。",
          rate=126.0,
          pause_after=0.48,
          style="reveal",
        ),
      ],
    ),
    @narration.speech(
      "travel",
      "让观察点沿曲线移动。切线的斜率，从负数经过零，再变成正数。",
      beats=[
        @narration.beat(
          "让观察点沿曲线移动。",
          rate=142.0,
          pause_after=0.3,
          style="inviting",
        ),
        @narration.beat(
          "切线的斜率，从负数经过零，再变成正数。",
          rate=132.0,
          pause_after=0.42,
          style="reveal",
        ),
      ],
    ),
    @narration.speech(
      "return",
      "回到曲线下降的位置。这里的切线斜率，是负数。",
      beats=[
        @narration.beat(
          "回到曲线下降的位置。",
          rate=135.0,
          pause_after=0.32,
          style="calm",
        ),
        @narration.beat(
          "这里的切线斜率，是负数。",
          rate=128.0,
          pause_after=0.34,
          style="calm",
        ),
      ],
    ),
    @narration.speech(
      "separate",
      "再次拉开两个点。割线斜率与导数，出现了差距。",
      beats=[
        @narration.beat(
          "再次拉开两个点。",
          rate=142.0,
          pause_after=0.3,
          style="curious",
        ),
        @narration.beat(
          "割线斜率与导数，出现了差距。",
          rate=123.0,
          pause_after=0.4,
          style="reveal",
        ),
      ],
    ),
    @narration.speech(
      "explore",
      "再让间距趋近零。你也可以切换自由探索，亲手调整位置和间距。",
      beats=[
        @narration.beat(
          "再让间距趋近零。",
          rate=138.0,
          pause_after=0.32,
          style="inviting",
        ),
        @narration.beat(
          "你也可以切换自由探索，亲手调整位置和间距。",
          rate=128.0,
          pause_after=0.5,
          style="inviting",
        ),
      ],
    ),
  ]
}

///|
pub fn Tangent::describe(self : Tangent) -> @json.Json {
  match self.lesson.describe() {
    Object(fields) => {
      fields["narration"] = self.narration.describe()
      @json.Json::object(fields)
    }
    _ => self.lesson.describe()
  }
}

///|
pub fn Tangent::at_progress(
  self : Tangent,
  progress : Double,
) -> @json.Json raise {
  self.draw(self.lesson.sample_progress(progress))
}
