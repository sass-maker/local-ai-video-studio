# Local AI Video Studio — PROJECT STATUS

Last updated: 2026-08-09

## Why / What

A private, local-first macOS studio that turns natural-language editing intent
into validated, reproducible video-effect variants for side-by-side comparison.

**Users:** Technical creators using Apple Silicon Macs with at least 16 GB of
unified memory.

**In scope:** Offline project files, video import, strict effect graphs,
deterministic preview/render pipelines, 2–5 comparable variants, synchronized
playback, selection, and export.

**Out of scope:** Cloud rendering, publishing integrations, collaboration,
third-party plugins, arbitrary code execution, text-to-video, and professional
frame-perfect editing.

## Dependencies

### External

- macOS 14+ system frameworks: SwiftUI, AVFoundation, Core Image, Core Media,
  and VideoToolbox.
- Optional future model/runtime dependencies require separate approval.

### Internal

- Fleet OpenSpec and design-review workflows during development only.

## Timeline

- 2026-08-09 — Added a native 23-effect capability catalog and direct effect
  controls that share the validated graph and reproducibility path with prompt
  planning.
- 2026-08-09 — Local project and initial product-change proposal scaffolded.

## Products

- Local macOS video-effects application.

## Features (shipped)

- Strict versioned effect graphs with validation, compatibility resolution,
  cost estimation, canonical hashing, and local project persistence.
- Apple on-device prompt planning when available with deterministic local
  fallback and visible planner provenance.
- Native catalog for all 23 registered effects with categories, parameter
  bounds, local cost, approximation state, and fallback disclosure.
- Direct selected-variant or explicit all-variant add/remove controls plus
  schema-derived numeric tuning through the same graph validator used by the
  planner.
- Adaptive dark-first comparison workspace with synchronized playback, stale
  revision protection, save-for-later markers, and hash-gated export.

## Work queue

- https://github.com/sass-maker/local-ai-video-studio/issues
