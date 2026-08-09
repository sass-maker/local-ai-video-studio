## Why

Technical creators need a private way to explore several publishable edits from
one source clip without learning several professional tools or paying a cloud
rendering cost per experiment. The useful proof is not free-form prompting; it
is a small, reliable effect library that turns intent into inspectable plans and
reproducible local outputs.

## What Changes

- Create a native macOS application for importing an MP4 or MOV into a local
  project and inspecting basic media metadata.
- Convert an editing request into 2–5 strict, versioned effect graphs using a
  deterministic offline planner boundary with fixture-backed demo planning.
- Validate supported effects and parameters, estimate render effort, report
  incompatibilities, and preserve graceful fallbacks before any pipeline runs.
- Render local draft variants through an AVFoundation/Core Image pipeline,
  initially covering crop/resize, trim, speed, captions/title overlays, color
  treatments, simple transitions, audio normalization, and stylized preset
  approximations.
- Present variants in a synchronized comparison workspace with descriptive
  labels, blinded mode, rating/selection, and inspectable parameter differences.
- Export selected variants and a JSON comparison sheet with reproducible graph
  metadata, without accounts, uploads, telemetry, or arbitrary command
  execution.
- Establish explicit extension points for later Vision/Core ML/Metal/FFmpeg and
  local-LLM adapters; these heavy runtimes and production neural models are not
  included in this first implementation.

## Capabilities

### New Capabilities

- `local-media-projects`: Import media and retain portable, local project state
  without accounts, uploads, or telemetry.
- `effect-graph-planning`: Produce, validate, explain, cost, and persist strict
  effect graphs without executing model-supplied code.
- `variant-rendering`: Compile supported graph nodes into local preview and
  export pipelines while isolating individual effect failures.
- `variant-comparison`: Compare 2–5 variants with synchronized playback,
  meaningful labels, blinded selection, and reproducible exports.

### Modified Capabilities

- None.

## Impact

- Adds a new independent local project at `local-ai-video-studio/` targeting
  macOS 14+ and Apple Silicon with Swift 6, SwiftUI, AVFoundation, Core Image,
  Core Media, VideoToolbox, and XCTest.
- Persists user-selected media references, project JSON, draft renders, final
  renders, and comparison metadata only on the local machine.
- Adds no production dependency, cloud service, account system, telemetry,
  deployment, or publishing integration.
- Neural preset fidelity and the 30-second-under-60-second render target remain
  hardware-dependent acceptance work for later model-backed adapters; the MVP
  must label approximations honestly and never imply a model ran when it did
  not.
