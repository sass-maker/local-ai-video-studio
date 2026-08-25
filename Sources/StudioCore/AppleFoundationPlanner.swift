import Foundation

#if canImport(FoundationModels)
  import FoundationModels
#endif

public enum LocalModelAvailability: Equatable, Sendable {
  case available
  case unavailable(String)

  /// The actionable reason the on-device model cannot be used, if any.
  public var unavailableReason: String? {
    switch self {
    case .available: nil
    case .unavailable(let reason): reason
    }
  }
}

public enum GeneratedPlanMappingError: Error, Equatable, Sendable {
  case wrongVariantCount(expected: Int, actual: Int)
  case emptyLabel(Int)
  case emptyEffects(Int)
  case unsupportedEffect(String)

  /// A short, human-readable explanation suitable for the app and agent output.
  public var explanation: String {
    switch self {
    case .wrongVariantCount(let expected, let actual):
      "the model returned \(actual) variants instead of \(expected)"
    case .emptyLabel(let index):
      "variant \(index + 1) had no label"
    case .emptyEffects(let index):
      "variant \(index + 1) contained no effects"
    case .unsupportedEffect(let identifier):
      "the model proposed the unsupported effect “\(identifier)”"
    }
  }
}

public struct GeneratedEffectDraft: Equatable, Sendable {
  public var type: String
  public var strength: Double
  public var intensity: Double
  public var rate: Double
  public var duration: Double
  public var preset: String
  public var text: String
  public var target: String

  public init(
    type: String, strength: Double = 0.5, intensity: Double = 0.5, rate: Double = 1,
    duration: Double = 0.2, preset: String = "", text: String = "",
    target: String = "primary_person"
  ) {
    self.type = type
    self.strength = strength
    self.intensity = intensity
    self.rate = rate
    self.duration = duration
    self.preset = preset
    self.text = text
    self.target = target
  }
}

public struct GeneratedVariantDraft: Equatable, Sendable {
  public var label: String
  public var summary: String
  public var effects: [GeneratedEffectDraft]

  public init(label: String, summary: String, effects: [GeneratedEffectDraft]) {
    self.label = label
    self.summary = summary
    self.effects = effects
  }
}

public struct GeneratedPlanDraft: Equatable, Sendable {
  public var variants: [GeneratedVariantDraft]
  public init(variants: [GeneratedVariantDraft]) { self.variants = variants }
}

public struct GeneratedPlanMapper: Sendable {
  public let provenance: PlannerProvenance

  public init(modelIdentifier: String = appleFoundationModelIdentifier) {
    provenance = PlannerProvenance(
      kind: .localModel, name: modelIdentifier, version: "system")
  }

  public func map(_ draft: GeneratedPlanDraft, for request: PlanningRequest) throws -> [EffectGraph]
  {
    guard draft.variants.count == request.variantCount else {
      throw GeneratedPlanMappingError.wrongVariantCount(
        expected: request.variantCount, actual: draft.variants.count)
    }
    return try draft.variants.enumerated().map { variantIndex, variant in
      let label = variant.label.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !label.isEmpty else { throw GeneratedPlanMappingError.emptyLabel(variantIndex) }
      guard !variant.effects.isEmpty else {
        throw GeneratedPlanMappingError.emptyEffects(variantIndex)
      }
      let effects = try variant.effects.enumerated().map { effectIndex, effect in
        guard let type = EffectType(rawValue: effect.type) else {
          throw GeneratedPlanMappingError.unsupportedEffect(effect.type)
        }
        return EffectNode(
          id: stableUUID(variant: variantIndex, effect: effectIndex),
          type: type,
          parameters: parameters(for: type, draft: effect),
          required: [.cropAutoSubject, .resize, .trim].contains(type)
        )
      }
      return EffectGraph(
        id: stableUUID(variant: variantIndex),
        label: label,
        differenceSummary: variant.summary,
        provenance: provenance,
        output: request.output,
        timeline: [
          TimelineSegment(
            id: stableUUID(variant: variantIndex, segment: 0), start: 0, end: request.duration,
            effects: effects)
        ]
      )
    }
  }

