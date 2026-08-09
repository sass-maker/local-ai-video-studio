@preconcurrency import AVFoundation
import CoreImage
import CoreMedia
import Foundation
import StudioCore

public enum VideoRenderError: Error, Sendable {
    case missingVideoTrack
    case cannotCreateCompositionTrack
    case cannotCreateExporter
    case exportFailed(String)
    case exportProducedNoFile
}

public struct AVFoundationRenderer: VariantRendering, Sendable {
    private let compiler: GraphCompiler

    public init(compiler: GraphCompiler = .init()) {
        self.compiler = compiler
    }

    public func render(_ request: RenderRequest) async throws -> RenderManifest {
        try Task.checkCancellation()
        let pipeline = try compiler.compile(request.normalizedGraph)
        let asset = AVURLAsset(url: request.sourceURL)
        guard let sourceVideo = try await asset.loadTracks(withMediaType: .video).first else {
            throw VideoRenderError.missingVideoTrack
        }

        let composition = AVMutableComposition()
        guard let videoTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) else {
            throw VideoRenderError.cannotCreateCompositionTrack
        }
        let sourceDuration = try await asset.load(.duration)
        let graphEnd = pipeline.segments.map(\.end).max() ?? sourceDuration.seconds
        let chosenDuration = min(max(graphEnd, 0), sourceDuration.seconds)
        let timeRange = CMTimeRange(start: .zero, duration: CMTime(seconds: chosenDuration, preferredTimescale: 600))
        try videoTrack.insertTimeRange(timeRange, of: sourceVideo, at: .zero)
        videoTrack.preferredTransform = try await sourceVideo.load(.preferredTransform)

