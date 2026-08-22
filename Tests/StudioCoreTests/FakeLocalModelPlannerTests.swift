import Foundation
import StudioCore
import Testing

/// A deterministic stand-in for Apple's on-device model.
///
/// Every test in this file injects this fake, so the suite exercises the real
/// registry mapping, validation, disclosure, and fallback paths on machines
/// where Apple Intelligence is unavailable, disabled, or still downloading.
private struct FakeLocalModel: GeneratedPlanProducing {
  struct GenerationFailure: Error {}

  let modelIdentifier = "fake-local-model"
  let draft: GeneratedPlanDraft?

  init(_ draft: GeneratedPlanDraft?) { self.draft = draft }

  func generatePlan(_ request: PlanningRequest) async throws -> GeneratedPlanDraft {
    guard let draft else { throw GenerationFailure() }
    return draft
  }
}

private let fakeOutput = OutputProfile(aspectRatio: .vertical, width: 1080, height: 1920, fps: 24)

private func fakeRequest(_ instruction: String, variantCount: Int = 2) -> PlanningRequest {
  PlanningRequest(
    instruction: instruction, variantCount: variantCount, output: fakeOutput, duration: 18)
}

private func plannerWithFake(_ draft: GeneratedPlanDraft?) -> PreferredVariantPlanner {
  PreferredVariantPlanner(model: FakeLocalModel(draft))
}

@Test func injectedLocalModelPlanIsMappedValidatedAndDisclosed() async throws {
  let draft = GeneratedPlanDraft(variants: [
    .init(
      label: "Painted Drift", summary: "Soft watercolor pass held at half speed.",
      effects: [
        .init(type: EffectType.styleWatercolor.rawValue, strength: 0.62),
        .init(type: EffectType.speed.rawValue, rate: 0.5),
      ]),
    .init(
      label: "Ink Hook", summary: "Comic ink with a short title hook.",
      effects: [
        .init(type: EffectType.styleComic.rawValue, strength: 0.7),
        .init(type: EffectType.titleCard.rawValue, text: "LOOK CLOSER"),
      ]),
  ])

  let outcome = try await plannerWithFake(draft).planDisclosed(
    fakeRequest("dreamy watercolor slow motion, plus a comic hook"))

  #expect(outcome.disclosure.provenance.kind == .localModel)
  #expect(outcome.disclosure.provenance.name == "fake-local-model")
  #expect(outcome.disclosure.fallbackReason == nil)
  #expect(outcome.graphs.count == 2)
  #expect(outcome.graphs.map(\.label) == ["Painted Drift", "Ink Hook"])
  #expect(
    outcome.graphs[0].timeline[0].effects.map(\.type) == [.styleWatercolor, .speed])
  #expect(outcome.graphs[1].timeline[0].effects.map(\.type) == [.styleComic, .titleCard])
  #expect(outcome.graphs[1].timeline[0].effects[1].parameters.text == "LOOK CLOSER")
  for graph in outcome.graphs { _ = try EffectGraphValidator().validate(graph) }
}

@Test func unregisteredModelEffectFallsBackWithAnActionableReason() async throws {
  let draft = GeneratedPlanDraft(variants: [
    .init(
      label: "Escape", summary: "Attempts an unsupported operation.",
      effects: [.init(type: "shell.execute")]),
    .init(
      label: "Noir", summary: "A supported alternate.",
      effects: [.init(type: EffectType.styleNoir.rawValue, strength: 0.5)]),
  ])

  let outcome = try await plannerWithFake(draft).planDisclosed(fakeRequest("do anything"))

  #expect(outcome.disclosure.provenance.kind == .deterministicDemo)
  #expect(outcome.disclosure.fallbackReason?.contains("shell.execute") == true)
  #expect(outcome.graphs.count == 2)
  let types = Set(outcome.graphs.flatMap { $0.timeline.flatMap(\.effects).map(\.type.rawValue) })
  #expect(!types.contains("shell.execute"))
}

