import CoreImage
import Foundation
import StudioCore

public enum FilterRecipe: String, Equatable, Sendable {
    case anime
    case comic
    case sketch
    case watercolor
    case cel
    case cinematic
    case noir
    case vhs
    case colorGrade
    case backgroundBlur
    case outline
    case glow
    case beatFlash
    case beatZoom
}

public enum CompiledOperation: Equatable, Sendable {
    case cropAutoSubject(target: String)
    case resize
    case trim
    case speed(rate: Double)
    case caption(text: String?, preset: String?)
    case title(text: String)
    case transition(duration: Double)
    case filter(FilterRecipe, strength: Double)
    case backgroundReplacement(preset: String)
    case audioNormalize
}

public struct CompiledSegment: Equatable, Sendable {
    public let start: Double
    public let end: Double
    public let operations: [CompiledOperation]
}

public struct CompiledPipeline: Equatable, Sendable {
    public let variantID: UUID
    public let graphHash: String
    public let output: OutputProfile
    public let segments: [CompiledSegment]
}

public enum CompilationError: Error, Equatable, Sendable {
    case unregisteredEffect(EffectType)
    case missingRequiredParameter(effect: EffectType, parameter: String)
}

public struct GraphCompiler: Sendable {
    public let registry: EffectRegistry

    public init(registry: EffectRegistry = .standard) {
        self.registry = registry
    }

    public func compile(_ normalized: NormalizedGraph) throws -> CompiledPipeline {
        let segments = try normalized.graph.timeline.map { segment in
            CompiledSegment(
                start: segment.start,
                end: segment.end,
                operations: try segment.effects.map(compile)
            )
        }
        return CompiledPipeline(
            variantID: normalized.graph.id,
            graphHash: normalized.canonicalHash,
            output: normalized.graph.output,
            segments: segments
        )
    }

    private func compile(_ node: EffectNode) throws -> CompiledOperation {
        guard registry[node.type] != nil else { throw CompilationError.unregisteredEffect(node.type) }
        let parameters = node.parameters
        switch node.type {
        case .cropAutoSubject:
            return .cropAutoSubject(target: parameters.target ?? "primary_person")
        case .resize:
            return .resize
        case .trim:
            return .trim
        case .speed:
            return .speed(rate: parameters.rate ?? 1)
        case .captionDynamic:
            return .caption(text: parameters.text, preset: parameters.preset)
        case .titleCard:
            guard let text = parameters.text, !text.isEmpty else {
                throw CompilationError.missingRequiredParameter(effect: node.type, parameter: "text")
            }
            return .title(text: text)
        case .transitionCrossfade:
            return .transition(duration: parameters.duration ?? 0.2)
        case .audioNormalize:
            return .audioNormalize
        case .backgroundReplace:
            return .backgroundReplacement(preset: parameters.preset ?? "soft_gradient")
        case .backgroundBlur:
            return .filter(.backgroundBlur, strength: parameters.strength ?? 0.5)
        case .outline:
            return .filter(.outline, strength: parameters.strength ?? 0.5)
        case .glow:
            return .filter(.glow, strength: parameters.strength ?? 0.5)
        case .beatFlash:
            return .filter(.beatFlash, strength: parameters.intensity ?? 0.35)
        case .beatZoom:
            return .filter(.beatZoom, strength: parameters.intensity ?? 0.25)
        case .colorGrade:
            return .filter(.colorGrade, strength: parameters.intensity ?? 0.5)
        case .styleAnime:
            return .filter(.anime, strength: parameters.strength ?? 0.7)
        case .styleComic:
            return .filter(.comic, strength: parameters.strength ?? 0.7)
        case .styleSketch:
            return .filter(.sketch, strength: parameters.strength ?? 0.7)
        case .styleWatercolor:
            return .filter(.watercolor, strength: parameters.strength ?? 0.7)
        case .styleCel:
            return .filter(.cel, strength: parameters.strength ?? 0.7)
        case .styleCinematic:
            return .filter(.cinematic, strength: parameters.strength ?? 0.7)
        case .styleNoir:
            return .filter(.noir, strength: parameters.strength ?? 0.7)
        case .styleVHS:
            return .filter(.vhs, strength: parameters.strength ?? 0.7)
        }
    }
}

extension FilterRecipe {
    func applying(to input: CIImage, strength: Double, time: Double) -> CIImage {
        let amount = min(max(strength, 0), 1)
        switch self {
        case .anime, .cel:
            let quantized = input.applyingFilter("CIColorPosterize", parameters: ["inputLevels": 5 + amount * 3])
            let edges = input.applyingFilter("CIEdges", parameters: [kCIInputIntensityKey: 1.2 + amount * 2])
                .applyingFilter("CIColorInvert")
            return edges.applyingFilter("CIMultiplyCompositing", parameters: [kCIInputBackgroundImageKey: quantized])
        case .comic:
            return input.applyingFilter("CIComicEffect")
        case .sketch:
            return input.applyingFilter("CILineOverlay", parameters: ["inputNRNoiseLevel": 0.05, "inputEdgeIntensity": 1 + amount])
        case .watercolor:
            return input.applyingFilter("CIMedianFilter").applyingFilter("CIColorControls", parameters: [kCIInputSaturationKey: 1.1 + amount * 0.3])
        case .cinematic:
            return input.applyingFilter("CIColorControls", parameters: [kCIInputContrastKey: 1.05 + amount * 0.25, kCIInputSaturationKey: 0.9 + amount * 0.15])
        case .noir:
            return input.applyingFilter("CIPhotoEffectNoir")
        case .vhs:
            let shifted = input.transformed(by: CGAffineTransform(translationX: sin(time * 18) * amount * 4, y: 0))
            return shifted.applyingFilter("CIColorControls", parameters: [kCIInputSaturationKey: 0.75, kCIInputContrastKey: 1.15])
        case .colorGrade:
            return input.applyingFilter("CIColorControls", parameters: [kCIInputContrastKey: 1 + amount * 0.25, kCIInputSaturationKey: 1 + amount * 0.2])
        case .backgroundBlur:
            return input.applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: amount * 18]).cropped(to: input.extent)
        case .outline:
            let edges = input.applyingFilter("CIEdges", parameters: [kCIInputIntensityKey: 1 + amount * 3])
            return edges.applyingFilter("CIScreenBlendMode", parameters: [kCIInputBackgroundImageKey: input])
        case .glow:
            return input.applyingFilter("CIBloom", parameters: [kCIInputIntensityKey: amount, kCIInputRadiusKey: 4 + amount * 16])
        case .beatFlash:
            let pulse = max(0, sin(time * .pi * 4)) * amount
            return input.applyingFilter("CIExposureAdjust", parameters: [kCIInputEVKey: pulse * 0.75])
        case .beatZoom:
            let scale = 1 + max(0, sin(time * .pi * 2)) * amount * 0.05
            return input.transformed(by: CGAffineTransform(translationX: input.extent.midX, y: input.extent.midY))
                .transformed(by: CGAffineTransform(scaleX: scale, y: scale))
                .transformed(by: CGAffineTransform(translationX: -input.extent.midX, y: -input.extent.midY))
                .cropped(to: input.extent)
        }
    }
}
