import AppKit
import AVFoundation
import Foundation
import MediaEngine
import StudioCore

@MainActor
final class StudioViewModel: ObservableObject {
    @Published var sourceURL: URL?
    @Published var source: SourceReference?
    @Published var sourcePlayer: AVPlayer?
    @Published var instruction = "Create three vertical reels. Use cel-shaded anime, comic-book styling, and an original treatment with a replaced background, captions, and beat-synced flashes."
    @Published var variantCount = 3
    @Published var variants: [NormalizedGraph] = []
    @Published var states: [UUID: RenderState] = [:]
    @Published var outputURLs: [UUID: URL] = [:]
    @Published var manifests: [UUID: RenderManifest] = [:]
    @Published var players: [UUID: AVPlayer] = [:]
    @Published var selectedID: UUID?
    @Published var savedVariantIDs: Set<UUID> = []
    @Published var isBlinded = false
    @Published var sharedTime = 0.0
    @Published var isPlaying = false
    @Published var driftedIDs: Set<UUID> = []
    @Published var message = "Import a local MP4 or MOV to begin."
    @Published var diagnostics: [GraphDiagnostic] = []
    @Published var isBusy = false
    @Published var isRendering = false

    private let analyzer = MediaAnalyzer()
    private let planner = PreferredVariantPlanner()
    private let validator = EffectGraphValidator()
    private let graphEditor = EffectGraphEditor()
    private let renderer = AVFoundationRenderer()
    private let projectStore = ProjectStore()
    private var projectURL: URL?
    private var projectID = UUID()
    private var projectCreatedAt = Date()
    private var playbackMonitor: Task<Void, Never>?
    private var renderTask: Task<Void, Never>?
    private var saveTask: Task<Void, Never>?
    private var importOperationID: UUID?
    private var renderOperationID: UUID?
    private var planOperationID: UUID?

    var duration: Double { source?.metadata.duration ?? 0 }

    var effectCatalog: [EffectDefinition] { EffectRegistry.standard.allDefinitions }

    var estimate: RenderEstimate? {
        variants.first.map { RenderEstimator().estimate($0.graph) }
    }

    var diskPreflight: DiskSpacePreflight? {
        guard let estimate else { return nil }
        let directory = FileManager.default.temporaryDirectory
        let values = try? directory.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
        let available = values?.volumeAvailableCapacityForImportantUsage ?? 0
        return DiskSpacePreflight(requiredBytes: estimate.estimatedBytes * Int64(max(variants.count, 1)), availableBytes: available)
    }

    var canExportSelected: Bool {
        guard let selectedID,
              let variant = variants.first(where: { $0.graph.id == selectedID }),
              let manifest = manifests[selectedID],
              outputURLs[selectedID] != nil,
              [.completed, .degraded].contains(manifest.state)
        else { return false }
        return manifest.normalizedGraphHash == variant.canonicalHash
    }

    func importVideo(_ url: URL) {
        planOperationID = nil
        renderOperationID = nil
        renderTask?.cancel()
        renderTask = nil
        let operationID = UUID()
        importOperationID = operationID
        isBusy = true
        message = "Analysing media locally…"
        Task {
            let accessing = url.startAccessingSecurityScopedResource()
            defer { if accessing { url.stopAccessingSecurityScopedResource() } }
            do {
                let metadata = try await analyzer.analyze(url)
                guard self.importOperationID == operationID else { return }
                let reference = try analyzer.makeSourceReference(for: url, projectURL: nil, metadata: metadata)
                self.sourceURL = url
                self.source = reference
                self.sourcePlayer = AVPlayer(url: url)
                self.variants = []
                self.states = [:]
                self.outputURLs = [:]
                self.players = [:]
                self.manifests = [:]
                self.playbackMonitor?.cancel()
                self.playbackMonitor = nil
                self.renderTask?.cancel()
                self.renderTask = nil
                self.isPlaying = false
                self.isRendering = false
                self.selectedID = nil
                self.savedVariantIDs = []
                self.diagnostics = []
                self.driftedIDs = []
                self.sharedTime = 0
                self.projectID = UUID()
                self.projectCreatedAt = Date()
                self.projectURL = self.makeProjectURL(for: reference)
                self.message = "Video loaded. Create previews when you’re ready."
                self.persistProject()
            } catch {
                guard self.importOperationID == operationID else { return }
                self.message = "Import failed: \(error.localizedDescription)"
            }
            guard self.importOperationID == operationID else { return }
            self.importOperationID = nil
            self.isBusy = false
        }
    }

