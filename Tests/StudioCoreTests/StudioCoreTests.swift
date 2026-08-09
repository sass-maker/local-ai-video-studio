import Foundation
import Testing
@testable import StudioCore

@Test func schemaVersionsStartAtOne() {
    #expect(StudioCore.projectSchemaVersion == 1)
    #expect(StudioCore.effectGraphSchemaVersion == 1)
}

private let output = OutputProfile(aspectRatio: .vertical, width: 1080, height: 1920, fps: 24)
private let provenance = PlannerProvenance(kind: .deterministicDemo, name: "test", version: "1")

private func graph(effects: [EffectNode] = [EffectNode(type: .styleCel, parameters: .init(strength: 0.7))]) -> EffectGraph {
    EffectGraph(
        id: UUID(uuidString: "00000000-0000-4000-8000-000000000001")!,
        label: "Cel Study",
        differenceSummary: "A cel approximation.",
        provenance: provenance,
        output: output,
        timeline: [TimelineSegment(id: UUID(uuidString: "00000000-0000-4000-8000-000000000002")!, start: 0, end: 4.5, effects: effects)]
    )
}

@Test func strictDecoderRejectsUnknownRootFields() throws {
    let encoded = try JSONEncoder().encode(graph())
    var object = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
    object["shell_command"] = "rm something"
    let modified = try JSONSerialization.data(withJSONObject: object)

    #expect(throws: StrictDecodingError.self) {
        try JSONDecoder().decode(EffectGraph.self, from: modified)
    }
}

@Test func fixtureGraphDecodesAndValidates() throws {
    let url = try #require(Bundle.module.url(forResource: "milestone-graph", withExtension: "json"))
    let decoded = try JSONDecoder().decode(EffectGraph.self, from: Data(contentsOf: url))
    let normalized = try EffectGraphValidator().validate(decoded)

    #expect(normalized.graph.label == "Cel Study")
    #expect(normalized.graph.timeline[0].effects[0].type == .styleCel)
}

