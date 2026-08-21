import Foundation

#if canImport(FoundationModels)
  import FoundationModels
#endif

public enum LocalModelAvailability: Equatable, Sendable {
  case available
  case unavailable(String)
}

public enum GeneratedPlanMappingError: Error, Equatable, Sendable {
  case wrongVariantCount(expected: Int, actual: Int)
  case emptyLabel(Int)
  case emptyEffects(Int)
  case unsupportedEffect(String)
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
  public init() {}

  public func map(_ draft: GeneratedPlanDraft, for request: PlanningRequest) throws -> [EffectGraph]
  {
    guard draft.variants.count == request.variantCount else {
      throw GeneratedPlanMappingError.wrongVariantCount(
        expected: request.variantCount, actual: draft.variants.count)
    }
    let provenance = PlannerProvenance(
      kind: .localModel, name: "apple-foundation-model", version: "system")
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
      return .init(strength: draft.strength)
    }
    if [.beatFlash, .beatZoom, .colorGrade].contains(type) {
      return .init(intensity: draft.intensity)
    }
    switch type {
    case .speed: return .init(rate: draft.rate)
    case .transitionCrossfade: return .init(duration: draft.duration)
    case .backgroundReplace:
      return .init(preset: draft.preset.isEmpty ? "soft_gradient" : draft.preset)
    case .captionDynamic:
      return .init(
        preset: draft.preset.isEmpty ? "bold" : draft.preset,
        text: draft.text.isEmpty ? nil : draft.text)
    case .titleCard: return .init(text: draft.text.isEmpty ? "WATCH THIS" : draft.text)
    case .cropAutoSubject:
      return .init(target: draft.target.isEmpty ? "primary_person" : draft.target)
    default: return .init()
    }
  }

  private func stableUUID(variant: Int, effect: Int? = nil, segment: Int? = nil) -> UUID {
    let suffix = variant * 10_000 + (effect.map { 100 + $0 } ?? segment.map { 50 + $0 } ?? 1)
    return UUID(uuidString: String(format: "10000000-0000-4000-8000-%012d", suffix))!
  }
}

public struct PreferredVariantPlanner: VariantPlanning {
  private let fallback: DeterministicDemoPlanner
  private let primaryOverride: (@Sendable (PlanningRequest) async throws -> [EffectGraph])?

  public init(
    fallback: DeterministicDemoPlanner = .init(),
    primaryOverride: (@Sendable (PlanningRequest) async throws -> [EffectGraph])? = nil
  ) {
    self.fallback = fallback
    self.primaryOverride = primaryOverride
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
    if let primaryOverride {
      do { return try await primaryOverride(request) } catch {
        return try await fallback.plan(request)
      }
    }
    #if canImport(FoundationModels)
      if #available(macOS 26.0, *), SystemLanguageModel.default.isAvailable {
        do {
          return try await AppleFoundationPlanGenerator().plan(request)
        } catch {
          return try await fallback.plan(request)
        }
      }
    #endif
    return try await fallback.plan(request)
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
  private struct AppleFoundationPlanGenerator {
    func plan(_ request: PlanningRequest) async throws -> [EffectGraph] {
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
      let draft = GeneratedPlanDraft(
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
      let mapped = try GeneratedPlanMapper().map(draft, for: request)
      let validator = EffectGraphValidator()
      return try mapped.map { try validator.validate($0).graph }
    }
  }
#endif
