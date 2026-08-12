import CryptoKit
import Foundation
import MediaEngine
import StudioCore

public let studioAgentSchema = "fleet.video-agent-operation.v1"

public struct StudioAgentError: Error, CustomStringConvertible, Sendable {
    public let code: String
    public let message: String
    public let path: String?

    public init(_ code: String, _ message: String, path: String? = nil) {
        self.code = code
        self.message = message
        self.path = path
    }

    public var description: String { message }
}

public struct StudioAgentService: Sendable {
    private static let rootFields: Set<String> = [
        "schema", "product", "operation", "operationId", "idempotencyKey", "validateOnly", "input",
    ]
    private static let forbiddenFields: Set<String> = [
        "command", "shell", "script", "sourceCode", "code", "plugin", "executable",
    ]
    public static let operations = [
        "manifest", "inspect", "analyze", "plan", "catalog", "validate", "edit", "estimate",
        "render", "cancel", "select", "export",
    ]

    private let analyzer = MediaAnalyzer()
    private let planner = PreferredVariantPlanner()
    private let validator = EffectGraphValidator()
    private let editor = EffectGraphEditor()
    private let store = ProjectStore()

    public init() {}

    public func run(_ raw: Any) async throws -> sending [String: Any] {
        let request = try normalize(raw)
        let operation = request.operation
        let startedAt = Self.timestamp()
        let result: Any
        let artifacts: [[String: Any]]

        switch operation {
        case "manifest":
            try exact(request.input, allowed: [], path: "input")
            result = manifest()
            artifacts = []
        case "catalog":
            try exact(request.input, allowed: [], path: "input")
            result = catalog()
            artifacts = []
        case "analyze":
            try exact(request.input, allowed: ["sourcePath"], path: "input")
            let url = try requiredPath(request.input, "sourcePath")
            let metadata = try await analyzer.analyze(url)
            result = try object(metadata)
            artifacts = []
        case "plan":
            try exact(
                request.input,
                allowed: ["instruction", "variantCount", "durationSeconds", "aspectRatio", "width", "height", "fps"],
                path: "input"
            )
            let instruction = try requiredString(request.input, "instruction")
            let count = try optionalInt(request.input, "variantCount", default: 3)
            let duration = try optionalDouble(request.input, "durationSeconds", default: 30)
            let aspectRaw = try optionalString(request.input, "aspectRatio", default: "9:16")
            guard let aspect = AspectRatio(rawValue: aspectRaw) else {
                throw StudioAgentError("INVALID_INPUT", "input.aspectRatio is unsupported", path: "input.aspectRatio")
            }
            let output = OutputProfile(
                aspectRatio: aspect,
                width: try optionalInt(request.input, "width", default: 1080),
                height: try optionalInt(request.input, "height", default: 1920),
                fps: try optionalInt(request.input, "fps", default: 24)
            )
            let graphs = try await planner.plan(.init(instruction: instruction, variantCount: count, output: output, duration: duration))
            let normalized = try graphs.map(validator.validate)
            result = [
                "planner": Self.plannerDescription(graphs),
                "variants": try normalized.map { try normalizedObject($0) },
            ]
            artifacts = []
        case "validate":
            try exact(request.input, allowed: ["graph"], path: "input")
            let normalized = try validator.validate(try graph(from: request.input["graph"]))
            result = try normalizedObject(normalized)
            artifacts = []
        case "estimate":
            try exact(request.input, allowed: ["graph"], path: "input")
            let normalized = try validator.validate(try graph(from: request.input["graph"]))
            let estimate = RenderEstimator().estimate(normalized.graph)
            result = [
                "graphHash": normalized.canonicalHash,
                "workClass": estimate.workClass.rawValue,
                "costUnits": estimate.costUnits,
                "recommendedPreviewLongEdge": estimate.recommendedPreviewLongEdge,
                "estimatedBytes": estimate.estimatedBytes,
                "responsibleEffects": estimate.responsibleEffects.map(\.rawValue),
            ]
            artifacts = []
        case "edit":
            let inputGraph = try graph(from: request.input["graph"])
            let action = try requiredString(request.input, "action")
            let normalized: NormalizedGraph
            do {
                switch action {
                case "add", "remove":
                    try exact(request.input, allowed: ["graph", "action", "effect"], path: "input")
                    let effect = try effectType(request.input["effect"])
                    normalized = action == "add"
                        ? try editor.adding(effect, to: inputGraph)
                        : try editor.removing(effect, from: inputGraph)
                case "split-segment":
                    try exact(request.input, allowed: ["graph", "action", "segmentId", "at"], path: "input")
                    normalized = try editor.splitting(
                        segmentID: requiredUUID(request.input, "segmentId"),
                        at: requiredDouble(request.input, "at"),
                        in: inputGraph
                    )
                case "trim-segment":
                    try exact(request.input, allowed: ["graph", "action", "segmentId", "start", "end"], path: "input")
                    normalized = try editor.updatingSegment(
                        segmentID: requiredUUID(request.input, "segmentId"),
                        start: requiredDouble(request.input, "start"),
                        end: requiredDouble(request.input, "end"),
                        in: inputGraph
                    )
                case "remove-segment":
                    try exact(request.input, allowed: ["graph", "action", "segmentId"], path: "input")
                    normalized = try editor.removingSegment(
                        segmentID: requiredUUID(request.input, "segmentId"),
                        from: inputGraph
                    )
                default:
                    throw StudioAgentError(
                        "INVALID_ACTION",
                        "action must be add, remove, split-segment, trim-segment, or remove-segment",
                        path: "input.action"
                    )
                }
            } catch let error as EffectGraphEditError {
                throw StudioAgentError("INVALID_EDIT", String(describing: error), path: "input")
            }
            result = try normalizedObject(normalized)
            artifacts = []
        case "inspect":
            try exact(request.input, allowed: ["projectPath"], path: "input")
            let project = try await store.load(from: requiredPath(request.input, "projectPath"))
            result = try object(project)
            artifacts = []
        case "select":
            try exact(request.input, allowed: ["projectPath", "variantId"], path: "input")
            let path = try requiredPath(request.input, "projectPath")
            var project = try await store.load(from: path)
            let id = try requiredUUID(request.input, "variantId")
            guard project.variants.contains(where: { $0.graph.id == id }) else {
                throw StudioAgentError("VARIANT_NOT_FOUND", "variant is not present in project", path: "input.variantId")
            }
            project.comparison.selectedVariantID = id
            if !request.validateOnly { try await store.save(project, to: path) }
            result = ["selectedVariantId": id.uuidString, "projectPath": path.path]
            artifacts = request.validateOnly ? [] : [["kind": "project", "path": path.path]]
        case "render":
            try exact(request.input, allowed: ["sourcePath", "outputPath", "graph", "sourceFingerprint", "mode"], path: "input")
            let source = try requiredPath(request.input, "sourcePath")
            let output = try outputPath(request.input, "outputPath")
            let normalized = try validator.validate(try graph(from: request.input["graph"]))
            let fingerprint: String
            if let supplied = request.input["sourceFingerprint"] as? String {
                try SourceFingerprint.verify(source, expected: supplied)
                fingerprint = supplied
            } else {
                fingerprint = try SourceFingerprint.make(for: source)
            }
            if request.validateOnly {
                result = ["ready": true, "graphHash": normalized.canonicalHash, "outputPath": output.path]
                artifacts = []
            } else {
                let renderer = AVFoundationRenderer()
                let mode: RenderRequest.Mode = request.input["mode"] as? String == "final" ? .final : .preview
                let manifest = try await renderer.render(.init(sourceURL: source, outputURL: output, normalizedGraph: normalized, sourceFingerprint: fingerprint, mode: mode))
                result = try object(manifest)
                artifacts = [["kind": "video", "path": output.path]]
            }
        case "cancel":
            try exact(request.input, allowed: [], path: "input")
            throw StudioAgentError("NO_ACTIVE_OPERATION", "studio-agent runs one foreground operation per process; stop the process to cancel")
        case "export":
            try exact(request.input, allowed: ["projectPath", "outputPath"], path: "input")
            let projectPath = try requiredPath(request.input, "projectPath")
            let project = try await store.load(from: projectPath)
            guard let selected = project.comparison.selectedVariantID,
                  let revision = project.variants.first(where: { $0.graph.id == selected }),
                  let render = revision.render,
                  [.completed, .degraded].contains(render.state),
                  render.normalizedGraphHash == revision.normalizedGraphHash,
                  let relative = render.outputRelativePath
            else { throw StudioAgentError("EXPORT_NOT_READY", "selected variant has no current completed render") }
            let source = projectPath.deletingLastPathComponent().appending(path: relative)
            guard FileManager.default.fileExists(atPath: source.path) else {
                throw StudioAgentError("OUTPUT_NOT_FOUND", "rendered output is missing")
            }
            let destination = try outputPath(request.input, "outputPath")
            if !request.validateOnly { try FileManager.default.copyItem(at: source, to: destination) }
            result = ["variantId": selected.uuidString, "outputPath": destination.path]
            artifacts = request.validateOnly ? [] : [["kind": "video", "path": destination.path]]
        default:
            throw StudioAgentError("UNKNOWN_OPERATION", "unknown Studio operation: \(operation)", path: "operation")
        }

        return [
            "schema": studioAgentSchema,
            "product": "studio",
            "operation": operation,
            "operationId": request.operationID,
            "idempotencyKey": request.idempotencyKey ?? NSNull(),
            "state": request.validateOnly ? "validated" : "completed",
            "sideEffect": request.validateOnly ? "plan" : sideEffect(operation),
            "startedAt": startedAt,
            "finishedAt": Self.timestamp(),
            "requestHash": try stableHash(["operation": operation, "input": request.input]),
            "result": result,
            "warnings": [],
            "artifacts": artifacts,
            "error": NSNull(),
        ]
    }

