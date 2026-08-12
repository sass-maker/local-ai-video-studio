import AppKit
import AVKit
import StudioCore
import SwiftUI
import UniformTypeIdentifiers

struct StudioWorkspace: View {
    @StateObject private var model = StudioViewModel()
    @State private var showingImporter = false
    @State private var handledLaunchURL = false
    @State private var showingSourceBench = false
    @State private var confirmingSourceReplacement = false
    @State private var showingPlan = false
    @State private var showingEffects = false
    @AppStorage("studioAppearance") private var studioAppearance = StudioAppearance.dark.rawValue

    var body: some View {
        VStack(spacing: 0) {
            topBar
            Divider().overlay(StudioPalette.hairline)
            GeometryReader { proxy in
                HStack(spacing: 0) {
                    if proxy.size.width >= 980 {
                        SourceBench(model: model, requestImport: requestImport)
                            .frame(width: 268)
                        Divider().overlay(StudioPalette.hairline)
                    }
                    comparisonWorkspace(availableWidth: proxy.size.width - (proxy.size.width >= 980 ? 269 : 0))
                }
            }
            statusBar
        }
        .background(StudioPalette.canvas)
        .foregroundStyle(StudioPalette.ink)
        .preferredColorScheme(StudioAppearance(rawValue: studioAppearance)?.colorScheme)
        .fileImporter(
            isPresented: $showingImporter,
            allowedContentTypes: [.mpeg4Movie, .quickTimeMovie],
            allowsMultipleSelection: false
        ) { result in
            if case let .success(urls) = result, let url = urls.first {
                model.importVideo(url)
            }
        }
        .task {
            guard !handledLaunchURL else { return }
            handledLaunchURL = true
            if let path = ProcessInfo.processInfo.arguments.dropFirst().first(where: { !$0.hasPrefix("-") }) {
                model.importVideo(URL(filePath: path))
            }
        }
        .sheet(isPresented: $showingSourceBench) {
            SourceBench(model: model, requestImport: requestImport)
                .frame(minWidth: 320, minHeight: 620)
        }
        .confirmationDialog("Replace source and clear this comparison?", isPresented: $confirmingSourceReplacement) {
            Button("Replace Source", role: .destructive) { showingImporter = true }
            Button("Keep Current Source", role: .cancel) {}
        } message: {
            Text("Plans, previews, saved variants, and the current selection will be cleared.")
        }
        .sheet(isPresented: $showingPlan) {
            PlanInspector(planJSON: model.planJSON, plannerDescription: model.plannerDescription)
        }
        .inspector(isPresented: $showingEffects) {
            EffectInspector(model: model)
                .inspectorColumnWidth(min: 320, ideal: 380, max: 460)
        }
    }

    private var topBar: some View {
        ViewThatFits(in: .horizontal) {
            fullTopBar
            compactTopBar
            ultraCompactTopBar
        }
        .padding(.horizontal, 22)
        .frame(minHeight: 58)
        .background(StudioPalette.paper)
    }

    private var fullTopBar: some View {
        HStack(spacing: 18) {
            Text("LOCAL VIDEO STUDIO")
                .font(.headline)
            Text("Optical Printer Bench")
                .font(.subheadline)
                .foregroundStyle(StudioPalette.mutedInk)
            Spacer()
            Button {
                showingSourceBench = true
            } label: {
                Label("Source & Intent", systemImage: "sidebar.left")
            }
            Label("Local / Offline", systemImage: "checkmark.circle.fill")
                .foregroundStyle(StudioPalette.ready)
            if let estimate = model.estimate {
                Text("\(estimate.workClass.rawValue.capitalized) work · \(estimate.recommendedPreviewLongEdge)p edge")
                    .font(.caption.monospaced())
                    .foregroundStyle(StudioPalette.mutedInk)
            }
            if let disk = model.diskPreflight, !disk.canStart {
                Label("Needs \(ByteCountFormatter.string(fromByteCount: disk.additionalBytesRequired, countStyle: .file)) more", systemImage: "externaldrive.badge.exclamationmark")
                    .font(.caption)
                    .foregroundStyle(StudioPalette.warning)
            }
            appearanceMenu
            Button("Effects") { showingEffects = true }
                .disabled(model.variants.isEmpty)
                .keyboardShortcut("e", modifiers: [.command, .shift])
            Button("View Plan") { showingPlan = true }
                .disabled(model.variants.isEmpty)
            Button {
                model.toggleBlinded()
            } label: {
                Label(model.isBlinded ? "Reveal Labels" : "Blind Labels", systemImage: model.isBlinded ? "eye" : "eye.slash")
            }
            .keyboardShortcut("b", modifiers: [.command])
            Button("Export Selected", action: model.exportSelected)
                .buttonStyle(PrinterPrimaryButtonStyle())
                .keyboardShortcut("e", modifiers: [.command])
                .disabled(!model.canExportSelected)
        }
    }

