# PRD — Smooth Local Capabilities on Apple Silicon

## Hardware envelope

The development machine is a high-memory Apple Silicon MacBook Pro. The product
must still target a 16 GB Apple Silicon baseline by adapting preview resolution,
concurrency, and model use.

## Priority 1 — Complete the reliable editing core

- real captions and title cards through Core Animation / AVFoundation
- actual loudness measurement and normalization
- trim ranges, scene selection, speed ramps, and crossfades
- reusable color-grade and LUT recipes
- render-one-variant, cancel, retry, and cache reuse
- simple project reopening and saved-variant library

These are deterministic, inspectable, and should remain fast at 720p preview.

## Priority 2 — Apple-native perception

- Vision person rectangles and face landmarks
- subject tracking with confidence-aware center-crop fallback
- Vision person segmentation for blur and background replacement
- on-device Speech transcription with word timing when supported
- Accelerate/vDSP beat and onset analysis
- thumbnail scene-change detection and hook candidates

Each analysis result is cached independently and records confidence, model/API
version, and fallback behavior.

## Priority 3 — Composable effects

- tracked captions, face-safe reframing, background blur/replacement
- motion trails, outlines, glow, particles, flashes, and beat zooms
- sketch, watercolor, cel, noir, cinematic, and VHS recipes
- effect compatibility matrix and preview-quality tiers

Avoid diffusion-based per-frame generation in the core workflow until temporal
consistency and draft latency meet explicit gates.

## Priority 4 — Planning and learning

- hybrid constraint extractor plus creative model proposals
- prompt-plan inspector and editable requirements
- request-aware repair instead of fixed fallback recipes
- local small-model training from the validated corpus
- offline evaluation suite and planner comparison reports

## Later

- webcam recording as a source
- lightweight live deterministic preview
- OBS output only after offline effects and memory behavior are reliable

## Performance gates

- planning does not load video frames
- analysis stages are cancellable and cached
- one expensive ML stage at a time on 16 GB machines
- preview begins at reduced resolution and upgrades opportunistically
- no single failed perception adapter invalidates the entire render