    func createPreviews() {
        planVariants(renderAfterPlanning: true)
    }

    func planVariants(renderAfterPlanning: Bool = false) {
        guard let source else {
            message = "Import a source video before planning."
            return
        }
        isBusy = true
        let operationID = UUID()
        planOperationID = operationID
        message = "Compiling intent into strict effect graphs…"
        Task {
            var shouldRender = false
            do {
                let request = PlanningRequest(
                    instruction: instruction,
                    variantCount: variantCount,
                    output: OutputProfile(aspectRatio: .vertical, width: 1080, height: 1920, fps: 24),
                    duration: source.metadata.duration
                )
                let planned = try await planner.plan(request)
                guard self.planOperationID == operationID else { return }
                let normalized = try planned.map(validator.validate)
                variants = normalized
                diagnostics = normalized.flatMap(\.warnings)
                states = Dictionary(uniqueKeysWithValues: normalized.map { ($0.graph.id, .planned) })
                selectedID = normalized.first?.graph.id
                message = "\(normalized.count) reproducible plans ready. Review warnings before rendering."
                persistProject()
                shouldRender = renderAfterPlanning
            } catch let failure as GraphValidationFailure {
                guard self.planOperationID == operationID else { return }
                diagnostics = failure.diagnostics
                message = "Planning produced an invalid graph. Nothing was executed."
            } catch {
                guard self.planOperationID == operationID else { return }
                message = "Planning failed: \(error.localizedDescription)"
            }
            guard self.planOperationID == operationID else { return }
            self.planOperationID = nil
            isBusy = false
            if shouldRender { renderVariants() }
        }
    }

    func renderVariants() {
        renderVariants(targetIDs: nil)
    }

    func renderChangedVariants() {
        let changed = Set(states.compactMap { $0.value == .planned ? $0.key : nil })
        guard !changed.isEmpty else {
            message = "No changed studies need a new preview."
            return
        }
        renderVariants(targetIDs: changed)
    }

    private func renderVariants(targetIDs: Set<UUID>?) {
        guard let sourceURL, let source, !variants.isEmpty else {
            message = "Import and plan variants before rendering."
            return
        }
        guard diskPreflight?.canStart != false else {
            message = "Not enough local disk space for this render batch."
            return
        }
        isBusy = true
        isRendering = true
        let operationID = UUID()
        renderOperationID = operationID
        message = "Rendering locally, one variant at a time…"
        renderTask = Task {
            let outputDirectory = FileManager.default.temporaryDirectory
                .appending(path: "LocalVideoStudio-\(source.fingerprint.prefix(12))", directoryHint: .isDirectory)
            do {
                try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
                for variant in variants where targetIDs?.contains(variant.graph.id) ?? true {
                    try Task.checkCancellation()
                    guard self.renderOperationID == operationID else { throw CancellationError() }
                    let id = variant.graph.id
                    states[id] = .rendering
                    let fileName = exportStem(for: variant) + "-preview.mp4"
                    let outputURL = outputDirectory.appending(path: fileName)
                    do {
                        let manifest = try await renderer.render(RenderRequest(
                            sourceURL: sourceURL,
                            outputURL: outputURL,
                            normalizedGraph: variant,
                            sourceFingerprint: source.fingerprint,
                            mode: .preview
                        ))
                        guard self.renderOperationID == operationID else { throw CancellationError() }
                        states[id] = manifest.state
                        manifests[id] = manifest
                        outputURLs[id] = outputURL
                        players[id] = AVPlayer(url: outputURL)
                    } catch is CancellationError {
                        guard self.renderOperationID == operationID else { return }
                        states[id] = .cancelled
                    } catch {
                        guard self.renderOperationID == operationID else { return }
                        states[id] = .failed
                        diagnostics.append(.init(severity: .error, path: variant.graph.label, message: error.localizedDescription))
                    }
                }
                guard self.renderOperationID == operationID else { return }
                message = targetIDs == nil
                    ? "Local previews finished. Degraded variants remain playable and disclose fallbacks."
                    : "Changed studies were rerendered. Degraded results disclose every fallback."
                persistProject()
            } catch {
                guard self.renderOperationID == operationID else { return }
                message = "Render batch stopped: \(error.localizedDescription)"
            }
            guard self.renderOperationID == operationID else { return }
            isBusy = false
            isRendering = false
            renderTask = nil
            renderOperationID = nil
        }
    }