    private var compactTopBar: some View {
        HStack(spacing: 10) {
            Text("LOCAL VIDEO STUDIO").font(.headline)
            Spacer()
            Button { showingSourceBench = true } label: {
                Image(systemName: "sidebar.left")
            }
            .accessibilityLabel("Source and intent")
            Button { model.toggleBlinded() } label: {
                Image(systemName: model.isBlinded ? "eye" : "eye.slash")
            }
            .accessibilityLabel(model.isBlinded ? "Reveal labels" : "Blind labels")
            appearanceMenu
            Button { showingEffects = true } label: { Image(systemName: "slider.horizontal.3") }
                .accessibilityLabel("Edit effects")
                .disabled(model.variants.isEmpty)
                .keyboardShortcut("e", modifiers: [.command, .shift])
            Button { showingPlan = true } label: { Image(systemName: "doc.text.magnifyingglass") }
                .accessibilityLabel("View generated effect plan")
                .disabled(model.variants.isEmpty)
            Button("Export", action: model.exportSelected)
                .buttonStyle(PrinterPrimaryButtonStyle())
                .disabled(!model.canExportSelected)
        }
    }

    private var ultraCompactTopBar: some View {
        HStack(spacing: 8) {
            Text("LVS")
                .font(.headline.monospaced())
                .accessibilityLabel("Local Video Studio")
            Spacer(minLength: 4)
            Button { showingSourceBench = true } label: {
                Image(systemName: "sidebar.left")
            }
            .accessibilityLabel("Source and intent")
            Button { model.toggleBlinded() } label: {
                Image(systemName: model.isBlinded ? "eye" : "eye.slash")
            }
            .accessibilityLabel(model.isBlinded ? "Reveal labels" : "Blind labels")
            .keyboardShortcut("b", modifiers: [.command])
            appearanceMenu
            Button { showingEffects = true } label: {
                Image(systemName: "slider.horizontal.3")
            }
            .accessibilityLabel("Edit effects")
            .disabled(model.variants.isEmpty)
            .keyboardShortcut("e", modifiers: [.command, .shift])
            Button { showingPlan = true } label: {
                Image(systemName: "doc.text.magnifyingglass")
            }
            .accessibilityLabel("View generated effect plan")
            .disabled(model.variants.isEmpty)
            Button(action: model.exportSelected) {
                Image(systemName: "square.and.arrow.up")
            }
            .accessibilityLabel("Export selected")
            .disabled(!model.canExportSelected)
        }
    }

    private var appearanceMenu: some View {
        Menu {
            ForEach(StudioAppearance.allCases) { appearance in
                Button {
                    studioAppearance = appearance.rawValue
                } label: {
                    Label(appearance.label, systemImage: appearance == selectedAppearance ? "checkmark" : appearance.symbol)
                }
            }
        } label: {
            Image(systemName: selectedAppearance.symbol)
        }
        .menuStyle(.borderlessButton)
        .accessibilityLabel("Appearance: \(selectedAppearance.label)")
    }

    private var selectedAppearance: StudioAppearance {
        StudioAppearance(rawValue: studioAppearance) ?? .dark
    }

