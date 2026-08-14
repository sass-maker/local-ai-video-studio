@preconcurrency import AVFoundation
import CoreVideo
import Foundation
import StudioCore
import Testing

@testable import MediaEngine

@Test func previewDefaultsTo720pLongEdge() {
  #expect(MediaEngine.previewLongEdge == 1280)
}

private let output = OutputProfile(aspectRatio: .vertical, width: 1080, height: 1920, fps: 24)
private let provenance = PlannerProvenance(kind: .deterministicDemo, name: "test", version: "1")

private func normalized(label: String, id: UUID, effects: [EffectNode]) throws -> NormalizedGraph {
  try EffectGraphValidator().validate(
    EffectGraph(
      id: id,
      label: label,
      differenceSummary: "Distinct \(label) treatment.",
      provenance: provenance,
      output: output,
      timeline: [TimelineSegment(start: 0, end: 5, effects: effects)]
    ))
}

@Test func compilerPreservesTimelineAndEffectOrder() throws {
  let graph = try normalized(
    label: "Test", id: UUID(),
    effects: [
      EffectNode(
        type: .cropAutoSubject, parameters: .init(target: "primary_person"), required: true),
      EffectNode(type: .styleComic, parameters: .init(strength: 0.72)),
      EffectNode(type: .captionDynamic, parameters: .init(preset: "bold")),
      EffectNode(type: .audioNormalize),
    ])
  let pipeline = try GraphCompiler().compile(graph)

  #expect(pipeline.graphHash == graph.canonicalHash)
  #expect(pipeline.segments[0].start == 0)
  #expect(pipeline.segments[0].end == 5)
  #expect(
    pipeline.segments[0].operations == [
      .cropAutoSubject(target: "primary_person"),
      .filter(.comic, strength: 0.72),
      .caption(text: nil, preset: "bold"),
      .audioNormalize,
    ])
}

@Test func compilerRejectsMissingRequiredTitleText() throws {
  let graph = try normalized(label: "Title", id: UUID(), effects: [EffectNode(type: .titleCard)])
  #expect(throws: CompilationError.missingRequiredParameter(effect: .titleCard, parameter: "text"))
  {
    try GraphCompiler().compile(graph)
  }
}

@Test func compilerMapsEveryStyleEffectToItsFilterRecipe() throws {
  let expectations: [EffectType: CompiledOperation] = [
    .styleAnime: .filter(.anime, strength: 0.7),
    .styleComic: .filter(.comic, strength: 0.7),
    .styleSketch: .filter(.sketch, strength: 0.7),
    .styleWatercolor: .filter(.watercolor, strength: 0.7),
    .styleCel: .filter(.cel, strength: 0.7),
    .styleCinematic: .filter(.cinematic, strength: 0.7),
    .styleNoir: .filter(.noir, strength: 0.7),
    .styleVHS: .filter(.vhs, strength: 0.7),
  ]
  for (type, expected) in expectations {
    let graph = try normalized(label: "Style", id: UUID(), effects: [EffectNode(type: type)])
    let pipeline = try GraphCompiler().compile(graph)
    #expect(pipeline.segments[0].operations == [expected], "Default strength for \(type.rawValue)")
  }
}

@Test func compilerMapsEveryFilterEffectToItsDefaultStrength() throws {
  let expectations: [EffectType: CompiledOperation] = [
    .backgroundBlur: .filter(.backgroundBlur, strength: 0.5),
    .outline: .filter(.outline, strength: 0.5),
    .glow: .filter(.glow, strength: 0.5),
    .beatFlash: .filter(.beatFlash, strength: 0.35),
    .beatZoom: .filter(.beatZoom, strength: 0.25),
    .colorGrade: .filter(.colorGrade, strength: 0.5),
  ]
  for (type, expected) in expectations {
    let graph = try normalized(label: "Filter", id: UUID(), effects: [EffectNode(type: type)])
    let pipeline = try GraphCompiler().compile(graph)
    #expect(pipeline.segments[0].operations == [expected], "Default strength for \(type.rawValue)")
  }
}

@Test func compilerHonoursExplicitStyleStrength() throws {
  let graph = try normalized(
    label: "Strong", id: UUID(),
    effects: [
      EffectNode(type: .styleAnime, parameters: .init(strength: 0.42))
    ])
  let pipeline = try GraphCompiler().compile(graph)
  #expect(pipeline.segments[0].operations == [.filter(.anime, strength: 0.42)])
}

private enum FakeRenderError: Error { case deliberate }

private actor FakeRenderer: VariantRendering {
  let failingID: UUID?
  let delay: Duration

  init(failingID: UUID? = nil, delay: Duration = .zero) {
    self.failingID = failingID
    self.delay = delay
  }

  func render(_ request: RenderRequest) async throws -> RenderManifest {
    if delay > .zero { try await Task.sleep(for: delay) }
    if request.normalizedGraph.graph.id == failingID { throw FakeRenderError.deliberate }
    return RenderManifest(
      state: .completed,
      outputRelativePath: request.outputURL.lastPathComponent,
      normalizedGraphHash: request.normalizedGraph.canonicalHash,
      sourceFingerprint: request.sourceFingerprint,
      completedAt: Date()
    )
  }
}