@Test func devinDiscoveryRetryDecodesAsApplicationGraphs() throws {
    let testFile = URL(fileURLWithPath: #filePath)
    let projectRoot = testFile
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    let corpusURLs = [
        "Datasets/PlannerDiscovery/v0/pilot-001-raw-01-v2.jsonl",
        "Datasets/PlannerDiscovery/v0/pilot-001-raw-remaining-v2.jsonl",
        "Datasets/PlannerDiscovery/v0/pilot-001-repair-006-v4.jsonl",
        "Datasets/PlannerDiscovery/v0/pilot-001-repair-009-v5.jsonl",
        "Datasets/PlannerDiscovery/v0/pilot-001-normalized-010.jsonl",
    ].map(projectRoot.appendingPathComponent)
    let rawLines = try corpusURLs.flatMap { url in
        try String(contentsOf: url, encoding: .utf8).split(whereSeparator: \.isNewline)
    }
    var latestRecords: [String: [String: Any]] = [:]
    for line in rawLines {
        let recordData = Data(line.utf8)
        let record = try #require(JSONSerialization.jsonObject(with: recordData) as? [String: Any])
        let recordID = try #require(record["record_id"] as? String)
        latestRecords[recordID] = record
    }
    #expect(latestRecords.count == 20)

    var graphCount = 0
    for record in latestRecords.values {
        #expect(record["capability_tags"] is [String])
        let constraints = try #require(record["constraints"] as? [String: Any])
        #expect(constraints["capability_tags"] == nil)
        let graphs = try #require(record["candidate_graphs"] as? [[String: Any]])
        graphCount += graphs.count

        for graphObject in graphs {
            let graphData = try JSONSerialization.data(withJSONObject: graphObject)
            let graph = try JSONDecoder().decode(EffectGraph.self, from: graphData)
            _ = try EffectGraphValidator().validate(graph)
        }
    }

    #expect(graphCount == 29)
}

@Test func validatorNormalizesTimelineAndProducesStableHash() throws {
    var input = graph()
    input.timeline = [
        TimelineSegment(id: UUID(uuidString: "00000000-0000-4000-8000-000000000004")!, start: 4, end: 5, effects: []),
        TimelineSegment(id: UUID(uuidString: "00000000-0000-4000-8000-000000000003")!, start: 0, end: 4, effects: []),
    ]
    let validator = EffectGraphValidator()
    let first = try validator.validate(input)
    let second = try validator.validate(input)

    #expect(first.graph.timeline.map(\.start) == [0, 4])
    #expect(first.canonicalHash == second.canonicalHash)
    #expect(first.canonicalHash.count == 64)
}

@Test func effectCatalogCoversEveryRegisteredEffectTruthfully() {
    let catalog = EffectRegistry.standard.allDefinitions
    #expect(catalog.count == EffectType.allCases.count)
    #expect(Set(catalog.map(\.type)) == Set(EffectType.allCases))
    #expect(catalog.allSatisfy { !$0.displayName.isEmpty })
    #expect(catalog.filter { $0.readiness == .fallback }.allSatisfy { $0.fallbackReason?.isEmpty == false })
    #expect(EffectRegistry.standard[.styleAnime]?.readiness == .approximation)
    #expect(EffectRegistry.standard[.backgroundReplace]?.readiness == .fallback)
}

@Test func directEffectEditingUsesTheValidatedCanonicalGraph() throws {
    let editor = EffectGraphEditor()
    let original = try EffectGraphValidator().validate(graph())
    let added = try editor.adding(.beatFlash, to: original.graph)
    let flash = try #require(added.graph.timeline.flatMap(\.effects).first(where: { $0.type == .beatFlash }))
    #expect(added.canonicalHash != original.canonicalHash)
    #expect(flash.parameters.intensity == 0.5)

    let tuned = try editor.updating(type: .beatFlash, parameter: .intensity, value: 0.8, in: added.graph)
    #expect(tuned.graph.timeline.flatMap(\.effects).first(where: { $0.id == flash.id })?.parameters.intensity == 0.8)
    #expect(tuned.canonicalHash != added.canonicalHash)

    let removed = try editor.removing(.beatFlash, from: tuned.graph)
    #expect(!removed.graph.timeline.flatMap(\.effects).contains(where: { $0.type == .beatFlash }))
    #expect(removed.graph.timeline.flatMap(\.effects).contains(where: { $0.type == .styleCel }))
}

@Test func directEditingRejectsOutOfRangeParameters() throws {
    let editor = EffectGraphEditor()
    let added = try editor.adding(.speed, to: graph())
    let speed = try #require(added.graph.timeline.flatMap(\.effects).first(where: { $0.type == .speed }))
    #expect(throws: GraphValidationFailure.self) {
        try editor.updating(effectID: speed.id, parameter: .rate, value: 8, in: added.graph)
    }
}

@Test func directEditingExposesTypedTitleAndPresetParameters() throws {
    let editor = EffectGraphEditor()
    let titled = try editor.adding(.titleCard, to: graph())
    let renamed = try editor.updating(type: .titleCard, parameter: .text, value: "Launch Day", in: titled.graph)
    #expect(renamed.graph.timeline.flatMap(\.effects).first(where: { $0.type == .titleCard })?.parameters.text == "Launch Day")

    let captioned = try editor.adding(.captionDynamic, to: renamed.graph)
    let tuned = try editor.updating(type: .captionDynamic, parameter: .preset, value: "karaoke", in: captioned.graph)
    #expect(tuned.graph.timeline.flatMap(\.effects).first(where: { $0.type == .captionDynamic })?.parameters.preset == "karaoke")
}

@Test func validatorRejectsInvalidStrength() {
    let input = graph(effects: [EffectNode(type: .styleAnime, parameters: .init(strength: 1.4))])
    #expect(throws: GraphValidationFailure.self) {
        try EffectGraphValidator().validate(input)
    }
}