    public func failure(_ raw: Any?, error: Error) -> [String: Any] {
        let agentError = error as? StudioAgentError
        let request = raw as? [String: Any]
        return [
            "schema": studioAgentSchema,
            "product": "studio",
            "operation": request?["operation"] ?? NSNull(),
            "operationId": request?["operationId"] ?? NSNull(),
            "idempotencyKey": request?["idempotencyKey"] ?? NSNull(),
            "state": "failed",
            "sideEffect": "none",
            "startedAt": Self.timestamp(),
            "finishedAt": Self.timestamp(),
            "requestHash": NSNull(),
            "result": NSNull(),
            "warnings": [],
            "artifacts": [],
            "error": [
                "code": agentError?.code ?? "OPERATION_FAILED",
                "message": agentError?.message ?? String(describing: error),
                "path": agentError?.path as Any? ?? NSNull(),
                "retryable": false,
            ],
        ]
    }

    private func manifest() -> [String: Any] {
        [
            "schema": "fleet.video-agent-manifest.v1",
            "product": "studio",
            "transport": ["kind": "cli-json", "foreground": true, "stdout": "single-json-envelope"],
            "operations": Self.operations.map { ["id": $0, "sideEffect": sideEffect($0)] },
            "editActions": ["add", "remove", "split-segment", "trim-segment", "remove-segment"],
            "effectCount": EffectRegistry.standard.allDefinitions.count,
            "safety": ["arbitraryExecution": false, "localByDefault": true, "externalPublication": false],
            "cancellation": ["processSurvival": false, "mechanism": "terminate foreground process"],
        ]
    }

