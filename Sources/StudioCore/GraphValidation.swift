import CryptoKit
import Foundation

public enum DiagnosticSeverity: String, Codable, Sendable {
    case warning
    case error
}

public struct GraphDiagnostic: Error, Codable, Equatable, Sendable {
    public let severity: DiagnosticSeverity
    public let path: String
    public let message: String

    public init(severity: DiagnosticSeverity, path: String, message: String) {
        self.severity = severity
        self.path = path
        self.message = message
    }
}

public struct NormalizedGraph: Equatable, Sendable {
    public let graph: EffectGraph
    public let warnings: [GraphDiagnostic]
    public let canonicalHash: String

    public init(graph: EffectGraph, warnings: [GraphDiagnostic], canonicalHash: String) {
        self.graph = graph
        self.warnings = warnings
        self.canonicalHash = canonicalHash
    }
}

public struct GraphValidationFailure: Error, Equatable, Sendable {
    public let diagnostics: [GraphDiagnostic]

    public init(diagnostics: [GraphDiagnostic]) {
        self.diagnostics = diagnostics
    }
}

public struct EffectGraphValidator: Sendable {
    public let registry: EffectRegistry

    public init(registry: EffectRegistry = .standard) {
        self.registry = registry
    }

    public func validate(_ input: EffectGraph) throws -> NormalizedGraph {
        var graph = input
        var diagnostics: [GraphDiagnostic] = []

        if graph.schemaVersion != StudioCore.effectGraphSchemaVersion {
            diagnostics.append(.init(severity: .error, path: "schema_version", message: "Unsupported effect graph schema \(graph.schemaVersion)."))
        }
        if graph.label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            diagnostics.append(.init(severity: .error, path: "label", message: "Variant label cannot be empty."))
        }
        if graph.differenceSummary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            diagnostics.append(.init(severity: .error, path: "difference_summary", message: "A visible difference summary is required."))
        }
        validateOutput(graph.output, diagnostics: &diagnostics)

        graph.timeline.sort { lhs, rhs in
            lhs.start == rhs.start ? lhs.end < rhs.end : lhs.start < rhs.start
        }

        for segmentIndex in graph.timeline.indices {
            let path = "timeline[\(segmentIndex)]"
            let segment = graph.timeline[segmentIndex]
            if !segment.start.isFinite || !segment.end.isFinite || segment.start < 0 || segment.end <= segment.start {
                diagnostics.append(.init(severity: .error, path: path, message: "Timeline interval must have finite, non-negative start and end greater than start."))
            }
            for effectIndex in segment.effects.indices {
                let effectPath = "\(path).effects[\(effectIndex)]"
                validate(segment.effects[effectIndex], path: effectPath, diagnostics: &diagnostics)
            }
            resolveBackgroundConflict(in: &graph.timeline[segmentIndex], path: path, diagnostics: &diagnostics)
        }

        let errors = diagnostics.filter { $0.severity == .error }
        guard errors.isEmpty else { throw GraphValidationFailure(diagnostics: diagnostics) }

        let canonicalData = try canonicalData(for: graph)
        let digest = SHA256.hash(data: canonicalData)
        let hash = digest.map { String(format: "%02x", $0) }.joined()
        return NormalizedGraph(graph: graph, warnings: diagnostics, canonicalHash: hash)
    }

    private func validateOutput(_ output: OutputProfile, diagnostics: inout [GraphDiagnostic]) {
        if output.width < 64 || output.height < 64 || output.width > 7680 || output.height > 7680 {
            diagnostics.append(.init(severity: .error, path: "output", message: "Output dimensions must be between 64 and 7680 pixels."))
        }
        if !(1...120).contains(output.fps) {
            diagnostics.append(.init(severity: .error, path: "output.fps", message: "Frame rate must be between 1 and 120 FPS."))
        }
        let isOrientationValid = switch output.aspectRatio {
        case .vertical: output.height > output.width
        case .landscape: output.width > output.height
        case .square: output.width == output.height
        }
        if !isOrientationValid {
            diagnostics.append(.init(severity: .error, path: "output.aspect_ratio", message: "Dimensions do not match the declared aspect ratio."))
        }
    }

    private func validate(_ effect: EffectNode, path: String, diagnostics: inout [GraphDiagnostic]) {
        guard let definition = registry[effect.type] else {
            diagnostics.append(.init(severity: .error, path: "\(path).type", message: "Effect is not registered."))
            return
        }
        validate(effect.parameters.strength, rule: definition.strength, name: "strength", path: path, diagnostics: &diagnostics)
        validate(effect.parameters.intensity, rule: definition.intensity, name: "intensity", path: path, diagnostics: &diagnostics)
        validate(effect.parameters.rate, rule: definition.rate, name: "rate", path: path, diagnostics: &diagnostics)
        validate(effect.parameters.duration, rule: definition.duration, name: "duration", path: path, diagnostics: &diagnostics)
        if definition.isApproximation {
            diagnostics.append(.init(severity: .warning, path: path, message: "\(definition.displayName) uses a deterministic realtime approximation."))
        }
    }

    private func validate(_ value: Double?, rule: ParameterRule?, name: String, path: String, diagnostics: inout [GraphDiagnostic]) {
        guard let value else { return }
        guard let rule, value.isFinite, rule.contains(value) else {
            let range = rule.map { "\($0.minimum)...\($0.maximum)" } ?? "not supported"
            diagnostics.append(.init(severity: .error, path: "\(path).parameters.\(name)", message: "Parameter \(name) is outside its allowed range (\(range))."))
            return
        }
    }

    private func resolveBackgroundConflict(in segment: inout TimelineSegment, path: String, diagnostics: inout [GraphDiagnostic]) {
        let hasReplace = segment.effects.contains { $0.type == .backgroundReplace }
        let hasBlur = segment.effects.contains { $0.type == .backgroundBlur }
        guard hasReplace && hasBlur else { return }
        segment.effects.removeAll { $0.type == .backgroundBlur }
        diagnostics.append(.init(severity: .warning, path: path, message: "Background replacement takes precedence; background blur was removed."))
    }

    private func canonicalData(for graph: EffectGraph) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(graph)
    }
}

