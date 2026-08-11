# Local AI Video Studio — PROJECT STATUS

Last updated: 2026-08-10

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

- 2026-08-11 — Added repeatable arm64 Release app packaging with embedded
  resources and icon, hardened-runtime Developer ID signing support, and a
  fail-closed notarization helper. Public distribution remains pending Apple
  signing credentials and a declared release channel.
- 2026-08-11 — Shipped the repository-owned informational product site to
  `local-ai-video-studio.pages.dev` from verified `main`, with real native
  evidence, privacy and system details, release-state metadata, and a
  fail-closed direct-download gate.
- 2026-08-10 — Added deterministic timeline-segment split, trim, and removal
  through the shared validated graph and headless agent interface.
- 2026-08-09 — Added the headless `studio-agent` executable over the same
  native planner, analyzer, 23-effect registry, validator, graph editor,
  estimator, renderer, project store, selection, and hash-gated export rules.
- 2026-08-09 — Added a native 23-effect capability catalog and direct effect
  controls that share the validated graph and reproducibility path with prompt
  planning.
- 2026-08-09 — Local project and initial product-change proposal scaffolded.

## Products

- Local macOS video-effects application.
- Locally packaged `dist/Local AI Video Studio.app`; no public download channel
  is currently declared.
- Dependency-free informational product site live at
  `https://local-ai-video-studio.pages.dev` and maintained from `site/`.

## Features (shipped)

- Repeatable local Release bundle assembly with versioned metadata, embedded
  SwiftPM resources and icon, hardened-runtime signing support, strict
  signature verification, and fail-closed Apple notarization checks.
- Verified public informational surface with real native product evidence,
  local-data disclosure, hardware and macOS requirements, version/build
  identity, support readiness, repository-owned manual Pages deployment, and
  release metadata that cannot expose an untrusted Mac binary.
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
- Strict machine-readable capability discovery and local operations with
  stable graph hashes, planner provenance, fallback truth, artifact paths, and
  rejection of unknown or executable inputs.
- Deterministic effect-timeline segment split, bound changes, and safe removal,
  including overlap rejection and strict agent payload validation.

## Work queue

- https://github.com/sass-maker/local-ai-video-studio/issues