    private func comparisonWorkspace(availableWidth: CGFloat) -> some View {
        VStack(spacing: 0) {
            if model.variants.isEmpty {
                if let source = model.source, let player = model.sourcePlayer {
                    SourceReadyView(
                        player: player,
                        sourceName: source.displayName,
                        isBusy: model.isBusy,
                        status: model.message,
                        variantCount: model.variantCount,
                        onPlan: { model.planVariants() },
                        onCreate: model.createPreviews
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    EmptyComparisonView(onImport: requestImport)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            } else if availableWidth < 780 {
                narrowComparison(availableWidth: availableWidth)
            } else {
                ScrollView(.horizontal) {
                    HStack(alignment: .top, spacing: 12) {
                        ForEach(Array(model.variants.enumerated()), id: \.element.graph.id) { index, variant in
                            VariantStudy(
                                index: index,
                                variant: variant,
                                state: model.states[variant.graph.id] ?? .planned,
                                player: model.players[variant.graph.id],
                                isBlinded: model.isBlinded,
                                isSelected: model.selectedID == variant.graph.id,
                                isDrifted: model.driftedIDs.contains(variant.graph.id),
                                isSaved: model.savedVariantIDs.contains(variant.graph.id),
                                manifest: model.manifests[variant.graph.id],
                                onSelect: { model.select(variant.graph.id) },
                                onToggleSaved: { model.toggleSaved(variant.graph.id) },
                                onStrength: { model.reviseStrength(for: variant.graph.id, strength: $0) },
                                onRerender: model.renderVariants
                            )
                            .frame(width: studyWidth(availableWidth: availableWidth))
                        }
                    }
                    .padding(18)
                }
                DifferenceStrip(variants: model.variants, playhead: model.sharedTime, blinded: model.isBlinded)
                    .frame(height: 230)
                PlaybackRail(model: model)
            }
        }
    }

    private func narrowComparison(availableWidth: CGFloat) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                ForEach(Array(model.variants.enumerated()), id: \.element.graph.id) { index, variant in
                    Button("\(index + 1)") { model.select(variant.graph.id) }
                        .buttonStyle(.bordered)
                        .tint(variant.graph.id == model.selectedID ? StudioPalette.probe : StudioPalette.mutedInk)
                        .accessibilityLabel("Show study \(index + 1)")
                }
                Spacer()
                Text("ONE-STUDY REVIEW").font(.caption.weight(.bold)).foregroundStyle(StudioPalette.mutedInk)
            }
            .padding(.horizontal, 18)
            .padding(.top, 12)
            if let index = model.variants.firstIndex(where: { $0.graph.id == model.selectedID }) ?? model.variants.indices.first {
                let variant = model.variants[index]
                ScrollView {
                    VariantStudy(
                        index: index,
                        variant: variant,
                        state: model.states[variant.graph.id] ?? .planned,
                        player: model.players[variant.graph.id],
                        isBlinded: model.isBlinded,
                        isSelected: true,
                        isDrifted: model.driftedIDs.contains(variant.graph.id),
                        isSaved: model.savedVariantIDs.contains(variant.graph.id),
                        manifest: model.manifests[variant.graph.id],
                        onSelect: { model.select(variant.graph.id) },
                        onToggleSaved: { model.toggleSaved(variant.graph.id) },
                        onStrength: { model.reviseStrength(for: variant.graph.id, strength: $0) },
                        onRerender: model.renderVariants
                    )
                    .frame(maxWidth: min(420, availableWidth - 36))
                    .padding(18)
                }
            }
            PlaybackRail(model: model)
        }
    }

    private func studyWidth(availableWidth: CGFloat) -> CGFloat {
        let count = CGFloat(max(model.variants.count, 1))
        return max(280, (availableWidth - 36 - (count - 1) * 12) / count)
    }

    private func requestImport() {
        if model.variants.isEmpty {
            showingImporter = true
        } else {
            confirmingSourceReplacement = true
        }
    }

    private var statusBar: some View {
        HStack(spacing: 10) {
            if model.isBusy { ProgressView().controlSize(.small) }
            Text(model.message)
                .font(.caption)
                .lineLimit(2)
                .accessibilityLabel("Status: \(model.message)")
            Spacer()
            if let source = model.source {
                Text("\(source.metadata.width)×\(source.metadata.height) · \(String(format: "%.2f", source.metadata.fps)) FPS · \(source.metadata.codec)")
                    .font(.caption.monospaced())
                    .foregroundStyle(StudioPalette.mutedInk)
            }
        }
        .padding(.horizontal, 18)
        .frame(height: 34)
        .background(StudioPalette.paper)
        .overlay(alignment: .top) { Divider().overlay(StudioPalette.hairline) }
    }
}

private struct EffectInspector: View {
    @ObservedObject var model: StudioViewModel
    @State private var applyToAll = false
    @Environment(\.dismiss) private var dismiss

    private var selectedVariant: NormalizedGraph? {
        model.variants.first(where: { $0.graph.id == model.selectedID })
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("WHOLE-STUDY EFFECTS").font(.headline)
                    Text(selectedStudyLabel)
                        .font(.caption)
                        .foregroundStyle(StudioPalette.mutedInk)
                }
                Spacer()
                Toggle("Add/remove in all studies", isOn: $applyToAll)
                    .toggleStyle(.switch)
                    .accessibilityHint("Parameter sliders continue to tune the selected study only")
                Button("Done") { dismiss() }.keyboardShortcut(.defaultAction)
            }
            .padding(18)
            .background(StudioPalette.paper)
            Divider().overlay(StudioPalette.hairline)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 20) {
                    ForEach(EffectCategory.allCases, id: \.self) { category in
                        let definitions = model.effectCatalog.filter { $0.category == category }
                        if !definitions.isEmpty {
                            VStack(alignment: .leading, spacing: 9) {
                                Text(category.rawValue.uppercased())
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(StudioPalette.mutedInk)
                                ForEach(definitions, id: \.type) { definition in
                                    EffectCatalogRow(
                                        definition: definition,
                                        appliedNode: selectedEffect(definition.type),
                                        applyToAll: applyToAll,
                                        onAdd: { model.addEffect(definition.type, toAllVariants: applyToAll) },
                                        onRemove: { model.removeEffect(definition.type, fromAllVariants: applyToAll) },
                                        onParameter: { type, parameter, value in
                                            model.updateEffect(type, parameter: parameter, value: value)
                                        },
                                        onTextParameter: { type, parameter, value in
                                            model.updateEffect(type, parameter: parameter, value: value)
                                        }
                                    )
                                }
                            }
                        }
                    }
                }
                .padding(18)
            }
            Divider().overlay(StudioPalette.hairline)
            HStack(spacing: 12) {
                Text(model.message)
                    .font(.caption)
                    .foregroundStyle(StudioPalette.mutedInk)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityLabel("Effect edit status: \(model.message)")
                Button("Rerender Changed Studies", action: model.renderChangedVariants)
                    .buttonStyle(PrinterPrimaryButtonStyle())
                    .disabled(model.isBusy || !model.states.values.contains(.planned))
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(StudioPalette.paper)
        }
        .frame(minWidth: 300, minHeight: 480)
        .background(StudioPalette.canvas)
    }

    private func selectedEffect(_ type: EffectType) -> EffectNode? {
        selectedVariant?.graph.timeline.flatMap(\.effects).first(where: { $0.type == type })
    }

    private var selectedStudyLabel: String {
        guard let selectedID = model.selectedID,
              let index = model.variants.firstIndex(where: { $0.graph.id == selectedID })
        else { return "Select a study to edit" }
        return model.isBlinded
            ? "Editing Study \(index + 1)"
            : "Editing \(model.variants[index].graph.label)"
    }
}

