import Foundation

public enum EffectCost: Int, Codable, Comparable, Sendable {
    case light = 1
    case medium = 3
    case heavy = 7

    public static func < (lhs: EffectCost, rhs: EffectCost) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

public enum EffectCategory: String, CaseIterable, Codable, Sendable {
    case framing = "Framing"
    case timing = "Timing"
    case text = "Text"
    case look = "Looks"
    case subject = "Subject"
    case rhythm = "Rhythm"
    case audio = "Audio"
}

public enum EffectReadiness: String, Codable, Sendable {
    case ready
    case approximation
    case fallback
}

public enum EffectParameterKind: String, CaseIterable, Sendable {
    case strength
    case intensity
    case rate
    case duration
}

public enum EffectTextParameterKind: String, CaseIterable, Sendable {
    case target
    case preset
    case text
}

public struct EffectTextParameterDescriptor: Equatable, Sendable {
    public let kind: EffectTextParameterKind
    public let defaultValue: String
    public let options: [String]

    public init(kind: EffectTextParameterKind, defaultValue: String, options: [String] = []) {
        self.kind = kind
        self.defaultValue = defaultValue
        self.options = options
    }
}

public struct EffectParameterDescriptor: Equatable, Sendable {
    public let kind: EffectParameterKind
    public let rule: ParameterRule
    public let defaultValue: Double
}

public struct ParameterRule: Equatable, Sendable {
    public let minimum: Double
    public let maximum: Double

    public init(_ minimum: Double, _ maximum: Double) {
        self.minimum = minimum
        self.maximum = maximum
    }

    public func contains(_ value: Double) -> Bool {
        minimum...maximum ~= value
    }
}

public struct EffectDefinition: Equatable, Sendable {
    public let type: EffectType
    public let displayName: String
    public let category: EffectCategory
    public let cost: EffectCost
    public let readiness: EffectReadiness
    public let fallbackReason: String?
    public let isApproximation: Bool
    public let allowsPassthroughFallback: Bool
    public let strength: ParameterRule?
    public let intensity: ParameterRule?
    public let rate: ParameterRule?
    public let duration: ParameterRule?

    public init(
        type: EffectType,
        displayName: String,
        category: EffectCategory,
        cost: EffectCost,
        readiness: EffectReadiness = .ready,
        fallbackReason: String? = nil,
        isApproximation: Bool = false,
        allowsPassthroughFallback: Bool = true,
        strength: ParameterRule? = nil,
        intensity: ParameterRule? = nil,
        rate: ParameterRule? = nil,
        duration: ParameterRule? = nil
    ) {
        self.type = type
        self.displayName = displayName
        self.category = category
        self.cost = cost
        self.readiness = readiness
        self.fallbackReason = fallbackReason
        self.isApproximation = isApproximation
        self.allowsPassthroughFallback = allowsPassthroughFallback
        self.strength = strength
        self.intensity = intensity
        self.rate = rate
        self.duration = duration
    }

    public var parameters: [EffectParameterDescriptor] {
        [
            strength.map { .init(kind: .strength, rule: $0, defaultValue: 0.65) },
            intensity.map { .init(kind: .intensity, rule: $0, defaultValue: 0.5) },
            rate.map { .init(kind: .rate, rule: $0, defaultValue: 1) },
            duration.map { .init(kind: .duration, rule: $0, defaultValue: 0.2) },
        ].compactMap { $0 }
    }

    public var defaultParameters: EffectParameters {
        EffectParameters(
            target: type == .cropAutoSubject ? "primary_person" : nil,
            preset: type == .captionDynamic ? "bold" : (type == .backgroundReplace ? "soft_gradient" : nil),
            text: type == .titleCard ? "Title" : nil,
            strength: strength == nil ? nil : 0.65,
            intensity: intensity == nil ? nil : 0.5,
            rate: rate == nil ? nil : 1,
            duration: duration == nil ? nil : 0.2
        )
    }

    public var textParameters: [EffectTextParameterDescriptor] {
        switch type {
        case .cropAutoSubject:
            [.init(kind: .target, defaultValue: "primary_person", options: ["primary_person", "center"])]
        case .captionDynamic:
            [.init(kind: .preset, defaultValue: "bold", options: ["bold", "minimal", "karaoke"])]
        case .titleCard:
            [.init(kind: .text, defaultValue: "Title")]
        case .backgroundReplace:
            [.init(kind: .preset, defaultValue: "soft_gradient", options: ["soft_gradient", "studio_dark", "paper"])]
        default:
            []
        }
    }
}

public struct EffectRegistry: Sendable {
    private let definitions: [EffectType: EffectDefinition]

    public init(definitions: [EffectDefinition]) {
        self.definitions = Dictionary(uniqueKeysWithValues: definitions.map { ($0.type, $0) })
    }

    public subscript(type: EffectType) -> EffectDefinition? {
        definitions[type]
    }

    public var allDefinitions: [EffectDefinition] {
        EffectType.allCases.compactMap { definitions[$0] }
    }

    public static let standard = EffectRegistry(definitions: EffectType.allCases.map { type in
        let styleTypes: Set<EffectType> = [.styleAnime, .styleComic, .styleSketch, .styleWatercolor, .styleCel, .styleCinematic, .styleNoir, .styleVHS]
        let mediumTypes: Set<EffectType> = [.backgroundBlur, .backgroundReplace, .outline, .glow, .beatFlash, .beatZoom, .transitionCrossfade]
        let fallbackReasons: [EffectType: String] = [
            .cropAutoSubject: "Subject tracking is pending; preview uses a center crop.",
            .backgroundReplace: "Subject segmentation is pending; the original background is retained.",
            .captionDynamic: "Text overlay rendering is pending; captions remain in the graph.",
            .titleCard: "Title overlay rendering is pending; the title remains in the graph.",
        ]
        return EffectDefinition(
            type: type,
            displayName: type.displayName,
            category: type.category,
            cost: styleTypes.contains(type) ? .heavy : (mediumTypes.contains(type) ? .medium : .light),
            readiness: fallbackReasons[type] == nil ? (styleTypes.contains(type) ? .approximation : .ready) : .fallback,
            fallbackReason: fallbackReasons[type],
            isApproximation: styleTypes.contains(type),
            allowsPassthroughFallback: type != .cropAutoSubject && type != .resize && type != .trim,
            strength: styleTypes.contains(type) || [.backgroundBlur, .outline, .glow].contains(type) ? ParameterRule(0, 1) : nil,
            intensity: [.beatFlash, .beatZoom, .colorGrade].contains(type) ? ParameterRule(0, 1) : nil,
            rate: type == .speed ? ParameterRule(0.25, 4) : nil,
            duration: type == .transitionCrossfade ? ParameterRule(0.05, 2) : nil
        )
    })
}

public extension EffectType {
    var displayName: String {
        rawValue.split(separator: ".").last.map { word in
            word.split(separator: "_").map { $0.capitalized }.joined(separator: " ")
        } ?? rawValue
    }

    var category: EffectCategory {
        switch self {
        case .cropAutoSubject, .resize: .framing
        case .trim, .speed, .transitionCrossfade: .timing
        case .captionDynamic, .titleCard: .text
        case .audioNormalize: .audio
        case .backgroundBlur, .backgroundReplace, .outline, .glow: .subject
        case .beatFlash, .beatZoom: .rhythm
        case .colorGrade, .styleAnime, .styleComic, .styleSketch, .styleWatercolor, .styleCel, .styleCinematic, .styleNoir, .styleVHS: .look
        }
    }
}
