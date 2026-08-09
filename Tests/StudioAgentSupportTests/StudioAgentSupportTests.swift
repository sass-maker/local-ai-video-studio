import StudioAgentSupport
import Testing

@Test func manifestCoversEveryOperationAndEffect() async throws {
    let result = try await StudioAgentService().run(request("manifest"))
    let payload = try #require(result["result"] as? [String: Any])
    let operations = try #require(payload["operations"] as? [[String: Any]])

    #expect(Set(operations.compactMap { $0["id"] as? String }) == Set(StudioAgentService.operations))
    #expect(payload["effectCount"] as? Int == 23)
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

@Test func promptPlanningReturnsValidatedHashes() async throws {
    let result = try await StudioAgentService().run(request("plan", input: [
        "instruction": "Create three vertical variants: anime, comic, and clean captions",
        "variantCount": 3,
        "durationSeconds": 12.0,
    ]))
    let payload = try #require(result["result"] as? [String: Any])
    let variants = try #require(payload["variants"] as? [[String: Any]])

    #expect(variants.count == 3)
    #expect(variants.allSatisfy { ($0["graphHash"] as? String)?.count == 64 })
}

private func request(_ operation: String, input: [String: Any] = [:], extra: [String: Any] = [:]) -> [String: Any] {
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
