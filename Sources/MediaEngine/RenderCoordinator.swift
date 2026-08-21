import Foundation
import StudioCore

public struct RenderRequest: Sendable {
  public enum Mode: String, Sendable {
    case preview
    case final
  }

  public let sourceURL: URL
  public let outputURL: URL
  public let normalizedGraph: NormalizedGraph
  public let sourceFingerprint: String
  public let mode: Mode

  public init(
    sourceURL: URL, outputURL: URL, normalizedGraph: NormalizedGraph, sourceFingerprint: String,
    mode: Mode = .preview
  ) {
    self.sourceURL = sourceURL
    self.outputURL = outputURL
    self.normalizedGraph = normalizedGraph
    self.sourceFingerprint = sourceFingerprint
    self.mode = mode
  }
}

public protocol VariantRendering: Sendable {
  func render(_ request: RenderRequest) async throws -> RenderManifest
}

public enum RenderCoordinatorError: Error, Equatable, Sendable {
  case alreadyRunning
}

public actor RenderCoordinator {
  private var states: [UUID: RenderState] = [:]
  private var activeTask: Task<Void, Never>?
  private var cancelRequested = false

  public init() {}

  public func state(for variantID: UUID) -> RenderState? {
    states[variantID]
  }

  public func allStates() -> [UUID: RenderState] {
    states
  }

  public func start(requests: [RenderRequest], renderer: any VariantRendering) throws {
    guard activeTask == nil else { throw RenderCoordinatorError.alreadyRunning }
    cancelRequested = false
    for request in requests { states[request.normalizedGraph.graph.id] = .queued }
    activeTask = Task { [requests] in
      for request in requests {
        if self.shouldCancel() {
          self.setState(.cancelled, for: request.normalizedGraph.graph.id)
          continue
        }
        self.setState(.rendering, for: request.normalizedGraph.graph.id)
        do {
          let manifest = try await renderer.render(request)
          self.setState(manifest.state, for: request.normalizedGraph.graph.id)
        } catch is CancellationError {
          self.setState(.cancelled, for: request.normalizedGraph.graph.id)
        } catch {
          self.setState(.failed, for: request.normalizedGraph.graph.id)
        }
      }
      self.finish()
    }
  }

  public func cancel() {
    cancelRequested = true
    activeTask?.cancel()
  }

  public func waitUntilFinished() async {
    await activeTask?.value
  }

  private func shouldCancel() -> Bool {
    cancelRequested || Task.isCancelled
  }

  private func setState(_ state: RenderState, for id: UUID) {
    states[id] = state
  }

  private func finish() {
    activeTask = nil
  }
}
