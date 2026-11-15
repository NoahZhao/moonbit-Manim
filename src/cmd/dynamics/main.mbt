///|
/// The offline adapter samples the same absolute timeline as the website.
fn main raise {
  let args = @env.args()
  if args.length() > 1 && args[1] == "narration-script" {
    println(
      @json.Json::array(
        @tangent.narration_script().map(s => {
          @json.Json::object({
            "key": @json.Json::string(s.key),
            "text": @json.Json::string(s.text),
            "beats": @json.Json::array(
              s.beats
              .iter()
              .map(b => {
                @json.Json::object({
                  "text": @json.Json::string(b.text),
                  "rate": @json.Json::number(b.rate),
                  "pauseAfter": @json.Json::number(b.pause_after),
                  "style": @json.Json::string(b.style),
                  "pitch": @json.Json::number(b.pitch),
                  "energy": @json.Json::number(b.energy),
                })
              })
              .collect(),
            ),
          })
        }),
      ).stringify(),
    )
    return
  }
  let model = @tangent.Tangent::new()
  let rate = @timeline.FrameRate::fps60()
  let count = rate.frame_count(model.lesson.duration)
  if args.length() > 1 && args[1] == "samples" {
    for progress in [0.0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.9, 1.0] {
      println(model.at(progress * model.lesson.duration).stringify())
    }
    return
  }
  println(
    @json.Json::object({
      "type": "start",
      "scene": "tangent",
      "width": 1280,
      "height": 720,
      "fps": 60,
    }).stringify(),
  )
  for index in 0L..<count {
    println(model.at(rate.time(index)).stringify())
  }
  println(
    @json.Json::object({
      "type": "end",
      "frames": @json.Json::number(count.to_double()),
      "duration": @json.Json::number(model.lesson.duration),
    }).stringify(),
  )
}
