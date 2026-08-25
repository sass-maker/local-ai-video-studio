import Foundation
import Testing

@testable import StudioCore

// The estimator decides how hard a render will be and how far the preview is
// downscaled before any work starts. Cost thresholds and the preview edge are
// therefore behaviour, not implementation detail.

private let vertical = OutputProfile(aspectRatio: .vertical, width: 1080, height: 1920, fps: 24)
private let provenance = PlannerProvenance(kind: .deterministicDemo, name: "test", version: "1")
private let estimator = RenderEstimator()

private func graph(
  _ effects: [EffectType], end: Double, output: OutputProfile = vertical
) -> EffectGraph {
  EffectGraph(
    label: "Estimate",
    differenceSummary: "For estimation.",
    provenance: provenance,
    output: output,
    timeline: [
      TimelineSegment(
        start: 0, end: end,
        effects: effects.map { EffectNode(type: $0, parameters: .init()) })
    ]
  )
}

@Test func estimatePixelFramesFollowOutputAndDuration() {
  let estimate = estimator.estimate(graph([.trim], end: 2))

  #expect(estimate.pixelFrames == Double(1080 * 1920 * 24) * 2)
  #expect(estimate.estimatedBytes == Int64(2 * Double(1080 * 1920) * 0.12))
}

@Test func aShortLightGraphStaysLightAndKeepsTheFullPreviewEdge() {
  // 1080x1920x24 for 1s is ~49.8M pixel-frames; one light effect keeps
  // costUnits ~49.8, far under the 3000 light ceiling.
  let estimate = estimator.estimate(graph([.trim], end: 1))

  #expect(estimate.workClass == .light)
  #expect(estimate.responsibleEffects.isEmpty)
  #expect(estimate.recommendedPreviewLongEdge == 1280)
}

@Test func aHeavyStyleEffectIsNamedAndDownscalesThePreview() {
  let estimate = estimator.estimate(graph([.styleAnime, .trim], end: 1))

  #expect(estimate.responsibleEffects == [.styleAnime])
  #expect(estimate.recommendedPreviewLongEdge == 960)
}

@Test func heavyEffectsAreReportedOnceAndSorted() {
  let estimate = estimator.estimate(graph([.styleVHS, .styleAnime, .styleVHS], end: 1))

  #expect(estimate.responsibleEffects.count == 2)
  #expect(
    estimate.responsibleEffects == estimate.responsibleEffects.sorted { $0.rawValue < $1.rawValue })
}

@Test func aLongExpensiveGraphEscalatesToHeavyWork() {
  // ~49.8 cost units per second per light effect; three heavy style effects at
  // cost 7 each push a 120s graph well past the 12000 heavy threshold.
  let estimate = estimator.estimate(graph([.styleAnime, .styleNoir, .styleVHS], end: 120))

  #expect(estimate.workClass == .heavy)
  #expect(estimate.costUnits > 12_000)
  #expect(estimate.recommendedPreviewLongEdge == 960)
}

@Test func anEmptyTimelineCostsNothingRatherThanCrashing() {
  let empty = EffectGraph(
    label: "Empty", differenceSummary: "No segments.", provenance: provenance,
    output: vertical, timeline: [])
  let estimate = estimator.estimate(empty)

  #expect(estimate.pixelFrames == 0)
  #expect(estimate.costUnits == 0)
  #expect(estimate.workClass == .light)
}

@Test func preflightBlocksAShortfallAndReportsHowMuchIsMissing() {
  let short = DiskSpacePreflight(requiredBytes: 900, availableBytes: 400)
  let ample = DiskSpacePreflight(requiredBytes: 900, availableBytes: 900)

  #expect(!short.canStart)
  #expect(short.additionalBytesRequired == 500)
  #expect(ample.canStart)
  #expect(ample.additionalBytesRequired == 0)
}