    private func catalog() -> [String: Any] {
        ["effects": EffectRegistry.standard.allDefinitions.map { definition in
            [
                "id": definition.type.rawValue,
                "name": definition.displayName,
                "category": definition.category.rawValue,
                "cost": definition.cost.rawValue,
                "readiness": definition.readiness.rawValue,
                "fallbackReason": definition.fallbackReason ?? NSNull(),
            ] as [String: Any]
        }]
    }

    private func normalize(_ raw: Any) throws -> Request {
        guard let root = raw as? [String: Any] else { throw StudioAgentError("INVALID_REQUEST", "request must be a JSON object") }
        try exact(root, allowed: Self.rootFields, path: "request")
        guard root["schema"] as? String == studioAgentSchema else { throw StudioAgentError("UNSUPPORTED_SCHEMA", "schema must be \(studioAgentSchema)", path: "schema") }
        guard root["product"] as? String == "studio" else { throw StudioAgentError("PRODUCT_MISMATCH", "product must be studio", path: "product") }
        let operation = try requiredString(root, "operation", prefix: "")
        let input: [String: Any]
        if let supplied = root["input"] {
            guard let object = supplied as? [String: Any] else {
                throw StudioAgentError("INVALID_INPUT", "input must be a JSON object", path: "input")
            }
            input = object
        } else {
            input = [:]
        }
        try rejectForbidden(input, path: "input")
        return Request(operation: operation, operationID: root["operationId"] as? String ?? UUID().uuidString, idempotencyKey: root["idempotencyKey"] as? String, validateOnly: root["validateOnly"] as? Bool == true, input: input)
    }

    private func exact(_ object: [String: Any], allowed: Set<String>, path: String) throws {
        if let key = object.keys.first(where: { !allowed.contains($0) }) {
            throw StudioAgentError("UNKNOWN_FIELD", "unknown field: \(path).\(key)", path: "\(path).\(key)")
        }
    }