private struct EffectCatalogRow: View {
    let definition: EffectDefinition
    let appliedNode: EffectNode?
    let applyToAll: Bool
    let onAdd: () -> Void
    let onRemove: () -> Void
    let onParameter: (EffectType, EffectParameterKind, Double) -> Void
    let onTextParameter: (EffectType, EffectTextParameterKind, String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(definition.displayName).font(.subheadline.weight(.semibold))
                    Text("\(definition.cost.label) cost · \(definition.readiness.label)")
                        .font(.caption2.monospaced())
                        .foregroundStyle(readinessColor)
                }
                Spacer()
                if appliedNode == nil {
                    Button("Add", action: onAdd)
                        .buttonStyle(.borderedProminent)
                        .tint(StudioPalette.probe)
                        .accessibilityLabel("Add \(definition.displayName)")
                        .accessibilityHint(applyToAll ? "Applies to every variant" : "Applies to the selected variant")
                } else {
                    Button("Remove", action: onRemove)
                        .buttonStyle(.bordered)
                        .tint(StudioPalette.mutedInk)
                        .accessibilityLabel("Remove \(definition.displayName)")
                        .accessibilityHint(applyToAll ? "Removes from every variant" : "Removes from the selected variant")
                }
            }
            if let fallbackReason = definition.fallbackReason {
                Label(fallbackReason, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(StudioPalette.warning)
                    .fixedSize(horizontal: false, vertical: true)
            } else if definition.readiness == .approximation {
                Text("Fast local approximation; the exact graph records this treatment.")
                    .font(.caption)
                    .foregroundStyle(StudioPalette.mutedInk)
            } else if definition.parameters.isEmpty {
                Text("Uses the registered local preset; no numeric tuning is available.")
                    .font(.caption)
                    .foregroundStyle(StudioPalette.mutedInk)
            }
            if let appliedNode {
                ForEach(definition.parameters, id: \.kind) { descriptor in
                    EffectParameterControl(
                        descriptor: descriptor,
                        effectName: definition.displayName,
                        value: parameterValue(descriptor.kind, from: appliedNode.parameters) ?? descriptor.defaultValue,
                        onCommit: { onParameter(definition.type, descriptor.kind, $0) }
                    )
                    .id("\(appliedNode.id)-\(descriptor.kind.rawValue)")
                }
                ForEach(definition.textParameters, id: \.kind) { descriptor in
                    EffectTextParameterControl(
                        descriptor: descriptor,
                        effectName: definition.displayName,
                        value: textParameterValue(descriptor.kind, from: appliedNode.parameters) ?? descriptor.defaultValue,
                        onCommit: { onTextParameter(definition.type, descriptor.kind, $0) }
                    )
                    .id("\(appliedNode.id)-text-\(descriptor.kind.rawValue)")
                }
            }
        }
        .padding(12)
        .background(StudioPalette.study)
        .overlay(RoundedRectangle(cornerRadius: 5).stroke(StudioPalette.hairline))
    }

    private var readinessColor: Color {
        definition.readiness == .ready ? StudioPalette.ready : StudioPalette.warning
    }

    private func parameterValue(_ kind: EffectParameterKind, from parameters: EffectParameters) -> Double? {
        switch kind {
        case .strength: parameters.strength
        case .intensity: parameters.intensity
        case .rate: parameters.rate
        case .duration: parameters.duration
        }
    }

    private func textParameterValue(_ kind: EffectTextParameterKind, from parameters: EffectParameters) -> String? {
        switch kind {
        case .target: parameters.target
        case .preset: parameters.preset
        case .text: parameters.text
        }
    }
}

private struct EffectTextParameterControl: View {
    let descriptor: EffectTextParameterDescriptor
    let effectName: String
    @State private var draft: String
    let onCommit: (String) -> Void

