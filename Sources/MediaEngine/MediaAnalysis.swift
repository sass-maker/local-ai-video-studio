@preconcurrency import AVFoundation
import CoreMedia
import Foundation
import StudioCore

public enum MediaAnalysisError: Error, Equatable, Sendable {
    case unsupportedExtension(String)
    case unreadable
    case missingVideoTrack
    case invalidDuration
}

public struct MediaAnalyzer: Sendable {
    public init() {}

    public func analyze(_ url: URL) async throws -> MediaMetadata {
        let fileExtension = url.pathExtension.lowercased()
        guard ["mp4", "mov"].contains(fileExtension) else {
            throw MediaAnalysisError.unsupportedExtension(fileExtension)
        }

        let asset = AVURLAsset(url: url)
        guard try await asset.load(.isReadable) else { throw MediaAnalysisError.unreadable }
        let duration = try await asset.load(.duration).seconds
        guard duration.isFinite, duration > 0 else { throw MediaAnalysisError.invalidDuration }
        guard let video = try await asset.loadTracks(withMediaType: .video).first else {
            throw MediaAnalysisError.missingVideoTrack
        }

        let size = try await video.load(.naturalSize).applying(try await video.load(.preferredTransform))
        let fps = try await video.load(.nominalFrameRate)
        let descriptions = try await video.load(.formatDescriptions)
        let codec = descriptions.first.map { description in
            fourCCString(CMFormatDescriptionGetMediaSubType(description))
        } ?? "unknown"
        let hasAudio = try await !asset.loadTracks(withMediaType: .audio).isEmpty

        return MediaMetadata(
            duration: duration,
            width: Int(abs(size.width).rounded()),
            height: Int(abs(size.height).rounded()),
            fps: Double(fps),
            hasAudio: hasAudio,
            codec: codec
        )
    }

    public func makeSourceReference(for url: URL, projectURL: URL?, metadata: MediaMetadata) throws -> SourceReference {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        let size = (attributes[.size] as? NSNumber)?.int64Value ?? 0
        let bookmark = try? url.bookmarkData(options: [.withSecurityScope], includingResourceValuesForKeys: nil, relativeTo: nil)
        return SourceReference(
            displayName: url.lastPathComponent,
            relativePath: projectURL.flatMap { SourceLocator.relativePath(from: $0, to: url) },
            originalPath: url.path,
            bookmark: bookmark,
            fingerprint: try SourceFingerprint.make(for: url),
            fileSize: size,
            metadata: metadata
        )
    }
}

private func fourCCString(_ value: FourCharCode) -> String {
    let bytes: [UInt8] = [24, 16, 8, 0].map { UInt8((value >> $0) & 0xff) }
    return String(bytes: bytes, encoding: .macOSRoman) ?? String(format: "0x%08x", value)
}