    func cancelRendering() {
        renderOperationID = nil
        renderTask?.cancel()
        renderTask = nil
        isRendering = false
        isBusy = false
        for id in states.keys where states[id] == .queued || states[id] == .rendering {
            states[id] = .cancelled
        }
        message = "Render cancelled. Completed previews remain available."
        persistProject()
    }

    func togglePlayback() {
        if isPlaying {
            players.values.forEach { $0.pause() }
            playbackMonitor?.cancel()
            playbackMonitor = nil
        } else {
            seekAll(to: sharedTime)
            players.values.forEach { $0.play() }
            startPlaybackMonitor()
        }
        isPlaying.toggle()
    }

    func restartPlayback() {
        seekAll(to: 0)
        if isPlaying { players.values.forEach { $0.play() } }
    }

    func seekAll(to seconds: Double) {
        sharedTime = seconds
        let time = CMTime(seconds: seconds, preferredTimescale: 600)
        players.values.forEach { $0.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero) }
    }

    func toggleSaved(_ id: UUID) {
        if savedVariantIDs.contains(id) {
            savedVariantIDs.remove(id)
        } else {
            savedVariantIDs.insert(id)
        }
        persistProject()
    }

    var planJSON: String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        guard let data = try? encoder.encode(variants.map(\.graph)) else { return "No plan has been created yet." }
        return String(decoding: data, as: UTF8.self)
    }

    var plannerDescription: String {
        if variants.first?.graph.provenance.kind == .localModel {
            return "Apple Foundation Models · on-device · no video frames shared"
        }
        switch PreferredVariantPlanner.availability {
        case .available:
            return "Deterministic fallback · Apple model generation was unavailable for this plan"
        case let .unavailable(reason):
            return "Deterministic fallback · \(reason)"
        }
    }

    var plannerAvailabilityDescription: String {
        switch PreferredVariantPlanner.availability {
        case .available: "Apple on-device prompt planner ready"
        case let .unavailable(reason): "Preset planner active · \(reason)"
        }
    }

    func select(_ id: UUID) {
        selectedID = id
        persistProject()
    }

    func toggleBlinded() {
        isBlinded.toggle()
        persistProject()
    }

    func reviseStrength(for id: UUID, strength: Double) {
        guard let index = variants.firstIndex(where: { $0.graph.id == id }) else { return }
        var graph = variants[index].graph
        var didUpdate = false
        for segmentIndex in graph.timeline.indices {
            for effectIndex in graph.timeline[segmentIndex].effects.indices where !didUpdate {
                let type = graph.timeline[segmentIndex].effects[effectIndex].type
                if type.rawValue.hasPrefix("style.") || type == .outline || type == .glow {
                    graph.timeline[segmentIndex].effects[effectIndex].parameters.strength = strength
                    didUpdate = true
                }
            }
        }
        guard didUpdate else { return }
        do {
            variants[index] = try validator.validate(graph)
            states[id] = .planned
            message = "Created a new plan revision. The previous preview remains available until rerender succeeds."
            persistProject()
        } catch let failure as GraphValidationFailure {
            diagnostics = failure.diagnostics
        } catch {
            message = "Revision failed: \(error.localizedDescription)"
        }
    }

    func addEffect(_ type: EffectType, toAllVariants: Bool) {
        editGraphs(toAllVariants: toAllVariants, action: "Added \(type.displayName)") { graph in
            try graphEditor.adding(type, to: graph)
        }
    }

    func removeEffect(_ type: EffectType, fromAllVariants: Bool) {
        editGraphs(toAllVariants: fromAllVariants, action: "Removed \(type.displayName)") { graph in
            try graphEditor.removing(type, from: graph)
        }
    }

    func updateEffect(_ type: EffectType, parameter: EffectParameterKind, value: Double) {
        guard let selectedID,
              let index = variants.firstIndex(where: { $0.graph.id == selectedID })
        else { return }
        do {
            variants[index] = try graphEditor.updating(
                type: type,
                parameter: parameter,
                value: value,
                in: variants[index].graph
            )
            states[selectedID] = .planned
            diagnostics = variants.flatMap(\.warnings)
            message = "Updated \(parameter.rawValue). The previous preview is stale until rerendered."
            persistProject()
        } catch let failure as GraphValidationFailure {
            diagnostics = failure.diagnostics
            message = "That parameter value is not valid. The graph was not changed."
        } catch {
            message = "Effect update failed: \(error.localizedDescription)"
        }
    }

    func updateEffect(_ type: EffectType, parameter: EffectTextParameterKind, value: String) {
        guard let selectedID,
              let index = variants.firstIndex(where: { $0.graph.id == selectedID })
        else { return }
        do {
            variants[index] = try graphEditor.updating(type: type, parameter: parameter, value: value, in: variants[index].graph)
            states[selectedID] = .planned
            diagnostics = variants.flatMap(\.warnings)
            message = "Updated \(parameter.rawValue). The previous preview is stale until rerendered."
            persistProject()
        } catch {
            message = "Text or preset update was rejected. Enter a supported non-empty value."
        }
    }

    private func editGraphs(
        toAllVariants: Bool,
        action: String,
        transform: (EffectGraph) throws -> NormalizedGraph
    ) {
        let targetIDs = toAllVariants ? Set(variants.map { $0.graph.id }) : Set([selectedID].compactMap { $0 })
        guard !targetIDs.isEmpty else {
            message = "Select a variant before editing effects."
            return
        }
        do {
            let replacements = try variants.compactMap { variant -> (UUID, NormalizedGraph)? in
                guard targetIDs.contains(variant.graph.id) else { return nil }
                return (variant.graph.id, try transform(variant.graph))
            }
            for (id, replacement) in replacements {
                guard let index = variants.firstIndex(where: { $0.graph.id == id }) else { continue }
                variants[index] = replacement
                states[id] = .planned
            }
            diagnostics = variants.flatMap(\.warnings)
            message = "\(action) \(toAllVariants ? "to all variants" : "to the selected variant"). Previous previews are stale until rerendered."
            persistProject()
        } catch let failure as GraphValidationFailure {
            diagnostics = failure.diagnostics
            message = "Effect edit was rejected before changing any variant."
        } catch {
            message = "Effect edit failed: \(error.localizedDescription)"
        }
    }

    func exportSelected() {
        guard canExportSelected,
              let selectedID,
              let videoURL = outputURLs[selectedID],
              let selected = variants.first(where: { $0.graph.id == selectedID })
        else {
            message = "Render the current selected revision before exporting."
            return
        }
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.prompt = "Export Here"
        guard panel.runModal() == .OK, let directory = panel.url else { return }
        do {
            let videoDestination = directory.appending(path: exportStem(for: selected) + ".mp4")
            if FileManager.default.fileExists(atPath: videoDestination.path) {
                _ = try FileManager.default.replaceItemAt(videoDestination, withItemAt: videoURL)
            } else {
                try FileManager.default.copyItem(at: videoURL, to: videoDestination)
            }
            try writeComparisonSheet(to: directory)
            message = "Exported selected video and comparison sheets to \(directory.lastPathComponent)."
        } catch {
            message = "Export failed: \(error.localizedDescription)"
        }
    }

    private func exportStem(for variant: NormalizedGraph) -> String {
        let label = variant.graph.label.lowercased().replacingOccurrences(of: " ", with: "-")
        return "vertical-\(label)-\(variant.canonicalHash.prefix(8))"
    }

    private func startPlaybackMonitor() {
        playbackMonitor?.cancel()
        playbackMonitor = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(400))
                guard let self, self.isPlaying else { return }
                let samples = self.players.map { ($0.key, $0.value.currentTime().seconds) }
                    .filter { $0.1.isFinite }
                guard let reference = samples.map(\.1).min() else { continue }
                self.sharedTime = reference
                self.driftedIDs = Set(samples.filter { abs($0.1 - reference) > 0.15 }.map(\.0))
            }
        }
    }

    private func makeProjectURL(for source: SourceReference) -> URL? {
        guard let applicationSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return nil }
        let directory = applicationSupport.appending(path: "LocalVideoStudio/Projects", directoryHint: .isDirectory)
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            return directory.appending(path: "\(source.fingerprint.prefix(16)).lvstudio")
        } catch {
            message = "Project storage unavailable: \(error.localizedDescription)"
            return nil
        }
    }

    private func persistProject() {
        guard let source, let projectURL else { return }
        let revisions = variants.enumerated().map { index, variant in
            VariantRevision(
                revision: index + 1,
                graph: variant.graph,
                normalizedGraphHash: variant.canonicalHash,
                render: manifests[variant.graph.id]
            )
        }
        let project = StudioProject(
            id: projectID,
            name: source.displayName.replacingOccurrences(of: ".\((source.displayName as NSString).pathExtension)", with: ""),
            createdAt: projectCreatedAt,
            instruction: instruction,
            source: source,
            variants: revisions,
            comparison: VariantComparison(
                ratings: Dictionary(uniqueKeysWithValues: savedVariantIDs.map { ($0, 1) }),
                selectedVariantID: selectedID,
                isBlinded: isBlinded,
                sharedPlayhead: sharedTime
            )
        )
        saveTask?.cancel()
        saveTask = Task {
            try? await Task.sleep(for: .milliseconds(120))
            guard !Task.isCancelled else { return }
            do { try await projectStore.save(project, to: projectURL) }
            catch { self.message = "Project save failed: \(error.localizedDescription)" }
        }
    }

    private func writeComparisonSheet(to directory: URL) throws {
        struct Row: Codable {
            let id: UUID
            let label: String
            let summary: String
            let duration: Double
            let aspectRatio: String
            let effects: [String]
            let savedForLater: Bool
            let selected: Bool
            let hash: String
            let state: String
        }
        let rows = variants.map { variant in
            Row(
                id: variant.graph.id,
                label: variant.graph.label,
                summary: variant.graph.differenceSummary,
                duration: variant.graph.timeline.map(\.end).max() ?? 0,
                aspectRatio: variant.graph.output.aspectRatio.rawValue,
                effects: variant.graph.timeline.flatMap(\.effects).map { $0.type.rawValue },
                savedForLater: savedVariantIDs.contains(variant.graph.id),
                selected: selectedID == variant.graph.id,
                hash: variant.canonicalHash,
                state: states[variant.graph.id]?.rawValue ?? "planned"
            )
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(rows).write(to: directory.appending(path: "comparison-sheet.json"), options: .atomic)

        var markdown = "# Variant comparison\n\n| Variant | Style/effects | Duration | Ratio | Saved | Selected | State |\n|---|---|---:|---|---|---|---|\n"
        for row in rows {
            markdown += "| \(row.label) | \(row.effects.joined(separator: ", ")) | \(String(format: "%.1fs", row.duration)) | \(row.aspectRatio) | \(row.savedForLater ? "Yes" : "No") | \(row.selected ? "Yes" : "No") | \(row.state) |\n"
        }
        try Data(markdown.utf8).write(to: directory.appending(path: "comparison-sheet.md"), options: .atomic)
    }
}