    init(descriptor: EffectTextParameterDescriptor, effectName: String, value: String, onCommit: @escaping (String) -> Void) {
        self.descriptor = descriptor
        self.effectName = effectName
        _draft = State(initialValue: value)
        self.onCommit = onCommit
    }

    var body: some View {
        HStack {
            Text(descriptor.kind.rawValue.capitalized).font(.caption)
            if descriptor.options.isEmpty {
                TextField(descriptor.defaultValue, text: $draft)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { onCommit(draft) }
                    .accessibilityLabel("\(effectName) \(descriptor.kind.rawValue)")
            } else {
                Picker(descriptor.kind.rawValue.capitalized, selection: $draft) {
                    ForEach(descriptor.options, id: \.self) { option in
                        Text(option.replacingOccurrences(of: "_", with: " ").capitalized).tag(option)
                    }
                }
                .labelsHidden()
                .onChange(of: draft) { _, value in onCommit(value) }
                .accessibilityLabel("\(effectName) \(descriptor.kind.rawValue)")
            }
        }
    }
}

private struct EffectParameterControl: View {
    let descriptor: EffectParameterDescriptor
    let effectName: String
    @State private var draft: Double
    let onCommit: (Double) -> Void

    init(descriptor: EffectParameterDescriptor, effectName: String, value: Double, onCommit: @escaping (Double) -> Void) {
        self.descriptor = descriptor
        self.effectName = effectName
        _draft = State(initialValue: value)
        self.onCommit = onCommit
    }

    var body: some View {
        HStack {
            Text(descriptor.kind.rawValue.capitalized).font(.caption)
            Slider(value: $draft, in: descriptor.rule.minimum...descriptor.rule.maximum, step: step) { editing in
                if !editing { onCommit(draft) }
            }
            .accessibilityLabel("\(effectName) \(descriptor.kind.rawValue)")
            .accessibilityValue(formattedValue)
            Text(formattedValue).font(.caption.monospaced()).frame(width: 42, alignment: .trailing)
        }
    }

    private var step: Double {
        switch descriptor.kind { case .strength, .intensity: 0.01; case .rate, .duration: 0.05 }
    }

    private var formattedValue: String {
        switch descriptor.kind {
        case .strength, .intensity: "\(Int((draft * 100).rounded()))%"
        case .rate: String(format: "%.2f×", draft)
        case .duration: String(format: "%.2fs", draft)
        }
    }
}

private extension EffectCost {
    var label: String {
        switch self { case .light: "Light"; case .medium: "Medium"; case .heavy: "Heavy" }
    }
}

private extension EffectReadiness {
    var label: String {
        switch self { case .ready: "Ready"; case .approximation: "Approximation"; case .fallback: "Fallback" }
    }
}

private enum StudioAppearance: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }
    var label: String { rawValue.capitalized }
    var symbol: String {
        switch self {
        case .system: "circle.lefthalf.filled"
        case .light: "sun.max"
        case .dark: "moon.stars"
        }
    }
    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

private struct SourceBench: View {
    @ObservedObject var model: StudioViewModel
    let requestImport: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("SOURCE & INTENT").font(.subheadline.weight(.bold))
            Label(model.plannerAvailabilityDescription, systemImage: "apple.intelligence")
                .font(.caption)
                .foregroundStyle(StudioPalette.ready)
                .fixedSize(horizontal: false, vertical: true)
            if let source = model.source {
                VStack(alignment: .leading, spacing: 7) {
                    Label(source.displayName, systemImage: "film")
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(2)
                    Text("\(time(source.metadata.duration))  ·  \(source.metadata.width)×\(source.metadata.height)")
                        .font(.caption.monospaced())
                        .foregroundStyle(StudioPalette.mutedInk)
                }
            } else {
                Text("No source selected")
                    .foregroundStyle(StudioPalette.mutedInk)
            }
            Button(action: requestImport) {
                Label(model.source == nil ? "Import Video" : "Replace Source", systemImage: "square.and.arrow.down")
            }
            .buttonStyle(PrinterSecondaryButtonStyle())

            Divider().overlay(StudioPalette.hairline)
            Text("EDIT INSTRUCTION").font(.caption.weight(.semibold)).foregroundStyle(StudioPalette.mutedInk)
            TextEditor(text: $model.instruction)
                .font(.body)
                .scrollContentBackground(.hidden)
                .padding(8)
                .frame(height: 160)
                .background(StudioPalette.study)
                .overlay(RoundedRectangle(cornerRadius: 5).stroke(StudioPalette.hairline))
            Stepper("\(model.variantCount) variants", value: $model.variantCount, in: 2...5)
                .font(.caption)
            Button("Plan \(model.variantCount) Variants") { model.planVariants() }
                .buttonStyle(PrinterPrimaryButtonStyle())
                .disabled(model.source == nil || model.isBusy)
                .keyboardShortcut("p", modifiers: [.command])
            Button("Plan & Render Previews", action: model.createPreviews)
                .buttonStyle(PrinterSecondaryButtonStyle())
                .disabled(model.source == nil || model.isBusy)
                .keyboardShortcut("r", modifiers: [.command, .shift])
            if model.isRendering {
                Button("Cancel Render", action: model.cancelRendering)
                    .buttonStyle(PrinterSecondaryButtonStyle())
            }