@Test func coordinatorIsolatesVariantFailureAndCompletesSiblings() async throws {
  let firstID = UUID()
  let failedID = UUID()
  let thirdID = UUID()
  let graphs = try [
    normalized(label: "First", id: firstID, effects: []),
    normalized(label: "Failed", id: failedID, effects: []),
    normalized(label: "Third", id: thirdID, effects: []),
  ]
  let requests = graphs.map {
    RenderRequest(
      sourceURL: URL(filePath: "/source.mov"), outputURL: URL(filePath: "/\($0.graph.label).mp4"),
      normalizedGraph: $0, sourceFingerprint: "source")
  }
  let coordinator = RenderCoordinator()
  try await coordinator.start(requests: requests, renderer: FakeRenderer(failingID: failedID))
  await coordinator.waitUntilFinished()

  #expect(await coordinator.state(for: firstID) == .completed)
  #expect(await coordinator.state(for: failedID) == .failed)
  #expect(await coordinator.state(for: thirdID) == .completed)
}

@Test func coordinatorCancelsPendingVariants() async throws {
  let firstID = UUID()
  let secondID = UUID()
  let graphs = try [
    normalized(label: "First", id: firstID, effects: []),
    normalized(label: "Second", id: secondID, effects: []),
  ]
  let requests = graphs.map {
    RenderRequest(
      sourceURL: URL(filePath: "/source.mov"), outputURL: URL(filePath: "/\($0.graph.label).mp4"),
      normalizedGraph: $0, sourceFingerprint: "source")
  }
  let coordinator = RenderCoordinator()
  try await coordinator.start(requests: requests, renderer: FakeRenderer(delay: .seconds(1)))
  await coordinator.cancel()
  await coordinator.waitUntilFinished()

  #expect(await coordinator.state(for: firstID) == .cancelled)
  #expect(await coordinator.state(for: secondID) == .cancelled)
}

@Test func analyzerAndRendererProcessLocalFixture() async throws {
  let temporary = FileManager.default.temporaryDirectory.appending(
    path: UUID().uuidString, directoryHint: .isDirectory)
  try FileManager.default.createDirectory(at: temporary, withIntermediateDirectories: true)
  defer { try? FileManager.default.removeItem(at: temporary) }
  let sourceURL = temporary.appending(path: "fixture.mov")
  let outputURL = temporary.appending(path: "rendered.mp4")
  try await makeFixtureVideo(at: sourceURL)

  let metadata = try await MediaAnalyzer().analyze(sourceURL)
  #expect(metadata.width == 320)
  #expect(metadata.height == 180)
  #expect(metadata.duration > 0.8)

  let graph = try normalized(
    label: "Noir", id: UUID(),
    effects: [
      EffectNode(type: .styleNoir, parameters: .init(strength: 0.7))
    ])
  let fingerprint = try SourceFingerprint.make(for: sourceURL)
  let manifest = try await AVFoundationRenderer().render(
    RenderRequest(
      sourceURL: sourceURL,
      outputURL: outputURL,
      normalizedGraph: graph,
      sourceFingerprint: fingerprint,
      mode: .preview
    ))

  #expect(manifest.state == .completed)
  #expect(FileManager.default.fileExists(atPath: outputURL.path))
  #expect(FileManager.default.fileExists(atPath: outputURL.appendingPathExtension("json").path))
  let rendered = try await MediaAnalyzer().analyze(outputURL)
  #expect(rendered.width == 720)
  #expect(rendered.height == 1280)
}

private func makeFixtureVideo(at url: URL) async throws {
  let writer = try AVAssetWriter(outputURL: url, fileType: .mov)
  let input = AVAssetWriterInput(
    mediaType: .video,
    outputSettings: [
      AVVideoCodecKey: AVVideoCodecType.h264,
      AVVideoWidthKey: 320,
      AVVideoHeightKey: 180,
    ])
  let adaptor = AVAssetWriterInputPixelBufferAdaptor(
    assetWriterInput: input,
    sourcePixelBufferAttributes: [
      kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
      kCVPixelBufferWidthKey as String: 320,
      kCVPixelBufferHeightKey as String: 180,
    ])
  #expect(writer.canAdd(input))
  writer.add(input)
  #expect(writer.startWriting())
  writer.startSession(atSourceTime: .zero)

  for frame in 0..<24 {
    while !input.isReadyForMoreMediaData { try await Task.sleep(for: .milliseconds(2)) }
    var pixelBuffer: CVPixelBuffer?
    let status = CVPixelBufferCreate(
      kCFAllocatorDefault, 320, 180, kCVPixelFormatType_32BGRA, nil, &pixelBuffer)
    guard status == kCVReturnSuccess, let pixelBuffer else { throw FakeRenderError.deliberate }
    CVPixelBufferLockBaseAddress(pixelBuffer, [])
    if let address = CVPixelBufferGetBaseAddress(pixelBuffer) {
      let byteCount = CVPixelBufferGetBytesPerRow(pixelBuffer) * CVPixelBufferGetHeight(pixelBuffer)
      memset(address, Int32((frame * 7) % 255), byteCount)
    }
    CVPixelBufferUnlockBaseAddress(pixelBuffer, [])
    #expect(
      adaptor.append(
        pixelBuffer, withPresentationTime: CMTime(value: CMTimeValue(frame), timescale: 24)))
  }
  input.markAsFinished()
  let box = WriterBox(writer)
  await withCheckedContinuation { continuation in
    box.value.finishWriting { continuation.resume() }
  }
  guard writer.status == .completed else {
    throw writer.error ?? FakeRenderError.deliberate
  }
}

private final class WriterBox: @unchecked Sendable {
  let value: AVAssetWriter
  init(_ value: AVAssetWriter) { self.value = value }
}