@Test func validatorResolvesRegisteredBackgroundConflict() throws {
    let input = graph(effects: [
        EffectNode(type: .backgroundBlur, parameters: .init(strength: 0.5)),
        EffectNode(type: .backgroundReplace, parameters: .init(preset: "studio")),
    ])
    let result = try EffectGraphValidator().validate(input)

    #expect(result.graph.timeline[0].effects.map(\.type) == [.backgroundReplace])
    #expect(result.warnings.contains { $0.message.contains("takes precedence") })
}

@Test func estimatorLowersHeavyPreviewProfile() throws {
    let result = try EffectGraphValidator().validate(graph())
    let estimate = RenderEstimator().estimate(result.graph)

    #expect(estimate.responsibleEffects == [.styleCel])
    #expect(estimate.recommendedPreviewLongEdge == 960)
    #expect(estimate.estimatedBytes > 0)
}

@Test func milestonePlannerCreatesMeaningfulValidatedVariants() async throws {
    let request = PlanningRequest(
        instruction: "Create three vertical reels: anime, comic, and original with background, captions, and beat flashes.",
        variantCount: 3,
        output: output,
        duration: 38
    )
    let variants = try await DeterministicDemoPlanner().plan(request)
    let validator = EffectGraphValidator()

    #expect(variants.count == 3)
    #expect(Set(variants.map(\.label)).count == 3)
    #expect(variants.allSatisfy { $0.output.aspectRatio == .vertical })
    for variant in variants {
        _ = try validator.validate(variant)
    }
    #expect(variants[2].timeline[0].effects.map(\.type).contains(.backgroundReplace))
    #expect(variants[2].timeline[0].effects.map(\.type).contains(.captionDynamic))
    #expect(variants[2].timeline[0].effects.map(\.type).contains(.beatFlash))
}

@Test func plannerEnforcesTwoToFiveVariants() async {
    let request = PlanningRequest(instruction: "one", variantCount: 1, output: output, duration: 5)
    await #expect(throws: PlanningError.variantCountOutOfRange) {
        try await DeterministicDemoPlanner().plan(request)
    }
}

@Test func generatedPlanMapsPromptSpecificEffectsAndModelProvenance() throws {
    let request = PlanningRequest(instruction: "watercolor, slow motion, and glow", variantCount: 2, output: output, duration: 12)
    let draft = GeneratedPlanDraft(variants: [
        .init(label: "Water Glow", summary: "Soft painted treatment", effects: [
            .init(type: EffectType.styleWatercolor.rawValue, strength: 0.8),
            .init(type: EffectType.glow.rawValue, strength: 0.35),
        ]),
        .init(label: "Slow Wash", summary: "Slower alternate", effects: [
            .init(type: EffectType.speed.rawValue, rate: 0.6),
            .init(type: EffectType.colorGrade.rawValue, intensity: 0.4),
        ]),
    ])

    let graphs = try GeneratedPlanMapper().map(draft, for: request)

    #expect(graphs.count == 2)
    #expect(graphs.allSatisfy { $0.provenance.kind == .localModel })
    #expect(graphs[0].timeline[0].effects.map(\.type) == [.styleWatercolor, .glow])
    #expect(graphs[1].timeline[0].effects.map(\.type) == [.speed, .colorGrade])
    #expect(graphs[1].timeline[0].effects[0].parameters.rate == 0.6)
}

@Test func generatedPlanRejectsUnknownEffectsBeforeValidation() {
    let request = PlanningRequest(instruction: "explode it", variantCount: 2, output: output, duration: 5)
    let bad = GeneratedPlanDraft(variants: [
        .init(label: "A", summary: "A", effects: [.init(type: "shell.execute")]),
        .init(label: "B", summary: "B", effects: [.init(type: EffectType.styleNoir.rawValue)]),
    ])

    #expect(throws: GeneratedPlanMappingError.unsupportedEffect("shell.execute")) {
        try GeneratedPlanMapper().map(bad, for: request)
    }
}