            if !model.diagnostics.isEmpty {
                Divider().overlay(StudioPalette.hairline)
                Text("PLAN NOTES").font(.caption.weight(.semibold)).foregroundStyle(StudioPalette.mutedInk)
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(model.diagnostics.enumerated()), id: \.offset) { _, item in
                            Label(item.message, systemImage: item.severity == .error ? "xmark.octagon" : "exclamationmark.triangle")
                                .font(.caption)
                                .foregroundStyle(item.severity == .error ? Color.red : StudioPalette.warning)
                        }
                    }
                }
            }
            Spacer()
        }
        .padding(18)
        .background(StudioPalette.secondaryStock)
    }

    private func time(_ seconds: Double) -> String {
        String(format: "%02d:%02d", Int(seconds) / 60, Int(seconds) % 60)
    }
}

private struct VariantStudy: View {
    let index: Int
    let variant: NormalizedGraph
    let state: RenderState
    let player: AVPlayer?
    let isBlinded: Bool
    let isSelected: Bool
    let isDrifted: Bool
    let isSaved: Bool
    let manifest: RenderManifest?
    let onSelect: () -> Void
    let onToggleSaved: () -> Void
    let onStrength: (Double) -> Void
    let onRerender: () -> Void

    private var styleStrength: Double {
        variant.graph.timeline.flatMap(\.effects).compactMap(\.parameters.strength).first ?? 0.5
    }

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                StudioPalette.ink
                if let player {
                    VideoPlayer(player: player)
                } else {
                    VStack(spacing: 10) {
                        Image(systemName: state == .rendering ? "gearshape.2" : "film.stack")
                            .font(.system(size: 30, weight: .light))
                        Text(state == .rendering ? "Rendering locally…" : "Draft not rendered")
                            .font(.caption)
                    }
                    .foregroundStyle(StudioPalette.paper)
                }
            }
            .aspectRatio(9 / 16, contentMode: .fit)
            .frame(maxHeight: 455)

            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    Text(isBlinded ? "STUDY \(index + 1)" : variant.graph.label.uppercased())
                        .font(.subheadline.weight(.bold))
                    Spacer()
                    StateLabel(state: state)
                }
                if isDrifted {
                    Label("Sync drift", systemImage: "clock.badge.exclamationmark")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(StudioPalette.warning)
                }
                if state == .planned, player != nil {
                    Label("Preview is from the prior revision", systemImage: "arrow.triangle.2.circlepath")
                        .font(.caption)
                        .foregroundStyle(StudioPalette.warning)
                }
                if let degradations = manifest?.degradations, !degradations.isEmpty, state == .degraded {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("USABLE WITH FALLBACK").font(.caption2.weight(.bold))
                        ForEach(Array(degradations.enumerated()), id: \.offset) { _, fallback in
                            Text("\(fallback.effectType.rawValue): \(fallback.reason)").font(.caption)
                        }
                        Button("Rerender Batch", action: onRerender)
                            .font(.caption.weight(.semibold))
                            .buttonStyle(.plain)
                    }
                    .foregroundStyle(StudioPalette.warning)
                    .accessibilityElement(children: .combine)
                }
                Text(isBlinded ? "Labels hidden until reveal." : variant.graph.differenceSummary)
                    .font(.caption)
                    .foregroundStyle(StudioPalette.mutedInk)
                    .frame(minHeight: 32, alignment: .topLeading)
                HStack {
                    Text("9:16 · \(Int(variant.graph.timeline.map(\.end).max() ?? 0))s")
                    Spacer()
                    Text(variant.canonicalHash.prefix(8))
                }
                .font(.caption2.monospaced())
                .foregroundStyle(StudioPalette.mutedInk)

                if variant.graph.timeline.flatMap(\.effects).contains(where: { $0.parameters.strength != nil }) {
                    StrengthControl(value: styleStrength, onCommit: onStrength)
                }
                HStack {
                    Button(isSelected ? "Selected" : "Select", action: onSelect)
                        .buttonStyle(PrinterSecondaryButtonStyle())
                        .accessibilityValue(isSelected ? "Selected" : "Not selected")
                    Spacer()
                    Button(action: onToggleSaved) {
                        Label(isSaved ? "Saved for Later" : "Save for Later", systemImage: isSaved ? "bookmark.fill" : "bookmark")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(isSaved ? StudioPalette.ready : StudioPalette.mutedInk)
                }
            }
            .padding(14)
            .background(StudioPalette.study)
        }
        .overlay(Rectangle().stroke(isSelected ? StudioPalette.probe : StudioPalette.hairline, lineWidth: isSelected ? 2 : 1))
        .accessibilityElement(children: .contain)
        .accessibilityLabel(isBlinded ? "Study \(index + 1)" : variant.graph.label)
    }
}

