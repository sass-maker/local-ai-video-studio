import Foundation
import StudioCore
import Testing

private let semanticRequest = PlanningRequest(
    instruction: "Create two vertical edits",
    variantCount: 2,
    output: OutputProfile(aspectRatio: .landscape, width: 1920, height: 1080, fps: 24),
    duration: 30
)

private let semanticProvenance = PlannerProvenance(kind: .localModel, name: "test-teacher", version: "1")

@Test func semanticPlanDecodesAndCompilesDeterministically() throws {
    let json = """
    {"record_id":"case-1","decision":"plan","reason":"Two treatments","variants":[{"label":"Soft anime","output":"vertical","effects":[{"type":"style.anime","strength":0.5},{"type":"crop.auto_subject"}]},{"label":"Comic","output":"vertical","effects":[{"type":"style.comic","strength":0.7}]}]}
    """
    let plan = try JSONDecoder().decode(SemanticPlan.self, from: Data(json.utf8))
    let compiler = SemanticPlanCompiler()
    let first = try compiler.compile(plan, request: semanticRequest, provenance: semanticProvenance)
    let second = try compiler.compile(plan, request: semanticRequest, provenance: semanticProvenance)

    #expect(first.graphs.count == 2)
    #expect(first.graphs.map(\.id) == second.graphs.map(\.id))
    #expect(first.graphs[0].output.aspectRatio == .vertical)
    #expect(first.graphs[0].output.fps == 24)
    #expect(first.graphs[0].provenance == semanticProvenance)
}

@Test func semanticPlanRejectsUnsupportedParameterForEffect() throws {
    let plan = SemanticPlan(
        recordID: "bad-parameter",
        decision: .plan,
        reason: "Invalid blur parameter",
        variants: [
            SemanticVariant(label: "A", output: .vertical, effects: [.init(type: .backgroundBlur, intensity: 0.5)]),
            SemanticVariant(label: "B", output: .vertical, effects: [.init(type: .backgroundBlur, intensity: 0.7)]),
        ]
    )

    #expect(throws: SemanticPlanCompilationError.self) {
        try SemanticPlanCompiler().compile(plan, request: semanticRequest, provenance: semanticProvenance)
    }
}

@Test func semanticPlanPreservesClarificationWithoutGraphs() throws {
    let plan = SemanticPlan(recordID: "clarify", decision: .clarify, reason: "Choose an aspect ratio", variants: [])
    let result = try SemanticPlanCompiler().compile(plan, request: semanticRequest, provenance: semanticProvenance)
    #expect(result.decision == .clarify)
    #expect(result.graphs.isEmpty)
}

@Test func semanticPlanStrictDecoderRejectsBoilerplate() {
    let json = """
    {"record_id":"case-1","decision":"plan","reason":"test","variants":[],"schema_version":1}
    """
    #expect(throws: StrictDecodingError.self) {
        try JSONDecoder().decode(SemanticPlan.self, from: Data(json.utf8))
    }
}

@Test func finalDevinSemanticPilotCompilesEveryPlannedVariant() throws {
    let testFile = URL(fileURLWithPath: #filePath)
    let projectRoot = testFile
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    let corpusURLs = [
        "Datasets/PlannerDiscovery/v0/pilot-001-semantic-final.jsonl",
        "Datasets/PlannerDiscovery/v0/pilot-001-semantic-repair-001-002.jsonl",
    ].map(projectRoot.appendingPathComponent)
    var plansByID: [String: SemanticPlan] = [:]
    for url in corpusURLs {
        for line in try String(contentsOf: url, encoding: .utf8).split(whereSeparator: \.isNewline) {
            let plan = try JSONDecoder().decode(SemanticPlan.self, from: Data(line.utf8))
            plansByID[plan.recordID] = plan
        }
    }
    let plans = plansByID.values.sorted { $0.recordID < $1.recordID }
    #expect(plans.count == 20)

    let expectedCounts = [3, 2, 4, 3, 2, 3, 2, 5, 2, 3]
    let requiredEffects: [Set<EffectType>] = [
        [.cropAutoSubject, .styleCel, .styleComic, .backgroundReplace, .captionDynamic, .beatFlash],
        [.styleCinematic, .audioNormalize, .colorGrade, .titleCard],
        [.captionDynamic, .cropAutoSubject, .trim, .speed],
        [.styleNoir, .beatZoom],
        [.styleWatercolor, .transitionCrossfade, .cropAutoSubject],
        [.styleVHS, .speed, .titleCard, .audioNormalize],
        [.backgroundBlur, .cropAutoSubject, .captionDynamic],
        [.styleSketch],
        [.trim, .speed, .transitionCrossfade, .titleCard],
        [.cropAutoSubject, .styleAnime, .styleCel, .outline, .glow],
    ]
    let forbiddenEffects: [Set<EffectType>] = [
        [], [.styleAnime, .styleComic], [], [.audioNormalize], [],
        [.captionDynamic], [.styleAnime, .styleComic, .styleSketch, .styleWatercolor, .styleCel, .styleCinematic, .styleNoir, .styleVHS],
        [], [], [],
    ]
    var graphCount = 0
    var decisions: [SemanticPlanDecision: Int] = [:]
    for (index, plan) in plans.enumerated() {
        let requestedCount = index < expectedCounts.count ? expectedCounts[index] : 2
        let request = PlanningRequest(
            instruction: "pilot",
            variantCount: requestedCount,
            output: OutputProfile(aspectRatio: .landscape, width: 1920, height: 1080, fps: 24),
            duration: 30
        )
        let result = try SemanticPlanCompiler().compile(plan, request: request, provenance: semanticProvenance)
        decisions[result.decision, default: 0] += 1
        graphCount += result.graphs.count
        if index < requiredEffects.count {
            let emitted = Set(plan.variants.flatMap(\.effects).map(\.type))
            #expect(requiredEffects[index].isSubset(of: emitted))
            #expect(forbiddenEffects[index].isDisjoint(with: emitted))
        }
    }

    #expect(graphCount == 29)
    #expect(decisions[.plan] == 10)
    #expect(decisions[.clarify] == 7)
    #expect(decisions[.unsupported] == 3)
}
