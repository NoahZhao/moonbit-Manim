///|
/// The offline adapter samples the same absolute timeline as the website.
fn main raise {
  let model = @tangent.Tangent::new()
  let rate = @timeline.FrameRate::fps60()
  let count = rate.frame_count(model.lesson.duration)
  let args = @env.args()
  if args.length() > 1 && args[1] == "samples" {
    for time in [0.0, 1.0, 2.5, 4.0, 5.5, 7.0, 8.0, 9.0, 10.5, 12.0] {
      println(model.at(time).stringify())
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