private struct PlanInspector: View {
    let planJSON: String
    let plannerDescription: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Generated Effect Plan").font(.title2.weight(.semibold))
                    Text("Planner: \(plannerDescription)")
                        .font(.subheadline)
                        .foregroundStyle(StudioPalette.mutedInk)
                }
                Spacer()
                Button("Done") { dismiss() }.keyboardShortcut(.defaultAction)
            }
            Text("This is the exact validated graph produced from your instruction and compiled into local filters.")
                .font(.body)
            ScrollView([.vertical, .horizontal]) {
                Text(planJSON)
                    .font(.body.monospaced())
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .padding(16)
            }
            .background(StudioPalette.canvas)
            .overlay(Rectangle().stroke(StudioPalette.hairline))
        }
        .padding(24)
        .frame(minWidth: 760, minHeight: 620)
        .background(StudioPalette.paper)
    }
}

private struct StrengthControl: View {
    @State private var draft: Double
    let onCommit: (Double) -> Void

    init(value: Double, onCommit: @escaping (Double) -> Void) {
        _draft = State(initialValue: value)
        self.onCommit = onCommit
    }

    var body: some View {
        HStack {
            Text("Strength").font(.caption)
            Slider(value: $draft, in: 0...1) { editing in
                if !editing { onCommit(draft) }
            }
            .accessibilityLabel("Effect strength")
            .accessibilityValue("\(Int(draft * 100)) percent")
        }
    }
}

private struct StateLabel: View {
    let state: RenderState
    var body: some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(state.rawValue.capitalized)
        }
        .font(.caption2.monospaced())
        .foregroundStyle(color)
    }
    private var color: Color {
        switch state {
        case .completed: StudioPalette.ready
        case .degraded: StudioPalette.warning
        case .failed, .cancelled: .red
        default: StudioPalette.mutedInk
        }
    }
}

private struct DifferenceStrip: View {
    let variants: [NormalizedGraph]
    let playhead: Double
    let blinded: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("DIFFERENCE REPORT AT SHARED PROBE")
                    .font(.caption.weight(.bold))
                Text(timecode(playhead)).font(.caption.monospaced())
                Spacer()
                Text("Exact normalized graph parameters")
                    .font(.caption2)
                    .foregroundStyle(StudioPalette.mutedInk)
            }
            HStack(alignment: .top, spacing: 0) {
                ForEach(Array(variants.enumerated()), id: \.element.graph.id) { index, variant in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(blinded ? "STUDY \(index + 1)" : variant.graph.label.uppercased())
                            .font(.caption.weight(.bold))
                        ForEach(Array(variant.graph.timeline.flatMap(\.effects).prefix(4)), id: \.id) { effect in
                            Text(effectLine(effect))
                                .font(.caption2.monospaced())
                                .lineLimit(1)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    if index < variants.count - 1 { Divider().overlay(StudioPalette.hairline) }
                }
            }
        }
        .padding(14)
        .background(StudioPalette.paper)
        .overlay(alignment: .top) { Rectangle().fill(StudioPalette.probe).frame(height: 3) }
        .overlay(Rectangle().stroke(StudioPalette.hairline))
        .padding(.horizontal, 18)
    }

    private func effectLine(_ effect: EffectNode) -> String {
        let value = effect.parameters.strength ?? effect.parameters.intensity
        return value.map { "\(effect.type.rawValue)  \(String(format: "%.2f", $0))" } ?? effect.type.rawValue
    }

    private func timecode(_ seconds: Double) -> String {
        String(format: "%02d:%02d:%02d", Int(seconds) / 3600, (Int(seconds) / 60) % 60, Int(seconds) % 60)
    }
}

private struct PlaybackRail: View {
    @ObservedObject var model: StudioViewModel
    var body: some View {
        HStack(spacing: 14) {
            Button(action: model.restartPlayback) {
                Image(systemName: "backward.end.fill")
            }
            .buttonStyle(PrinterSecondaryButtonStyle())
            .accessibilityLabel("Restart all variants")
            Button(action: model.togglePlayback) {
                Image(systemName: model.isPlaying ? "pause.fill" : "play.fill")
            }
            .buttonStyle(PrinterPrimaryButtonStyle())
            .keyboardShortcut(.space, modifiers: [])
            .accessibilityLabel(model.isPlaying ? "Pause all variants" : "Play all variants")
            Text(timecode(model.sharedTime)).font(.caption.monospaced())
            Slider(value: Binding(get: { model.sharedTime }, set: model.seekAll), in: 0...max(model.duration, 0.01))
                .tint(StudioPalette.probe)
                .accessibilityLabel("Shared playhead")
                .accessibilityValue(timecode(model.sharedTime))
            Text(timecode(model.duration)).font(.caption.monospaced())
        }
        .padding(18)
        .background(StudioPalette.canvas)
    }