@Test func generatedPlanParametersStillPassThroughExistingBoundsValidator() throws {
    let request = PlanningRequest(instruction: "too strong", variantCount: 2, output: output, duration: 5)
    let draft = GeneratedPlanDraft(variants: [
        .init(label: "A", summary: "A", effects: [.init(type: EffectType.styleComic.rawValue, strength: 2)]),
        .init(label: "B", summary: "B", effects: [.init(type: EffectType.styleNoir.rawValue)]),
    ])
    let graphs = try GeneratedPlanMapper().map(draft, for: request)

    #expect(throws: GraphValidationFailure.self) {
        try EffectGraphValidator().validate(graphs[0])
    }
}

@Test func preferredPlannerFallsBackWhenPrimaryGenerationFails() async throws {
    struct ExpectedFailure: Error {}
    let planner = PreferredVariantPlanner(primaryOverride: { _ in throw ExpectedFailure() })
    let request = PlanningRequest(instruction: "watercolor", variantCount: 2, output: output, duration: 5)

    let graphs = try await planner.plan(request)

    #expect(graphs.count == 2)
    #expect(graphs.allSatisfy { $0.provenance.kind == .deterministicDemo })
}

@Test func projectRoundTripsAndPreservesComparison() async throws {
    let temporary = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: temporary, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: temporary) }
    let sourceURL = temporary.appending(path: "source.mov")
    try Data("fixture-media".utf8).write(to: sourceURL)
    let source = SourceReference(
        displayName: "source.mov",
        relativePath: "source.mov",
        originalPath: sourceURL.path,
        bookmark: nil,
        fingerprint: try SourceFingerprint.make(for: sourceURL),
        fileSize: 13,
        metadata: MediaMetadata(duration: 5, width: 1920, height: 1080, fps: 24, hasAudio: true, codec: "avc1")
    )
    let normalized = try EffectGraphValidator().validate(graph())
    let revision = VariantRevision(revision: 1, graph: normalized.graph, normalizedGraphHash: normalized.canonicalHash)
    let project = StudioProject(
        name: "Test Project",
        instruction: "Make three variants",
        source: source,
        variants: [revision],
        comparison: VariantComparison(ratings: [normalized.graph.id: 4], selectedVariantID: normalized.graph.id, isBlinded: true, sharedPlayhead: 2.4)
    )
    let projectURL = temporary.appending(path: "project.lvstudio")
    let store = ProjectStore()

    try await store.save(project, to: projectURL)
    let restored = try await store.load(from: projectURL)

    #expect(restored.id == project.id)
    #expect(restored.variants == project.variants)
    #expect(restored.comparison.selectedVariantID == normalized.graph.id)
    #expect(SourceLocator.resolve(restored.source, relativeTo: projectURL) == sourceURL)
}

@Test func fingerprintRejectsDifferentRelinkedSource() throws {
    let temporary = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: temporary, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: temporary) }
    let original = temporary.appending(path: "original.mov")
    let replacement = temporary.appending(path: "replacement.mov")
    try Data("original".utf8).write(to: original)
    try Data("replacement".utf8).write(to: replacement)
    let fingerprint = try SourceFingerprint.make(for: original)

    #expect(throws: ProjectPersistenceError.sourceFingerprintMismatch) {
        try SourceFingerprint.verify(replacement, expected: fingerprint)
    }
}

@Test func projectStoreRejectsUnsupportedSchema() async throws {
    let temporary = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: temporary, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: temporary) }
    let source = SourceReference(
        displayName: "missing.mov",
        relativePath: nil,
        originalPath: "/missing.mov",
        bookmark: nil,
        fingerprint: "none",
        fileSize: 0,
        metadata: MediaMetadata(duration: 1, width: 1, height: 1, fps: 1, hasAudio: false, codec: "none")
    )
    let project = StudioProject(schemaVersion: 99, name: "Future", instruction: "", source: source)
    let url = temporary.appending(path: "future.lvstudio")
    let store = ProjectStore()
    try await store.save(project, to: url)

    await #expect(throws: ProjectPersistenceError.unsupportedSchema(99)) {
        try await store.load(from: url)
    }
}
