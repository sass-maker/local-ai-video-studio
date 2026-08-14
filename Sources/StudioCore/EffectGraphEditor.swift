import CryptoKit
import Foundation

public enum EffectGraphEditError: Error, Equatable, Sendable {
  case missingTimeline
  case unknownEffect(EffectType)
  case missingEffect(UUID)
  case missingSegment(UUID)
  case splitOutsideSegment
  case cannotRemoveFinalSegment
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
    for index in graph.timeline.indices
    where !graph.timeline[index].effects.contains(where: { $0.type == type }) {
      graph.timeline[index].effects.append(
        EffectNode(type: type, parameters: definition.defaultParameters))
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

  public func splitting(segmentID: UUID, at time: Double, in input: EffectGraph) throws
    -> NormalizedGraph
  {
    guard let index = input.timeline.firstIndex(where: { $0.id == segmentID }) else {
      throw EffectGraphEditError.missingSegment(segmentID)
    }
    let segment = input.timeline[index]
    guard time.isFinite, time > segment.start, time < segment.end else {
      throw EffectGraphEditError.splitOutsideSegment
    }

    var graph = input
    graph.timeline[index].end = time
    graph.timeline.insert(
      TimelineSegment(
        id: splitID(graphID: graph.id, segmentID: segmentID, at: time),
        start: time,
        end: segment.end,
        effects: segment.effects
      ),
      at: index + 1
    )
    return try validator.validate(graph)
  }

  public func updatingSegment(
    segmentID: UUID,
    start: Double,
    end: Double,
    in input: EffectGraph
  ) throws -> NormalizedGraph {
    guard let index = input.timeline.firstIndex(where: { $0.id == segmentID }) else {
      throw EffectGraphEditError.missingSegment(segmentID)
    }
    var graph = input
    graph.timeline[index].start = start
    graph.timeline[index].end = end
    return try validator.validate(graph)
  }

  public func removingSegment(segmentID: UUID, from input: EffectGraph) throws -> NormalizedGraph {
    guard input.timeline.contains(where: { $0.id == segmentID }) else {
      throw EffectGraphEditError.missingSegment(segmentID)
    }
    guard input.timeline.count > 1 else {
      throw EffectGraphEditError.cannotRemoveFinalSegment
    }
    var graph = input
    graph.timeline.removeAll { $0.id == segmentID }
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
      guard
        let effectIndex = graph.timeline[segmentIndex].effects.firstIndex(where: {
          $0.id == effectID
        })
      else { continue }
      found = true
      apply(
        parameter, value: value, to: &graph.timeline[segmentIndex].effects[effectIndex].parameters)
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
        apply(
          parameter, value: value, to: &graph.timeline[segmentIndex].effects[effectIndex].parameters
        )
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

  private func apply(
    _ parameter: EffectParameterKind, value: Double, to parameters: inout EffectParameters
  ) {
    switch parameter {
    case .strength: parameters.strength = value
    case .intensity: parameters.intensity = value
    case .rate: parameters.rate = value
    case .duration: parameters.duration = value
    }
  }

  private func summary(for graph: EffectGraph) -> String {
    let names = graph.timeline.flatMap(\.effects).map {
      registry[$0.type]?.displayName ?? $0.type.rawValue
    }
    return names.isEmpty
      ? "Original treatment with no added effects" : names.joined(separator: ", ")
  }

  private func splitID(graphID: UUID, segmentID: UUID, at time: Double) -> UUID {
    let seed = "\(graphID.uuidString)|\(segmentID.uuidString)|\(String(time.bitPattern, radix: 16))"
    let digest = Array(SHA256.hash(data: Data(seed.utf8)).prefix(16))
    var bytes = digest
    bytes[6] = (bytes[6] & 0x0f) | 0x50
    bytes[8] = (bytes[8] & 0x3f) | 0x80
    return UUID(
      uuid: (
        bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7],
        bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]
      ))
  }
}