    private func timecode(_ seconds: Double) -> String {
        String(format: "%02d:%02d", Int(seconds) / 60, Int(seconds) % 60)
    }
}

private struct SourceReadyView: View {
    let player: AVPlayer
    let sourceName: String
    let isBusy: Bool
    let status: String
    let variantCount: Int
    let onPlan: () -> Void
    let onCreate: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            VideoPlayer(player: player)
                .aspectRatio(16 / 9, contentMode: .fit)
                .frame(maxWidth: 860, maxHeight: 520)
                .background(.black)
            VStack(spacing: 8) {
                Label("Video loaded", systemImage: "checkmark.circle.fill")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(StudioPalette.ready)
                Text(sourceName).font(.subheadline).foregroundStyle(StudioPalette.mutedInk)
                Button(isBusy ? "Working…" : "Plan \(variantCount) Variants", action: onPlan)
                    .buttonStyle(PrinterPrimaryButtonStyle())
                    .disabled(isBusy)
                    .keyboardShortcut("p", modifiers: [.command])
                Button("Plan & Render Previews", action: onCreate)
                    .buttonStyle(PrinterSecondaryButtonStyle())
                    .disabled(isBusy)
                    .keyboardShortcut("r", modifiers: [.command, .shift])
                if isBusy { ProgressView(status).controlSize(.small) }
            }
        }
        .padding(24)
    }
}

private struct EmptyComparisonView: View {
    let onImport: () -> Void
    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "film")
                .font(.system(size: 38, weight: .light))
            Text("Start with one video")
                .font(.title3.weight(.semibold))
            Text("Import an MP4 or MOV. You’ll see it here immediately.")
                .foregroundStyle(StudioPalette.mutedInk)
            Button("Choose Video…", action: onImport)
                .buttonStyle(PrinterPrimaryButtonStyle())
        }
    }
}

private enum StudioPalette {
    static let canvas = adaptive(light: NSColor(red: 0.91, green: 0.90, blue: 0.86, alpha: 1), dark: NSColor(red: 0.018, green: 0.022, blue: 0.022, alpha: 1))
    static let secondaryStock = adaptive(light: NSColor(red: 0.84, green: 0.82, blue: 0.77, alpha: 1), dark: NSColor(red: 0.035, green: 0.043, blue: 0.043, alpha: 1))
    static let paper = adaptive(light: NSColor(red: 0.96, green: 0.95, blue: 0.91, alpha: 1), dark: NSColor(red: 0.055, green: 0.065, blue: 0.065, alpha: 1))
    static let study = adaptive(light: NSColor(red: 0.95, green: 0.94, blue: 0.90, alpha: 1), dark: NSColor(red: 0.028, green: 0.035, blue: 0.035, alpha: 1))
    static let ink = adaptive(light: NSColor(red: 0.12, green: 0.15, blue: 0.16, alpha: 1), dark: NSColor(red: 0.91, green: 0.90, blue: 0.86, alpha: 1))
    static let mutedInk = adaptive(light: NSColor(red: 0.35, green: 0.38, blue: 0.38, alpha: 1), dark: NSColor(red: 0.68, green: 0.69, blue: 0.67, alpha: 1))
    static let hairline = adaptive(light: NSColor(red: 0.55, green: 0.53, blue: 0.50, alpha: 1), dark: NSColor(red: 0.18, green: 0.20, blue: 0.20, alpha: 1))
    static let probe = adaptive(light: NSColor(red: 0.58, green: 0.25, blue: 0.16, alpha: 1), dark: NSColor(red: 0.95, green: 0.60, blue: 0.45, alpha: 1))
    static let ready = adaptive(light: NSColor(red: 0.12, green: 0.40, blue: 0.36, alpha: 1), dark: NSColor(red: 0.42, green: 0.82, blue: 0.75, alpha: 1))
    static let warning = adaptive(light: NSColor(red: 0.49, green: 0.27, blue: 0.05, alpha: 1), dark: NSColor(red: 0.96, green: 0.70, blue: 0.36, alpha: 1))

    private static func adaptive(light: NSColor, dark: NSColor) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
        })
    }
}

private struct PrinterPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold))
            .padding(.horizontal, 14)
            .frame(minHeight: 34)
            .foregroundStyle(StudioPalette.paper)
            .background(configuration.isPressed ? StudioPalette.probe : StudioPalette.ink)
            .clipShape(RoundedRectangle(cornerRadius: 5))
    }
}

private struct PrinterSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .medium))
            .padding(.horizontal, 12)
            .frame(minHeight: 32)
            .foregroundStyle(StudioPalette.ink)
            .background(configuration.isPressed ? StudioPalette.secondaryStock : StudioPalette.paper)
            .overlay(RoundedRectangle(cornerRadius: 5).stroke(StudioPalette.hairline))
            .clipShape(RoundedRectangle(cornerRadius: 5))
    }
}