@Test func outOfBoundsModelParameterFallsBackThroughTheExistingValidator() async throws {
  let draft = GeneratedPlanDraft(variants: [
    .init(
      label: "Blown Out", summary: "Strength past the registered bound.",
      effects: [.init(type: EffectType.styleComic.rawValue, strength: 2)]),
    .init(
      label: "Calm", summary: "A supported alternate.",
      effects: [.init(type: EffectType.styleNoir.rawValue, strength: 0.4)]),
  ])

  let outcome = try await plannerWithFake(draft).planDisclosed(fakeRequest("maximum comic"))

  #expect(outcome.disclosure.provenance.kind == .deterministicDemo)
  #expect(outcome.disclosure.fallbackReason?.contains("validation") == true)
}

@Test func wrongVariantCountFromTheModelFallsBackOnce() async throws {
  let draft = GeneratedPlanDraft(variants: [
    .init(
      label: "Only One", summary: "Single variant.",
      effects: [.init(type: EffectType.styleCel.rawValue, strength: 0.5)])
  ])

  let outcome = try await plannerWithFake(draft).planDisclosed(
    fakeRequest("three cel studies", variantCount: 3))

  #expect(outcome.disclosure.provenance.kind == .deterministicDemo)
  #expect(outcome.graphs.count == 3)
  #expect(outcome.disclosure.fallbackReason?.contains("1 variants instead of 3") == true)
}

@Test func modelGenerationFailureFallsBackWithTheUnderlyingReason() async throws {
  let outcome = try await plannerWithFake(nil).planDisclosed(fakeRequest("watercolor"))

  #expect(outcome.disclosure.provenance.kind == .deterministicDemo)
  #expect(outcome.graphs.allSatisfy { $0.provenance.kind == .deterministicDemo })
  #expect(outcome.disclosure.fallbackReason?.isEmpty == false)
}

@Test func variantCountOutsideTwoToFiveIsRejectedBeforeAnyModelCall() async {
  let planner = plannerWithFake(nil)

  await #expect(throws: PlanningError.variantCountOutOfRange) {
    try await planner.planDisclosed(fakeRequest("one only", variantCount: 1))
  }
  await #expect(throws: PlanningError.variantCountOutOfRange) {
    try await planner.planDisclosed(fakeRequest("too many", variantCount: 6))
  }
}

@Test func availabilityCarriesAnActionableReasonOnlyWhenUnavailable() {
  #expect(LocalModelAvailability.available.unavailableReason == nil)
  #expect(
    LocalModelAvailability.unavailable("Apple Intelligence is not enabled in System Settings.")
      .unavailableReason == "Apple Intelligence is not enabled in System Settings.")
}

@Test func mappingErrorsExplainThemselvesForTheInterface() {
  #expect(
    GeneratedPlanMappingError.unsupportedEffect("style.hologram").explanation
      .contains("style.hologram"))
  #expect(
    GeneratedPlanMappingError.wrongVariantCount(expected: 3, actual: 5).explanation
      .contains("5 variants instead of 3"))
  #expect(GeneratedPlanMappingError.emptyLabel(0).explanation.contains("variant 1"))
  #expect(GeneratedPlanMappingError.emptyEffects(1).explanation.contains("variant 2"))
}

@Test func emptyModelLabelsAndEffectsAreRejectedByTheMapper() {
  let request = fakeRequest("blank")
  let blankLabel = GeneratedPlanDraft(variants: [
    .init(label: "  ", summary: "s", effects: [.init(type: EffectType.styleNoir.rawValue)]),
    .init(label: "B", summary: "s", effects: [.init(type: EffectType.styleNoir.rawValue)]),
  ])
  let noEffects = GeneratedPlanDraft(variants: [
    .init(label: "A", summary: "s", effects: []),
    .init(label: "B", summary: "s", effects: [.init(type: EffectType.styleNoir.rawValue)]),
  ])

  #expect(throws: GeneratedPlanMappingError.emptyLabel(0)) {
    try GeneratedPlanMapper().map(blankLabel, for: request)
  }
  #expect(throws: GeneratedPlanMappingError.emptyEffects(0)) {
    try GeneratedPlanMapper().map(noEffects, for: request)
  }
}
