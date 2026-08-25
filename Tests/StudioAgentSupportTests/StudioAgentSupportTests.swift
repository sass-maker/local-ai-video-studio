import Foundation
import StudioAgentSupport
import StudioCore
import Testing

@Test func manifestCoversEveryOperationAndEffect() async throws {
  let result = try await StudioAgentService().run(request("manifest"))
  let payload = try #require(result["result"] as? [String: Any])
  let operations = try #require(payload["operations"] as? [[String: Any]])

  #expect(Set(operations.compactMap { $0["id"] as? String }) == Set(StudioAgentService.operations))
  #expect(payload["effectCount"] as? Int == 23)
  #expect(
    payload["editActions"] as? [String] == [
      "add", "remove", "split-segment", "trim-segment", "remove-segment",
    ])
}

@Test func agentTimelineEditMatchesTheNativeValidatedGraph() async throws {
  let graph = agentGraph()
  let segmentID = graph.timeline[0].id
  let graphObject = try #require(
    JSONSerialization.jsonObject(with: JSONEncoder().encode(graph)) as? [String: Any])
  let result = try await StudioAgentService().run(
    request(
      "edit",
      input: [
        "graph": graphObject,
        "action": "split-segment",
        "segmentId": segmentID.uuidString,
        "at": 2.0,
      ]))
  let payload = try #require(result["result"] as? [String: Any])
  let native = try EffectGraphEditor().splitting(segmentID: segmentID, at: 2, in: graph)

  #expect(payload["graphHash"] as? String == native.canonicalHash)
  let editedObject = try #require(payload["graph"] as? [String: Any])
  let edited = try JSONDecoder().decode(
    EffectGraph.self, from: JSONSerialization.data(withJSONObject: editedObject))
  #expect(edited == native.graph)
}

@Test func agentTimelineEditRejectsActionIncompatibleFields() async throws {
  let graph = agentGraph()
  let graphObject = try #require(
    JSONSerialization.jsonObject(with: JSONEncoder().encode(graph)) as? [String: Any])
  await #expect(throws: StudioAgentError.self) {
    try await StudioAgentService().run(
      request(
        "edit",
        input: [
          "graph": graphObject,
          "action": "remove-segment",
          "segmentId": graph.timeline[0].id.uuidString,
          "effect": "style.anime",
        ]))
  }
}

@Test func arbitraryExecutionAndUnknownFieldsFailClosed() async throws {
  let service = StudioAgentService()
  await #expect(throws: StudioAgentError.self) {
    try await service.run(request("manifest", input: ["command": "echo unsafe"]))
  }
  await #expect(throws: StudioAgentError.self) {
    try await service.run(request("manifest", extra: ["surprise": true]))
  }
}

@Test func malformedInputsFailInsteadOfSilentlyUsingDefaults() async throws {
  let service = StudioAgentService()
  await #expect(throws: StudioAgentError.self) {
    try await service.run([
      "schema": studioAgentSchema,
      "product": "studio",
      "operation": "manifest",
      "input": ["not", "an", "object"],
    ])
  }
  await #expect(throws: StudioAgentError.self) {
    try await service.run(
      request(
        "plan",
        input: [
          "instruction": "Create two variants",
          "variantCount": "three",
          "durationSeconds": 12.0,
        ]))
  }
}

@Test func failureEnvelopeRetainsTheCompleteProtocolShape() {
  let service = StudioAgentService()
  let result = service.failure(
    request("missing", extra: ["idempotencyKey": "retry-1"]),
    error: StudioAgentError("UNKNOWN_OPERATION", "missing"))

  #expect(result.keys.contains("idempotencyKey"))
  #expect(result.keys.contains("requestHash"))
  #expect(result["idempotencyKey"] as? String == "retry-1")
}

@Test func promptPlanningReturnsValidatedHashes() async throws {
  let service = StudioAgentService(planner: .init(model: StubLocalModel()))
  let result = try await service.run(
    request(
      "plan",
      input: [
        "instruction": "Create three vertical variants: anime, comic, and clean captions",
        "variantCount": 3,
        "durationSeconds": 12.0,
      ]))
  let payload = try #require(result["result"] as? [String: Any])
  let variants = try #require(payload["variants"] as? [[String: Any]])

  #expect(variants.count == 3)
  #expect(variants.allSatisfy { ($0["graphHash"] as? String)?.count == 64 })
  #expect(payload["planner"] as? String == "stub-local-model")
  #expect(payload["plannerKind"] as? String == "local_model")
  #expect(payload["fallbackReason"] is NSNull)
}

@Test func promptPlanningDisclosesTheDeterministicFallbackReason() async throws {
  let service = StudioAgentService(planner: .init(model: StubLocalModel(unsupported: true)))
  let result = try await service.run(
    request(
      "plan",
      input: [
        "instruction": "Do something unsupported", "variantCount": 2, "durationSeconds": 8.0,
      ]))
  let payload = try #require(result["result"] as? [String: Any])
  let reason = try #require(payload["fallbackReason"] as? String)

  #expect(payload["plannerKind"] as? String == "deterministic_demo")
  #expect(reason.contains("style.hologram"))
  #expect((payload["variants"] as? [[String: Any]])?.count == 2)
}

/// Keeps agent planning coverage deterministic and independent of whether
/// Apple Intelligence is enabled on the host.
private struct StubLocalModel: GeneratedPlanProducing {
  let modelIdentifier = "stub-local-model"
  var unsupported = false

  func generatePlan(_ request: PlanningRequest) async throws -> GeneratedPlanDraft {
    let types: [String] =
      unsupported
      ? ["style.hologram"] : [EffectType.styleCel.rawValue, EffectType.captionDynamic.rawValue]
    return GeneratedPlanDraft(
      variants: (0..<request.variantCount).map { index in
        GeneratedVariantDraft(
          label: "Study \(index + 1)",
          summary: "Stubbed variant \(index + 1) for the agent contract.",
          effects: types.map { GeneratedEffectDraft(type: $0, strength: 0.5, preset: "bold") })
      })
  }
}

private func request(_ operation: String, input: [String: Any] = [:], extra: [String: Any] = [:])
  -> [String: Any]
{
  var value: [String: Any] = [
    "schema": studioAgentSchema,
    "product": "studio",
    "operation": operation,
    "operationId": "op-test",
    "input": input,
  ]
  value.merge(extra) { _, new in new }
  return value
}

private func agentGraph() -> EffectGraph {
  EffectGraph(
    id: UUID(uuidString: "10000000-0000-4000-8000-000000000001")!,
    label: "Agent study",
    differenceSummary: "Structured agent test",
    provenance: .init(kind: .deterministicDemo, name: "test", version: "1"),
    output: .init(aspectRatio: .vertical, width: 1080, height: 1920, fps: 24),
    timeline: [
      TimelineSegment(
        id: UUID(uuidString: "10000000-0000-4000-8000-000000000002")!,
        start: 0,
        end: 4,
        effects: [
          EffectNode(
            id: UUID(uuidString: "10000000-0000-4000-8000-000000000003")!,
            type: .styleCel,
            parameters: .init(strength: 0.7)
          )
        ]
      )
    ]
  )
}