public enum WorkClass: String, Codable, Comparable, Sendable {
    case light
    case medium
    case heavy

    public static func < (lhs: WorkClass, rhs: WorkClass) -> Bool {
        let order: [WorkClass] = [.light, .medium, .heavy]
        return order.firstIndex(of: lhs)! < order.firstIndex(of: rhs)!
    }
}

public struct RenderEstimate: Equatable, Sendable {
    public let workClass: WorkClass
    public let pixelFrames: Double
    public let costUnits: Double
    public let responsibleEffects: [EffectType]
    public let recommendedPreviewLongEdge: Int
    public let estimatedBytes: Int64
}

public struct RenderEstimator: Sendable {
    public let registry: EffectRegistry

    public init(registry: EffectRegistry = .standard) {
        self.registry = registry
    }

    public func estimate(_ graph: EffectGraph) -> RenderEstimate {
        let duration = graph.timeline.map(\.end).max() ?? 0
        let pixelFrames = Double(graph.output.width * graph.output.height * graph.output.fps) * duration
        let types = graph.timeline.flatMap(\.effects).map(\.type)
        let effectCost = types.reduce(0) { $0 + (registry[$1]?.cost.rawValue ?? 10) }
        let costUnits = pixelFrames / 1_000_000 * Double(max(effectCost, 1))
        let workClass: WorkClass = costUnits < 3_000 ? .light : (costUnits < 12_000 ? .medium : .heavy)
        let responsible = Array(Set(types.filter { (registry[$0]?.cost ?? .heavy) >= .heavy })).sorted { $0.rawValue < $1.rawValue }
        let previewEdge = workClass == .heavy || !responsible.isEmpty ? 960 : 1280
        let estimatedBytes = Int64(max(duration, 1) * Double(graph.output.width * graph.output.height) * 0.12)
        return RenderEstimate(workClass: workClass, pixelFrames: pixelFrames, costUnits: costUnits, responsibleEffects: responsible, recommendedPreviewLongEdge: previewEdge, estimatedBytes: estimatedBytes)
    }
}

public struct DiskSpacePreflight: Equatable, Sendable {
    public let requiredBytes: Int64
    public let availableBytes: Int64
    public init(requiredBytes: Int64, availableBytes: Int64) {
        self.requiredBytes = requiredBytes
        self.availableBytes = availableBytes
    }
    public var canStart: Bool { availableBytes >= requiredBytes }
    public var additionalBytesRequired: Int64 { max(requiredBytes - availableBytes, 0) }
}