  private func parameters(for type: EffectType, draft: GeneratedEffectDraft) -> EffectParameters {
    let styleTypes: Set<EffectType> = [
      .styleAnime, .styleComic, .styleSketch, .styleWatercolor, .styleCel, .styleCinematic,
      .styleNoir, .styleVHS,
    ]
    if styleTypes.contains(type) || [.backgroundBlur, .outline, .glow].contains(type) {
      return EffectParameters(strength: draft.strength)
    }
    if [.beatFlash, .beatZoom, .colorGrade].contains(type) {
      return EffectParameters(intensity: draft.intensity)
    }
    switch type {
    case .speed: return EffectParameters(rate: draft.rate)
    case .transitionCrossfade: return EffectParameters(duration: draft.duration)
    case .backgroundReplace:
      return EffectParameters(preset: draft.preset.isEmpty ? "soft_gradient" : draft.preset)
    case .captionDynamic:
      return EffectParameters(
        preset: draft.preset.isEmpty ? "bold" : draft.preset,
        text: draft.text.isEmpty ? nil : draft.text)
    case .titleCard:
      return EffectParameters(text: draft.text.isEmpty ? "WATCH THIS" : draft.text)
    case .cropAutoSubject:
      return EffectParameters(target: draft.target.isEmpty ? "primary_person" : draft.target)
    default: return EffectParameters()
    }
  }

  private func stableUUID(variant: Int, effect: Int? = nil, segment: Int? = nil) -> UUID {
    let suffix = variant * 10_000 + (effect.map { 100 + $0 } ?? segment.map { 50 + $0 } ?? 1)
    return UUID(uuidString: String(format: "10000000-0000-4000-8000-%012d", suffix))!
  }
}

/// The stable identifier recorded as planner provenance for Apple's on-device model.
public let appleFoundationModelIdentifier = "apple-foundation-model"

/// The injectable seam for a local model that produces guided plan drafts.
///
/// Production uses Apple's `SystemLanguageModel`; tests inject a fake so the
/// suite never depends on Apple Intelligence being enabled.
public protocol GeneratedPlanProducing: Sendable {
  var modelIdentifier: String { get }
  func generatePlan(_ request: PlanningRequest) async throws -> GeneratedPlanDraft
}

/// Which planner produced a plan, and why a fallback happened when it did.
public struct PlanningDisclosure: Equatable, Sendable {
  public var provenance: PlannerProvenance
  public var fallbackReason: String?

  public init(provenance: PlannerProvenance, fallbackReason: String? = nil) {
    self.provenance = provenance
    self.fallbackReason = fallbackReason
  }
}

public struct PlanningOutcome: Equatable, Sendable {
  public var graphs: [EffectGraph]
  public var disclosure: PlanningDisclosure

  public init(graphs: [EffectGraph], disclosure: PlanningDisclosure) {
    self.graphs = graphs
    self.disclosure = disclosure
  }
}

public struct PreferredVariantPlanner: VariantPlanning {
  private let fallback: DeterministicDemoPlanner
  private let model: GeneratedPlanProducing?
  private let validator: EffectGraphValidator

  public init(
    fallback: DeterministicDemoPlanner = DeterministicDemoPlanner(),
    model: GeneratedPlanProducing? = nil,
    validator: EffectGraphValidator = EffectGraphValidator()
  ) {
    self.fallback = fallback
    self.model = model
    self.validator = validator
  }