        var audioMix: AVMutableAudioMix?
        if let sourceAudio = try await asset.loadTracks(withMediaType: .audio).first,
           let audioTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) {
            try audioTrack.insertTimeRange(timeRange, of: sourceAudio, at: .zero)
            if pipeline.segments.flatMap(\.operations).contains(.audioNormalize) {
                let parameters = AVMutableAudioMixInputParameters(track: audioTrack)
                parameters.setVolume(1, at: .zero)
                let mix = AVMutableAudioMix()
                mix.inputParameters = [parameters]
                audioMix = mix
            }
        }

        if let speed = firstSpeed(in: pipeline), speed != 1 {
            let scaled = CMTimeMultiplyByFloat64(timeRange.duration, multiplier: 1 / speed)
            composition.scaleTimeRange(CMTimeRange(start: .zero, duration: timeRange.duration), toDuration: scaled)
        }

        let outputSize = renderSize(for: pipeline.output, mode: request.mode)
        let degradations = degradationRecords(in: request.normalizedGraph.graph)
        let videoComposition = AVMutableVideoComposition(asset: composition) { filterRequest in
            let seconds = filterRequest.compositionTime.seconds
            var image = centerCrop(filterRequest.sourceImage, to: outputSize)
            for operation in activeOperations(at: seconds, pipeline: pipeline) {
                if case let .filter(recipe, strength) = operation {
                    image = recipe.applying(to: image, strength: strength, time: seconds)
                }
            }
            filterRequest.finish(with: image, context: nil)
        }
        videoComposition.renderSize = outputSize
        videoComposition.frameDuration = CMTime(value: 1, timescale: CMTimeScale(pipeline.output.fps))

        let temporaryURL = request.outputURL.deletingLastPathComponent()
            .appending(path: ".\(request.outputURL.deletingPathExtension().lastPathComponent)-\(UUID().uuidString).partial.mp4")
        guard let exporter = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else {
            throw VideoRenderError.cannotCreateExporter
        }
        exporter.videoComposition = videoComposition
        exporter.audioMix = audioMix
        exporter.outputURL = temporaryURL
        exporter.outputFileType = .mp4
        exporter.shouldOptimizeForNetworkUse = false

        try await export(exporter)
        try Task.checkCancellation()
        guard FileManager.default.fileExists(atPath: temporaryURL.path) else {
            throw VideoRenderError.exportProducedNoFile
        }
        if FileManager.default.fileExists(atPath: request.outputURL.path) {
            _ = try FileManager.default.replaceItemAt(request.outputURL, withItemAt: temporaryURL)
        } else {
            try FileManager.default.moveItem(at: temporaryURL, to: request.outputURL)
        }

        let finalState: RenderState = degradations.isEmpty ? .completed : .degraded
        let manifest = RenderManifest(
            state: finalState,
            outputRelativePath: request.outputURL.lastPathComponent,
            normalizedGraphHash: pipeline.graphHash,
            sourceFingerprint: request.sourceFingerprint,
            degradations: degradations,
            completedAt: Date()
        )
        let manifestURL = request.outputURL.appendingPathExtension("json")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(manifest).write(to: manifestURL, options: .atomic)
        return manifest
    }

    private func export(_ exporter: AVAssetExportSession) async throws {
        let box = ExportSessionBox(exporter)
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                box.value.exportAsynchronously {
                    switch box.value.status {
                    case .completed:
                        continuation.resume()
                    case .cancelled:
                        continuation.resume(throwing: CancellationError())
                    case .failed:
                        continuation.resume(throwing: VideoRenderError.exportFailed(box.value.error?.localizedDescription ?? "Unknown export failure"))
                    default:
                        continuation.resume(throwing: VideoRenderError.exportFailed("Export ended in state \(box.value.status.rawValue)"))
                    }
                }
            }
        } onCancel: {
            box.value.cancelExport()
        }
    }

    private func firstSpeed(in pipeline: CompiledPipeline) -> Double? {
        for operation in pipeline.segments.flatMap(\.operations) {
            if case let .speed(rate) = operation { return rate }
        }
        return nil
    }

    private func degradationRecords(in graph: EffectGraph) -> [DegradationRecord] {
        graph.timeline.flatMap(\.effects).compactMap { node in
            switch node.type {
            case .backgroundReplace:
                DegradationRecord(effectID: node.id, effectType: node.type, reason: "Subject segmentation adapter is unavailable; original background retained.")
            case .captionDynamic, .titleCard:
                DegradationRecord(effectID: node.id, effectType: node.type, reason: "Text overlay adapter is pending; video rendered without this overlay.")
            case .cropAutoSubject:
                DegradationRecord(effectID: node.id, effectType: node.type, reason: "Subject tracking adapter is unavailable; center crop used.")
            default:
                nil
            }
        }
    }
}

private final class ExportSessionBox: @unchecked Sendable {
    let value: AVAssetExportSession

    init(_ value: AVAssetExportSession) {
        self.value = value
    }
}

private func activeOperations(at seconds: Double, pipeline: CompiledPipeline) -> [CompiledOperation] {
    pipeline.segments.filter { seconds >= $0.start && seconds < $0.end }.flatMap(\.operations)
}

private func renderSize(for output: OutputProfile, mode: RenderRequest.Mode) -> CGSize {
    guard mode == .preview else { return CGSize(width: output.width, height: output.height) }
    let longEdge = 1280.0
    let sourceLongEdge = Double(max(output.width, output.height))
    let scale = min(1, longEdge / sourceLongEdge)
    return CGSize(width: (Double(output.width) * scale).rounded(), height: (Double(output.height) * scale).rounded())
}

private func centerCrop(_ input: CIImage, to outputSize: CGSize) -> CIImage {
    let extent = input.extent
    let scale = max(outputSize.width / extent.width, outputSize.height / extent.height)
    let scaled = input.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
    let translated = scaled.transformed(by: CGAffineTransform(
        translationX: (outputSize.width - scaled.extent.width) / 2 - scaled.extent.origin.x,
        y: (outputSize.height - scaled.extent.height) / 2 - scaled.extent.origin.y
    ))
    return translated.cropped(to: CGRect(origin: .zero, size: outputSize))
}
