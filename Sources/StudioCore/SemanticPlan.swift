import CryptoKit
import Foundation

public enum SemanticPlanDecision: String, Codable, Sendable {
    case plan
    case clarify
    case unsupported
}

public enum SemanticOutputIntent: String, Codable, Sendable {
    case vertical
    case landscape
    case square
    case source
}

public struct SemanticEffect: Codable, Equatable, Sendable {
    public var type: EffectType
    public var strength: Double?
    public var intensity: Double?
    public var rate: Double?
    public var duration: Double?
    public var target: String?
    public var preset: String?
    public var text: String?

    public init(
        type: EffectType,
        strength: Double? = nil,
        intensity: Double? = nil,
        rate: Double? = nil,
        duration: Double? = nil,
        target: String? = nil,
        preset: String? = nil,
        text: String? = nil
    ) {
        self.type = type
        self.strength = strength
        self.intensity = intensity
        self.rate = rate
        self.duration = duration
        self.target = target
        self.preset = preset
        self.text = text
    }

    enum CodingKeys: String, CodingKey, StrictCodingKey {
        case type, strength, intensity, rate, duration, target, preset, text
        static let allKeys = ["type", "strength", "intensity", "rate", "duration", "target", "preset", "text"]
    }

    public init(from decoder: Decoder) throws {
        try decoder.rejectUnknownKeys(CodingKeys.self)
        let values = try decoder.container(keyedBy: CodingKeys.self)
        type = try values.decode(EffectType.self, forKey: .type)
        strength = try values.decodeIfPresent(Double.self, forKey: .strength)
        intensity = try values.decodeIfPresent(Double.self, forKey: .intensity)
        rate = try values.decodeIfPresent(Double.self, forKey: .rate)
        duration = try values.decodeIfPresent(Double.self, forKey: .duration)
        target = try values.decodeIfPresent(String.self, forKey: .target)
        preset = try values.decodeIfPresent(String.self, forKey: .preset)
        text = try values.decodeIfPresent(String.self, forKey: .text)
    }
}

public struct SemanticVariant: Codable, Equatable, Sendable {
    public var label: String
    public var output: SemanticOutputIntent
    public var effects: [SemanticEffect]

    public init(label: String, output: SemanticOutputIntent, effects: [SemanticEffect]) {
        self.label = label
        self.output = output
        self.effects = effects
    }

    enum CodingKeys: String, CodingKey, StrictCodingKey {
        case label, output, effects
        static let allKeys = ["label", "output", "effects"]
    }

    public init(from decoder: Decoder) throws {
        try decoder.rejectUnknownKeys(CodingKeys.self)
        let values = try decoder.container(keyedBy: CodingKeys.self)
        label = try values.decode(String.self, forKey: .label)
        output = try values.decode(SemanticOutputIntent.self, forKey: .output)
        effects = try values.decode([SemanticEffect].self, forKey: .effects)
    }
}

public struct SemanticPlan: Codable, Equatable, Sendable {
    public var recordID: String
    public var decision: SemanticPlanDecision
    public var reason: String
    public var variants: [SemanticVariant]

    public init(recordID: String, decision: SemanticPlanDecision, reason: String, variants: [SemanticVariant]) {
        self.recordID = recordID
        self.decision = decision
        self.reason = reason
        self.variants = variants
    }

    enum CodingKeys: String, CodingKey, StrictCodingKey {
        case recordID = "record_id", decision, reason, variants
        static let allKeys = ["record_id", "decision", "reason", "variants"]
    }

    public init(from decoder: Decoder) throws {
        try decoder.rejectUnknownKeys(CodingKeys.self)
        let values = try decoder.container(keyedBy: CodingKeys.self)
        recordID = try values.decode(String.self, forKey: .recordID)
        decision = try values.decode(SemanticPlanDecision.self, forKey: .decision)
        reason = try values.decode(String.self, forKey: .reason)
        variants = try values.decode([SemanticVariant].self, forKey: .variants)
    }
}

