import CryptoKit
import Foundation

public struct MediaMetadata: Codable, Equatable, Sendable {
    public var duration: Double
    public var width: Int
    public var height: Int
    public var fps: Double
    public var hasAudio: Bool
    public var codec: String

    public init(duration: Double, width: Int, height: Int, fps: Double, hasAudio: Bool, codec: String) {
        self.duration = duration
        self.width = width
        self.height = height
        self.fps = fps
        self.hasAudio = hasAudio
        self.codec = codec
    }
}

public struct SourceReference: Codable, Equatable, Sendable {
    public var displayName: String
    public var relativePath: String?
    public var originalPath: String
    public var bookmark: Data?
    public var fingerprint: String
    public var fileSize: Int64
    public var metadata: MediaMetadata

    public init(displayName: String, relativePath: String?, originalPath: String, bookmark: Data?, fingerprint: String, fileSize: Int64, metadata: MediaMetadata) {
        self.displayName = displayName
        self.relativePath = relativePath
        self.originalPath = originalPath
        self.bookmark = bookmark
        self.fingerprint = fingerprint
        self.fileSize = fileSize
        self.metadata = metadata
    }
}

public enum RenderState: String, Codable, Sendable {
    case planned
    case queued
    case rendering
    case completed
    case degraded
    case failed
    case cancelled
}

public struct DegradationRecord: Codable, Equatable, Sendable {
    public var effectID: UUID
    public var effectType: EffectType
    public var reason: String

    public init(effectID: UUID, effectType: EffectType, reason: String) {
        self.effectID = effectID
        self.effectType = effectType
        self.reason = reason
    }
}

public struct RenderManifest: Codable, Equatable, Sendable {
    public var state: RenderState
    public var outputRelativePath: String?
    public var normalizedGraphHash: String
    public var sourceFingerprint: String
    public var degradations: [DegradationRecord]
    public var completedAt: Date?

    public init(state: RenderState, outputRelativePath: String? = nil, normalizedGraphHash: String, sourceFingerprint: String, degradations: [DegradationRecord] = [], completedAt: Date? = nil) {
        self.state = state
        self.outputRelativePath = outputRelativePath
        self.normalizedGraphHash = normalizedGraphHash
        self.sourceFingerprint = sourceFingerprint
        self.degradations = degradations
        self.completedAt = completedAt
    }
}

public struct VariantRevision: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var revision: Int
    public var graph: EffectGraph
    public var normalizedGraphHash: String
    public var render: RenderManifest?

    public init(id: UUID = UUID(), revision: Int, graph: EffectGraph, normalizedGraphHash: String, render: RenderManifest? = nil) {
        self.id = id
        self.revision = revision
        self.graph = graph
        self.normalizedGraphHash = normalizedGraphHash
        self.render = render
    }
}

public struct VariantComparison: Codable, Equatable, Sendable {
    public var ratings: [UUID: Int]
    public var selectedVariantID: UUID?
    public var isBlinded: Bool
    public var sharedPlayhead: Double

    public init(ratings: [UUID: Int] = [:], selectedVariantID: UUID? = nil, isBlinded: Bool = false, sharedPlayhead: Double = 0) {
        self.ratings = ratings
        self.selectedVariantID = selectedVariantID
        self.isBlinded = isBlinded
        self.sharedPlayhead = sharedPlayhead
    }
}

public struct StudioProject: Codable, Equatable, Identifiable, Sendable {
    public var schemaVersion: Int
    public var id: UUID
    public var name: String
    public var createdAt: Date
    public var updatedAt: Date
    public var instruction: String
    public var source: SourceReference
    public var variants: [VariantRevision]
    public var comparison: VariantComparison

    public init(
        schemaVersion: Int = StudioCore.projectSchemaVersion,
        id: UUID = UUID(),
        name: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        instruction: String,
        source: SourceReference,
        variants: [VariantRevision] = [],
        comparison: VariantComparison = .init()
    ) {
        self.schemaVersion = schemaVersion
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.instruction = instruction
        self.source = source
        self.variants = variants
        self.comparison = comparison
    }
}

public enum ProjectPersistenceError: Error, Equatable, Sendable {
    case unsupportedSchema(Int)
    case sourceMissing
    case sourceFingerprintMismatch
}

public actor ProjectStore {
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init() {
        encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    public func save(_ project: StudioProject, to url: URL) throws {
        var current = project
        current.updatedAt = Date()
        let data = try encoder.encode(current)
        try data.write(to: url, options: .atomic)
    }

    public func load(from url: URL) throws -> StudioProject {
        let project = try decoder.decode(StudioProject.self, from: Data(contentsOf: url))
        guard project.schemaVersion == StudioCore.projectSchemaVersion else {
            throw ProjectPersistenceError.unsupportedSchema(project.schemaVersion)
        }
        return project
    }
}

public enum SourceFingerprint {
    public static func make(for url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var hasher = SHA256()
        while let data = try handle.read(upToCount: 1_048_576), !data.isEmpty {
            hasher.update(data: data)
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    public static func verify(_ url: URL, expected: String) throws {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw ProjectPersistenceError.sourceMissing
        }
        guard try make(for: url) == expected else {
            throw ProjectPersistenceError.sourceFingerprintMismatch
        }
    }
}

public enum SourceLocator {
    public static func relativePath(from projectURL: URL, to sourceURL: URL) -> String? {
        let projectComponents = projectURL.deletingLastPathComponent().standardizedFileURL.pathComponents
        let sourceComponents = sourceURL.standardizedFileURL.pathComponents
        var common = 0
        while common < min(projectComponents.count, sourceComponents.count), projectComponents[common] == sourceComponents[common] {
            common += 1
        }
        guard common > 1 else { return nil }
        let ups = Array(repeating: "..", count: projectComponents.count - common)
        return (ups + sourceComponents.dropFirst(common)).joined(separator: "/")
    }

    public static func resolve(_ reference: SourceReference, relativeTo projectURL: URL) -> URL? {
        if let relativePath = reference.relativePath {
            let candidate = projectURL.deletingLastPathComponent().appending(path: relativePath).standardizedFileURL
            if FileManager.default.fileExists(atPath: candidate.path) { return candidate }
        }
        let original = URL(filePath: reference.originalPath)
        if FileManager.default.fileExists(atPath: original.path) { return original }
        guard let bookmark = reference.bookmark else { return nil }
        var stale = false
        return try? URL(resolvingBookmarkData: bookmark, options: [.withSecurityScope], relativeTo: nil, bookmarkDataIsStale: &stale)
    }
}
