import Foundation

public enum AspectRatio: String, Codable, CaseIterable, Sendable {
    case vertical = "9:16"
    case landscape = "16:9"
    case square = "1:1"
}

public struct OutputProfile: Codable, Equatable, Sendable {
    public var aspectRatio: AspectRatio
    public var width: Int
    public var height: Int
    public var fps: Int

    public init(aspectRatio: AspectRatio, width: Int, height: Int, fps: Int) {
        self.aspectRatio = aspectRatio
        self.width = width
        self.height = height
        self.fps = fps
    }

    enum CodingKeys: String, CodingKey, StrictCodingKey {
        case aspectRatio = "aspect_ratio", width, height, fps
        static let allKeys = ["aspect_ratio", "width", "height", "fps"]
    }

    public init(from decoder: Decoder) throws {
        try decoder.rejectUnknownKeys(CodingKeys.self)
        let values = try decoder.container(keyedBy: CodingKeys.self)
        aspectRatio = try values.decode(AspectRatio.self, forKey: .aspectRatio)
        width = try values.decode(Int.self, forKey: .width)
        height = try values.decode(Int.self, forKey: .height)
        fps = try values.decode(Int.self, forKey: .fps)
    }
}

public enum EffectType: String, Codable, CaseIterable, Sendable {
    case cropAutoSubject = "crop.auto_subject"
    case resize = "frame.resize"
    case trim = "timeline.trim"
    case speed = "timeline.speed"
    case captionDynamic = "caption.dynamic"
    case titleCard = "title.card"
    case transitionCrossfade = "transition.crossfade"
    case colorGrade = "color.grade"
    case audioNormalize = "audio.normalize"
    case backgroundBlur = "background.blur"
    case backgroundReplace = "background.replace"
    case outline = "subject.outline"
    case glow = "subject.glow"
    case beatFlash = "beat.flash"
    case beatZoom = "beat.zoom"
    case styleAnime = "style.anime"
    case styleComic = "style.comic"
    case styleSketch = "style.sketch"
    case styleWatercolor = "style.watercolor"
    case styleCel = "style.cel"
    case styleCinematic = "style.cinematic"
    case styleNoir = "style.noir"
    case styleVHS = "style.vhs"
}

public struct EffectParameters: Codable, Equatable, Sendable {
    public var target: String?
    public var preset: String?
    public var text: String?
    public var strength: Double?
    public var intensity: Double?
    public var rate: Double?
    public var duration: Double?

    public init(
        target: String? = nil,
        preset: String? = nil,
        text: String? = nil,
        strength: Double? = nil,
        intensity: Double? = nil,
        rate: Double? = nil,
        duration: Double? = nil
    ) {
        self.target = target
        self.preset = preset
        self.text = text
        self.strength = strength
        self.intensity = intensity
        self.rate = rate
        self.duration = duration
    }

    enum CodingKeys: String, CodingKey, StrictCodingKey {
        case target, preset, text, strength, intensity, rate, duration
        static let allKeys = ["target", "preset", "text", "strength", "intensity", "rate", "duration"]
    }

    public init(from decoder: Decoder) throws {
        try decoder.rejectUnknownKeys(CodingKeys.self)
        let values = try decoder.container(keyedBy: CodingKeys.self)
        target = try values.decodeIfPresent(String.self, forKey: .target)
        preset = try values.decodeIfPresent(String.self, forKey: .preset)
        text = try values.decodeIfPresent(String.self, forKey: .text)
        strength = try values.decodeIfPresent(Double.self, forKey: .strength)
        intensity = try values.decodeIfPresent(Double.self, forKey: .intensity)
        rate = try values.decodeIfPresent(Double.self, forKey: .rate)
        duration = try values.decodeIfPresent(Double.self, forKey: .duration)
    }
}