  public static var availability: LocalModelAvailability {
    #if canImport(FoundationModels)
      if #available(macOS 26.0, *) {
        switch SystemLanguageModel.default.availability {
        case .available: return .available
        case .unavailable(.deviceNotEligible):
          return .unavailable("This Mac is not eligible for Apple Intelligence.")
        case .unavailable(.appleIntelligenceNotEnabled):
          return .unavailable("Apple Intelligence is not enabled in System Settings.")
        case .unavailable(.modelNotReady):
          return .unavailable("Apple’s on-device model is not ready yet.")
        @unknown default:
          return .unavailable(
            "Apple’s on-device model is unavailable for an unknown system reason.")
        }
      }
    #endif
    return .unavailable("Apple Foundation Models requires macOS 26 or newer.")
  }

  public func plan(_ request: PlanningRequest) async throws -> [EffectGraph] {
    try await planDisclosed(request).graphs
  }

  /// Plans variants and reports which planner produced them.
  ///
  /// The local model is preferred whenever it is reachable. Generation,
  /// registry mapping, or validation failures fall back exactly once to the
  /// deterministic planner and carry an actionable reason.
  public func planDisclosed(_ request: PlanningRequest) async throws -> PlanningOutcome {
    guard (2...5).contains(request.variantCount) else {
      throw PlanningError.variantCountOutOfRange
    }
    guard let model = resolvedModel() else {
      return try await fallbackOutcome(request, reason: Self.availability.unavailableReason)
    }
    do {
      let mapper = GeneratedPlanMapper(modelIdentifier: model.modelIdentifier)
      let draft = try await model.generatePlan(request)
      let graphs = try mapper.map(draft, for: request).map { try validator.validate($0).graph }
      return PlanningOutcome(
        graphs: graphs, disclosure: PlanningDisclosure(provenance: mapper.provenance))
    } catch {
      return try await fallbackOutcome(request, reason: Self.reason(for: error))
    }
  }

  private func resolvedModel() -> GeneratedPlanProducing? {
    if let model { return model }
    #if canImport(FoundationModels)
      if #available(macOS 26.0, *), SystemLanguageModel.default.isAvailable {
        return AppleFoundationModel()
      }
    #endif
    return nil
  }

  private func fallbackOutcome(_ request: PlanningRequest, reason: String?) async throws
    -> PlanningOutcome
  {
    let graphs = try await fallback.plan(request)
    let provenance =
      graphs.first?.provenance
      ?? PlannerProvenance(kind: .deterministicDemo, name: "milestone-preset-planner", version: "0")
    return PlanningOutcome(
      graphs: graphs,
      disclosure: PlanningDisclosure(provenance: provenance, fallbackReason: reason))
  }

  private static func reason(for error: Error) -> String {
    if let mapping = error as? GeneratedPlanMappingError {
      return "Rejected the generated plan because \(mapping.explanation)."
    }
    if let validation = error as? GraphValidationFailure {
      let detail = validation.diagnostics.first.map { "\($0.path): \($0.message)" } ?? "unknown"
      return "The generated plan failed graph validation (\(detail))."
    }
    return "Apple’s on-device model could not produce a plan (\(error.localizedDescription))."
  }
}

#if canImport(FoundationModels)
  @available(macOS 26.0, *)
  @Generable
  private struct AppleGeneratedPlan {
    @Guide(
      description: "Create exactly the number of requested variants, from 2 through 5.",
      .count(2...5))
    var variants: [AppleGeneratedVariant]
  }

  @available(macOS 26.0, *)
  @Generable
  private struct AppleGeneratedVariant {
    @Guide(description: "A short distinctive human-readable name.")
    var label: String
    @Guide(description: "One sentence explaining how this version differs.")
    var summary: String
    @Guide(
      description: "Use only supported effect identifiers supplied in the prompt.", .count(1...8))
    var effects: [AppleGeneratedEffect]
  }

  @available(macOS 26.0, *)
  @Generable
  private struct AppleGeneratedEffect {
    @Guide(description: "An exact supported effect identifier supplied in the prompt.")
    var type: String
    @Guide(.range(0...1)) var strength: Double
    @Guide(.range(0...1)) var intensity: Double
    @Guide(.range(0.25...4)) var rate: Double
    @Guide(.range(0.05...2)) var duration: Double
    var preset: String
    var text: String
    var target: String
  }

  @available(macOS 26.0, *)
  private struct AppleFoundationModel: GeneratedPlanProducing {
    let modelIdentifier = appleFoundationModelIdentifier

    func generatePlan(_ request: PlanningRequest) async throws -> GeneratedPlanDraft {
      let supported = EffectType.allCases.map(\.rawValue).joined(separator: ", ")
      let session = LanguageModelSession(
        instructions: """
          You plan local video edits. Produce meaningfully different variants that follow the user instruction.
          Never invent effect identifiers. Keep parameters restrained unless the user explicitly asks for intensity.
          Use only the supplied supported effects. Do not describe or request code, shell commands, files, or network actions.
          """)
      let response = try await session.respond(
        to: """
          Editing instruction: \(request.instruction)
          Required variant count: \(request.variantCount)
          Video duration: \(request.duration) seconds
          Output: \(request.output.aspectRatio.rawValue), \(request.output.width)x\(request.output.height), \(request.output.fps) fps
          Supported effects: \(supported)
          Return exactly \(request.variantCount) variants. Each variant should use only effects needed to satisfy the instruction.
          """,
        generating: AppleGeneratedPlan.self
      )
      return GeneratedPlanDraft(
        variants: response.content.variants.map { variant in
          GeneratedVariantDraft(
            label: variant.label, summary: variant.summary,
            effects: variant.effects.map { effect in
              GeneratedEffectDraft(
                type: effect.type, strength: effect.strength, intensity: effect.intensity,
                rate: effect.rate, duration: effect.duration, preset: effect.preset,
                text: effect.text, target: effect.target)
            })
        })
    }
  }
#endif
