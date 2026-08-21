import Foundation

public struct PlanningRequest: Equatable, Sendable {
  public var instruction: String
  public var variantCount: Int
  public var output: OutputProfile
  public var duration: Double

  public init(instruction: String, variantCount: Int, output: OutputProfile, duration: Double) {
    self.instruction = instruction
    self.variantCount = variantCount
    self.output = output
    self.duration = duration
  }
}

public protocol VariantPlanning: Sendable {
  func plan(_ request: PlanningRequest) async throws -> [EffectGraph]
}

public enum PlanningError: Error, Equatable, Sendable {
  case variantCountOutOfRange
  case invalidDuration
}

public struct DeterministicDemoPlanner: VariantPlanning {
  private let provenance = PlannerProvenance(
    kind: .deterministicDemo, name: "milestone-preset-planner", version: "1.0.0")

  public init() {}

  public func plan(_ request: PlanningRequest) async throws -> [EffectGraph] {
    guard (2...5).contains(request.variantCount) else { throw PlanningError.variantCountOutOfRange }
    guard request.duration.isFinite, request.duration > 0 else {
      throw PlanningError.invalidDuration
    }
    let recipes = [animeRecipe, comicRecipe, cleanPulseRecipe, noirRecipe, vhsRecipe]
    return recipes.prefix(request.variantCount).enumerated().map { index, recipe in
      recipe(index, request)
    }
  }

  private func baseEffects() -> [EffectNode] {
    [
      EffectNode(
        type: .cropAutoSubject, parameters: .init(target: "primary_person"), required: true),
      EffectNode(type: .audioNormalize, required: false),
    ]
  }

  private func animeRecipe(_ index: Int, _ request: PlanningRequest) -> EffectGraph {
    graph(
      index: index, label: "Cel Study",
      summary: "Cel-shaded approximation with restrained outlines and bold captions.",
      request: request,
      effects: baseEffects() + [
        EffectNode(type: .styleCel, parameters: .init(strength: 0.68)),
        EffectNode(type: .captionDynamic, parameters: .init(preset: "bold")),
      ])
  }

  private func comicRecipe(_ index: Int, _ request: PlanningRequest) -> EffectGraph {
    graph(
      index: index, label: "Comic Ink",
      summary: "Higher-contrast comic approximation with ink outlines and faster beat zooms.",
      request: request,
      effects: baseEffects() + [
        EffectNode(type: .styleComic, parameters: .init(strength: 0.78)),
        EffectNode(type: .outline, parameters: .init(strength: 0.55)),
        EffectNode(type: .beatZoom, parameters: .init(intensity: 0.28)),
      ])
  }

  private func cleanPulseRecipe(_ index: Int, _ request: PlanningRequest) -> EffectGraph {
    graph(
      index: index, label: "Clean Pulse",
      summary:
        "Original subject with replaced background, dynamic captions, and restrained beat flashes.",
      request: request,
      effects: baseEffects() + [
        EffectNode(type: .backgroundReplace, parameters: .init(preset: "soft_gradient")),
        EffectNode(type: .captionDynamic, parameters: .init(preset: "bold")),
        EffectNode(type: .beatFlash, parameters: .init(intensity: 0.42)),
      ])
  }

  private func noirRecipe(_ index: Int, _ request: PlanningRequest) -> EffectGraph {
    graph(
      index: index, label: "Noir Cut",
      summary: "Monochrome cinematic approximation with slower crossfades.", request: request,
      effects: baseEffects() + [
        EffectNode(type: .styleNoir, parameters: .init(strength: 0.72)),
        EffectNode(type: .transitionCrossfade, parameters: .init(duration: 0.28)),
      ])
  }

  private func vhsRecipe(_ index: Int, _ request: PlanningRequest) -> EffectGraph {
    graph(
      index: index, label: "Tape Hook",
      summary: "VHS approximation with a short title hook and beat flashes.", request: request,
      effects: baseEffects() + [
        EffectNode(type: .styleVHS, parameters: .init(strength: 0.58)),
        EffectNode(type: .titleCard, parameters: .init(text: "WATCH THIS")),
        EffectNode(type: .beatFlash, parameters: .init(intensity: 0.3)),
      ])
  }

  private func graph(
    index: Int, label: String, summary: String, request: PlanningRequest, effects: [EffectNode]
  ) -> EffectGraph {
    let stableID = UUID(uuidString: String(format: "00000000-0000-4000-8000-%012d", index + 1))!
    return EffectGraph(
      id: stableID,
      label: label,
      differenceSummary: summary,
      provenance: provenance,
      output: request.output,
      timeline: [TimelineSegment(start: 0, end: request.duration, effects: effects)]
    )
  }
}