public enum SemanticPlanCompilationError: Error, Equatable, Sendable {
    case emptyRecordID
    case emptyReason
    case nonPlanContainsVariants
    case wrongVariantCount(expected: Int, actual: Int)
    case emptyLabel(Int)
    case emptyEffects(Int)
    case invalidGraph(Int, GraphValidationFailure)
}

public struct SemanticPlanCompilation: Equatable, Sendable {
    public let decision: SemanticPlanDecision
    public let reason: String
    public let graphs: [EffectGraph]
}

public struct SemanticPlanCompiler: Sendable {
    private let validator: EffectGraphValidator

    public init(validator: EffectGraphValidator = .init()) {
        self.validator = validator
    }

    public func compile(
        _ plan: SemanticPlan,
        request: PlanningRequest,
        provenance: PlannerProvenance
    ) throws -> SemanticPlanCompilation {
        guard !plan.recordID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw SemanticPlanCompilationError.emptyRecordID
        }
        guard !plan.reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw SemanticPlanCompilationError.emptyReason
        }
        guard plan.decision == .plan else {
            guard plan.variants.isEmpty else { throw SemanticPlanCompilationError.nonPlanContainsVariants }
            return SemanticPlanCompilation(decision: plan.decision, reason: plan.reason, graphs: [])
        }
        guard plan.variants.count == request.variantCount else {
            throw SemanticPlanCompilationError.wrongVariantCount(expected: request.variantCount, actual: plan.variants.count)
        }

        let graphs = try plan.variants.enumerated().map { variantIndex, variant in
            let label = variant.label.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !label.isEmpty else { throw SemanticPlanCompilationError.emptyLabel(variantIndex) }
            guard !variant.effects.isEmpty else { throw SemanticPlanCompilationError.emptyEffects(variantIndex) }
            let graph = EffectGraph(
                id: stableUUID(seed: "\(plan.recordID):variant:\(variantIndex)"),
                label: label,
                differenceSummary: differenceSummary(for: variant),
                provenance: provenance,
                output: outputProfile(for: variant.output, source: request.output),
                timeline: [TimelineSegment(
                    id: stableUUID(seed: "\(plan.recordID):variant:\(variantIndex):segment:0"),
                    start: 0,
                    end: request.duration,
                    effects: variant.effects.enumerated().map { effectIndex, effect in
                        EffectNode(
                            id: stableUUID(seed: "\(plan.recordID):variant:\(variantIndex):effect:\(effectIndex)"),
                            type: effect.type,
                            parameters: EffectParameters(
                                target: effect.target,
                                preset: effect.preset,
                                text: effect.text,
                                strength: effect.strength,
                                intensity: effect.intensity,
                                rate: effect.rate,
                                duration: effect.duration
                            ),
                            required: true
                        )
                    }
                )]
            )
            do {
                return try validator.validate(graph).graph
            } catch let failure as GraphValidationFailure {
                throw SemanticPlanCompilationError.invalidGraph(variantIndex, failure)
            }
        }
        return SemanticPlanCompilation(decision: .plan, reason: plan.reason, graphs: graphs)
    }

    private func outputProfile(for intent: SemanticOutputIntent, source: OutputProfile) -> OutputProfile {
        switch intent {
        case .vertical: OutputProfile(aspectRatio: .vertical, width: 1080, height: 1920, fps: source.fps)
        case .landscape: OutputProfile(aspectRatio: .landscape, width: 1920, height: 1080, fps: source.fps)
        case .square: OutputProfile(aspectRatio: .square, width: 1080, height: 1080, fps: source.fps)
        case .source: source
        }
    }

    private func differenceSummary(for variant: SemanticVariant) -> String {
        let effects = variant.effects.map(\.type.rawValue).joined(separator: ", ")
        return "\(variant.label): \(effects)."
    }

    private func stableUUID(seed: String) -> UUID {
        let digest = SHA256.hash(data: Data(seed.utf8)).map { String(format: "%02x", $0) }.joined()
        let value = "\(digest.prefix(8))-\(digest.dropFirst(8).prefix(4))-4\(digest.dropFirst(13).prefix(3))-8\(digest.dropFirst(17).prefix(3))-\(digest.dropFirst(20).prefix(12))"
        return UUID(uuidString: value)!
    }
}