public struct EffectNode: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var type: EffectType
    public var parameters: EffectParameters
    public var required: Bool

    public init(id: UUID = UUID(), type: EffectType, parameters: EffectParameters = .init(), required: Bool = false) {
        self.id = id
        self.type = type
        self.parameters = parameters
        self.required = required
    }

    enum CodingKeys: String, CodingKey, StrictCodingKey {
        case id, type, parameters, required
        static let allKeys = ["id", "type", "parameters", "required"]
    }

    public init(from decoder: Decoder) throws {
        try decoder.rejectUnknownKeys(CodingKeys.self)
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(UUID.self, forKey: .id)
        type = try values.decode(EffectType.self, forKey: .type)
        parameters = try values.decode(EffectParameters.self, forKey: .parameters)
        required = try values.decode(Bool.self, forKey: .required)
    }
}

public struct TimelineSegment: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var start: Double
    public var end: Double
    public var effects: [EffectNode]

    public init(id: UUID = UUID(), start: Double, end: Double, effects: [EffectNode]) {
        self.id = id
        self.start = start
        self.end = end
        self.effects = effects
    }

    enum CodingKeys: String, CodingKey, StrictCodingKey {
        case id, start, end, effects
        static let allKeys = ["id", "start", "end", "effects"]
    }

    public init(from decoder: Decoder) throws {
        try decoder.rejectUnknownKeys(CodingKeys.self)
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(UUID.self, forKey: .id)
        start = try values.decode(Double.self, forKey: .start)
        end = try values.decode(Double.self, forKey: .end)
        effects = try values.decode([EffectNode].self, forKey: .effects)
    }
}

public enum PlannerKind: String, Codable, Sendable {
    case deterministicDemo = "deterministic_demo"
    case localModel = "local_model"
}

public struct PlannerProvenance: Codable, Equatable, Sendable {
    public var kind: PlannerKind
    public var name: String
    public var version: String

    public init(kind: PlannerKind, name: String, version: String) {
        self.kind = kind
        self.name = name
        self.version = version
    }

    enum CodingKeys: String, CodingKey, StrictCodingKey {
        case kind, name, version
        static let allKeys = ["kind", "name", "version"]
    }

    public init(from decoder: Decoder) throws {
        try decoder.rejectUnknownKeys(CodingKeys.self)
        let values = try decoder.container(keyedBy: CodingKeys.self)
        kind = try values.decode(PlannerKind.self, forKey: .kind)
        name = try values.decode(String.self, forKey: .name)
        version = try values.decode(String.self, forKey: .version)
    }
}

public struct EffectGraph: Codable, Equatable, Identifiable, Sendable {
    public var schemaVersion: Int
    public var id: UUID
    public var label: String
    public var differenceSummary: String
    public var provenance: PlannerProvenance
    public var output: OutputProfile
    public var timeline: [TimelineSegment]

    public init(
        schemaVersion: Int = StudioCore.effectGraphSchemaVersion,
        id: UUID = UUID(),
        label: String,
        differenceSummary: String,
        provenance: PlannerProvenance,
        output: OutputProfile,
        timeline: [TimelineSegment]
    ) {
        self.schemaVersion = schemaVersion
        self.id = id
        self.label = label
        self.differenceSummary = differenceSummary
        self.provenance = provenance
        self.output = output
        self.timeline = timeline
    }

    enum CodingKeys: String, CodingKey, StrictCodingKey {
        case schemaVersion = "schema_version", id, label
        case differenceSummary = "difference_summary"
        case provenance, output, timeline
        static let allKeys = ["schema_version", "id", "label", "difference_summary", "provenance", "output", "timeline"]
    }

    public init(from decoder: Decoder) throws {
        try decoder.rejectUnknownKeys(CodingKeys.self)
        let values = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try values.decode(Int.self, forKey: .schemaVersion)
        id = try values.decode(UUID.self, forKey: .id)
        label = try values.decode(String.self, forKey: .label)
        differenceSummary = try values.decode(String.self, forKey: .differenceSummary)
        provenance = try values.decode(PlannerProvenance.self, forKey: .provenance)
        output = try values.decode(OutputProfile.self, forKey: .output)
        timeline = try values.decode([TimelineSegment].self, forKey: .timeline)
    }
}
