///|
let tangent_cache : Ref[@tangent.Tangent?] = { val: None, }

///|
fn tangent_model() -> @tangent.Tangent raise {
  match tangent_cache.val {
    Some(model) => model
    None => {
      let model = @tangent.Tangent::new()
      tangent_cache.val = Some(model)
      model
    }
  }
}

///|
/// Preserve the existing parameterized snapshot API for integrations.
fn tangent_frame(t : Double, x : Double, initial_gap : Double) -> String raise {
  let model = tangent_model()
  // Validate the supplied gap before progress scales it.
  ignore(model.lesson.explore([("x", x), ("h", initial_gap)]))
  model.manual(x, initial_gap * (1.0 - t)).stringify()
}

///|
#cfg(target="js")
fn describe_lesson() -> String {
  tangent_model().describe().stringify() catch {
    _ => "{\"error\":\"Lesson unavailable\"}"
  }
}

///|
#cfg(target="js")
fn render_lesson(progress : Double) -> String {
  let result = try {
    let model = tangent_model()
    model.at_progress(progress).stringify()
  } catch {
    _ => "{\"error\":\"Invalid lesson time\"}"
  }
  result
}