    private func rejectForbidden(_ value: Any, path: String) throws {
        if let object = value as? [String: Any] {
            for (key, nested) in object {
                if Self.forbiddenFields.contains(key) { throw StudioAgentError("ARBITRARY_EXECUTION_REJECTED", "\(path).\(key) is not accepted", path: "\(path).\(key)") }
                try rejectForbidden(nested, path: "\(path).\(key)")
            }
        } else if let array = value as? [Any] {
            for (index, nested) in array.enumerated() { try rejectForbidden(nested, path: "\(path)[\(index)]") }
        }
    }

    private func graph(from value: Any?) throws -> EffectGraph {
        guard let value else { throw StudioAgentError("REQUIRED_FIELD", "input.graph is required", path: "input.graph") }
        return try JSONDecoder().decode(EffectGraph.self, from: JSONSerialization.data(withJSONObject: value))
    }

    private func normalizedObject(_ value: NormalizedGraph) throws -> [String: Any] {
        ["graph": try object(value.graph), "graphHash": value.canonicalHash, "warnings": try value.warnings.map(object)]
    }

    private func object<T: Encodable>(_ value: T) throws -> Any {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return try JSONSerialization.jsonObject(with: encoder.encode(value))
    }

    private func stableHash(_ value: Any) throws -> String {
        let data = try JSONSerialization.data(withJSONObject: value, options: [.sortedKeys])
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private func requiredString(_ object: [String: Any], _ key: String, prefix: String = "input.") throws -> String {
        guard let value = object[key] as? String, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw StudioAgentError("REQUIRED_FIELD", "\(prefix)\(key) is required", path: "\(prefix)\(key)")
        }
        return value
    }

    private func optionalString(_ object: [String: Any], _ key: String, default defaultValue: String) throws -> String {
        guard let value = object[key] else { return defaultValue }
        guard let text = value as? String, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw StudioAgentError("INVALID_INPUT", "input.\(key) must be a non-empty string", path: "input.\(key)")
        }
        return text
    }

    private func optionalInt(_ object: [String: Any], _ key: String, default defaultValue: Int) throws -> Int {
        guard let value = object[key] else { return defaultValue }
        guard let number = value as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID(), Double(truncating: number).rounded() == Double(truncating: number) else {
            throw StudioAgentError("INVALID_INPUT", "input.\(key) must be an integer", path: "input.\(key)")
        }
        return number.intValue
    }

    private func optionalDouble(_ object: [String: Any], _ key: String, default defaultValue: Double) throws -> Double {
        guard let value = object[key] else { return defaultValue }
        guard let number = value as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID() else {
            throw StudioAgentError("INVALID_INPUT", "input.\(key) must be a number", path: "input.\(key)")
        }
        return number.doubleValue
    }

    private func requiredDouble(_ object: [String: Any], _ key: String) throws -> Double {
        guard let value = object[key] as? NSNumber,
              CFGetTypeID(value) != CFBooleanGetTypeID(),
              value.doubleValue.isFinite
        else {
            throw StudioAgentError("INVALID_INPUT", "input.\(key) must be a finite number", path: "input.\(key)")
        }
        return value.doubleValue
    }

    private func requiredPath(_ object: [String: Any], _ key: String) throws -> URL {
        let url = URL(filePath: try requiredString(object, key))
        guard FileManager.default.fileExists(atPath: url.path) else { throw StudioAgentError("PATH_NOT_FOUND", "input.\(key) does not exist", path: "input.\(key)") }
        return url
    }

    private func outputPath(_ object: [String: Any], _ key: String) throws -> URL {
        URL(filePath: try requiredString(object, key))
    }

    private func requiredUUID(_ object: [String: Any], _ key: String) throws -> UUID {
        guard let value = UUID(uuidString: try requiredString(object, key)) else { throw StudioAgentError("INVALID_UUID", "input.\(key) must be a UUID", path: "input.\(key)") }
        return value
    }

    private func effectType(_ value: Any?) throws -> EffectType {
        guard let raw = value as? String, let type = EffectType(rawValue: raw) else { throw StudioAgentError("UNSUPPORTED_EFFECT", "input.effect must name a registered effect", path: "input.effect") }
        return type
    }

    private func sideEffect(_ operation: String) -> String {
        switch operation {
        case "render": "render"
        case "select", "export": "write"
        case "plan", "edit": "plan"
        default: "read"
        }
    }

    private static func plannerDescription(_ graphs: [EffectGraph]) -> String {
        graphs.first?.provenance.name ?? "unknown"
    }

    private static func timestamp() -> String { ISO8601DateFormatter().string(from: Date()) }
}

private struct Request: @unchecked Sendable {
    let operation: String
    let operationID: String
    let idempotencyKey: String?
    let validateOnly: Bool
    let input: [String: Any]
}
