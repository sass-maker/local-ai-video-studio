import Foundation

public enum EffectGraphEditError: Error, Equatable, Sendable {
    case missingTimeline
    case unknownEffect(EffectType)
    case missingEffect(UUID)
    case unsupportedParameter(EffectParameterKind)
    case emptyTextParameter(EffectTextParameterKind)
}

public struct EffectGraphEditor: Sendable {
    public let registry: EffectRegistry
    public let validator: EffectGraphValidator

    public init(registry: EffectRegistry = .standard) {
        self.registry = registry
        self.validator = EffectGraphValidator(registry: registry)
    }

    public func adding(_ type: EffectType, to input: EffectGraph) throws -> NormalizedGraph {
        guard let definition = registry[type] else { throw EffectGraphEditError.unknownEffect(type) }
        guard !input.timeline.isEmpty else { throw EffectGraphEditError.missingTimeline }
        var graph = input
        for index in graph.timeline.indices where !graph.timeline[index].effects.contains(where: { $0.type == type }) {
            graph.timeline[index].effects.append(EffectNode(type: type, parameters: definition.defaultParameters))
        }
        graph.differenceSummary = summary(for: graph)
        return try validator.validate(graph)
    }

    public func removing(_ type: EffectType, from input: EffectGraph) throws -> NormalizedGraph {
        var graph = input
        for index in graph.timeline.indices {
            graph.timeline[index].effects.removeAll { $0.type == type }
        }
        graph.differenceSummary = summary(for: graph)
        return try validator.validate(graph)
    }

    public func updating(
        effectID: UUID,
        parameter: EffectParameterKind,
        value: Double,
        in input: EffectGraph
    ) throws -> NormalizedGraph {
        var graph = input
        var found = false
        for segmentIndex in graph.timeline.indices {
            guard let effectIndex = graph.timeline[segmentIndex].effects.firstIndex(where: { $0.id == effectID }) else { continue }
            found = true
            switch parameter {
            case .strength: graph.timeline[segmentIndex].effects[effectIndex].parameters.strength = value
            case .intensity: graph.timeline[segmentIndex].effects[effectIndex].parameters.intensity = value
            case .rate: graph.timeline[segmentIndex].effects[effectIndex].parameters.rate = value
            case .duration: graph.timeline[segmentIndex].effects[effectIndex].parameters.duration = value
            }
            break
        }
        guard found else { throw EffectGraphEditError.missingEffect(effectID) }
        return try validator.validate(graph)
    }

    public func updating(
        type: EffectType,
        parameter: EffectParameterKind,
        value: Double,
        in input: EffectGraph
    ) throws -> NormalizedGraph {
        var graph = input
        var found = false
        for segmentIndex in graph.timeline.indices {
            for effectIndex in graph.timeline[segmentIndex].effects.indices
            where graph.timeline[segmentIndex].effects[effectIndex].type == type {
                found = true
                switch parameter {
                case .strength: graph.timeline[segmentIndex].effects[effectIndex].parameters.strength = value
                case .intensity: graph.timeline[segmentIndex].effects[effectIndex].parameters.intensity = value
                case .rate: graph.timeline[segmentIndex].effects[effectIndex].parameters.rate = value
                case .duration: graph.timeline[segmentIndex].effects[effectIndex].parameters.duration = value
                }
            }
        }
        guard found else { throw EffectGraphEditError.unknownEffect(type) }
        return try validator.validate(graph)
    }

    public func updating(
        type: EffectType,
        parameter: EffectTextParameterKind,
        value: String,
        in input: EffectGraph
    ) throws -> NormalizedGraph {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw EffectGraphEditError.emptyTextParameter(parameter) }
        var graph = input
        var found = false
        for segmentIndex in graph.timeline.indices {
            for effectIndex in graph.timeline[segmentIndex].effects.indices
            where graph.timeline[segmentIndex].effects[effectIndex].type == type {
                found = true
                switch parameter {
                case .target: graph.timeline[segmentIndex].effects[effectIndex].parameters.target = trimmed
                case .preset: graph.timeline[segmentIndex].effects[effectIndex].parameters.preset = trimmed
                case .text: graph.timeline[segmentIndex].effects[effectIndex].parameters.text = trimmed
                }
            }
        }
        guard found else { throw EffectGraphEditError.unknownEffect(type) }
        return try validator.validate(graph)
    }

    private func summary(for graph: EffectGraph) -> String {
        let names = graph.timeline.flatMap(\.effects).map { registry[$0.type]?.displayName ?? $0.type.rawValue }
        return names.isEmpty ? "Original treatment with no added effects" : names.joined(separator: ", ")
    }
}
