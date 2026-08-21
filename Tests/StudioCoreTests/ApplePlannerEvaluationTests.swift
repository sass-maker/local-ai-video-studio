import Foundation
import StudioCore
import Testing

private struct PlannerEvaluationCase: Sendable {
  let name: String
  let prompt: String
  let variantCount: Int
  let expected: Set<EffectType>
  let forbidden: Set<EffectType>
}

@Test
func applePlannerSemanticEvaluation() async throws {
  guard ProcessInfo.processInfo.environment["RUN_APPLE_MODEL_EVAL"] == "1" else {
    print("APPLE_PLANNER_EVAL skipped; set RUN_APPLE_MODEL_EVAL=1 to run on-device inference")
    return
  }
  guard PreferredVariantPlanner.availability == .available else {
    print("APPLE_PLANNER_EVAL unavailable: \(PreferredVariantPlanner.availability)")
    return
  }

  let cases: [PlannerEvaluationCase] = [
    .init(
      name: "style-and-speed",
      prompt:
        "Create two watercolor versions. One should be dreamy and slow motion; the other should be a lighter watercolor treatment.",
      variantCount: 2,
      expected: [.styleWatercolor, .speed],
      forbidden: [.styleVHS, .styleComic]
    ),
    .init(
      name: "noir-restraint",
      prompt:
        "Make three restrained noir edits with cinematic contrast. Do not use anime, comic, VHS, captions, or title cards.",
      variantCount: 3,
      expected: [.styleNoir],
      forbidden: [.styleAnime, .styleComic, .styleVHS, .captionDynamic, .titleCard]
    ),
    .init(
      name: "vhs-hook",
      prompt: "Make four retro VHS hooks with a short WATCH NOW title and restrained beat flashes.",
      variantCount: 4,
      expected: [.styleVHS, .titleCard, .beatFlash],
      forbidden: [.styleWatercolor, .styleNoir]
    ),
    .init(
      name: "comic-subject",
      prompt:
        "Create three comic-book versions with a clear subject outline and a subtle glow. Keep the subject recognizable.",
      variantCount: 3,
      expected: [.styleComic, .outline, .glow],
      forbidden: [.styleNoir, .styleVHS]
    ),
    .init(
      name: "cinematic-background",
      prompt:
        "Create two cinematic versions with a softly blurred background and restrained color grading.",
      variantCount: 2,
      expected: [.styleCinematic, .backgroundBlur, .colorGrade],
      forbidden: [.styleAnime, .styleComic]
    ),
    .init(
      name: "clean-original",
      prompt:
        "Create three clean versions. Keep the original visual style, normalize audio, and reframe around the primary person. No stylization.",
      variantCount: 3,
      expected: [.audioNormalize, .cropAutoSubject],
      forbidden: [
        .styleAnime, .styleComic, .styleSketch, .styleWatercolor, .styleCel, .styleCinematic,
        .styleNoir, .styleVHS,
      ]
    ),
    .init(
      name: "captions-and-tracking",
      prompt:
        "Create five vertical social versions with bold dynamic captions and automatic framing around the main person.",
      variantCount: 5,
      expected: [.captionDynamic, .cropAutoSubject],
      forbidden: []
    ),
    .init(
      name: "unsupported-request",
      prompt:
        "Turn the speaker into a photorealistic 3D dragon and replace the entire world. If that is unsupported, use only safe available effects and explain the approximation through the variant summary.",
      variantCount: 2,
      expected: [],
      forbidden: []
    ),
  ]

  let planner = PreferredVariantPlanner()
  let validator = EffectGraphValidator()
  var covered = 0
  var expectedTotal = 0
  var forbiddenHits = 0
  var fallbackCases = 0

  for item in cases {
    let request = PlanningRequest(
      instruction: item.prompt,
      variantCount: item.variantCount,
      output: OutputProfile(aspectRatio: .vertical, width: 1080, height: 1920, fps: 24),
      duration: 30
    )
    let graphs = try await planner.plan(request)
    let effects = Set(graphs.flatMap { $0.timeline.flatMap(\.effects).map(\.type) })
    let found = item.expected.intersection(effects)
    let forbidden = item.forbidden.intersection(effects)
    let usedApple = graphs.allSatisfy { $0.provenance.kind == .localModel }
    if !usedApple { fallbackCases += 1 }
    covered += found.count
    expectedTotal += item.expected.count
    forbiddenHits += forbidden.count

    #expect(graphs.count == item.variantCount)
    #expect(usedApple)
    #expect(forbidden.isEmpty)
    for graph in graphs { _ = try validator.validate(graph) }

    print(
      "APPLE_PLANNER_CASE name=\(item.name) apple=\(usedApple) expected=\(item.expected.map(\.rawValue).sorted()) found=\(found.map(\.rawValue).sorted()) forbidden=\(forbidden.map(\.rawValue).sorted()) effects=\(effects.map(\.rawValue).sorted())"
    )
  }

  let recall = expectedTotal == 0 ? 1 : Double(covered) / Double(expectedTotal)
  print(
    "APPLE_PLANNER_SUMMARY cases=\(cases.count) semantic_recall=\(String(format: "%.3f", recall)) forbidden_hits=\(forbiddenHits) fallback_cases=\(fallbackCases)"
  )
}
