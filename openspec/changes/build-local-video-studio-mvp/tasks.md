## 1. Project and design gates

- [x] 1.1 Review and approve the OpenSpec proposal, capability specs, technical design, and MVP boundary before feature code
- [x] 1.2 Establish the Swift 6 package with separate `StudioCore`, `MediaEngine`, `StudioApp`, and test targets; verify `swift build` and `swift test`
- [x] 1.3 Run the Fleet overhaul design setup, record 2–3 named references and anti-references, and create three materially different workspace direction probes
- [x] 1.4 Obtain owner approval or explicit delegation for one probe, then encode the selected tokens, layout, component, interaction, and motion rules in `DESIGN.md`

## 2. Effect graph and planning core

- [x] 2.1 Implement versioned Codable output, timeline, target, effect, parameter, provenance, variant, and project models with strict unknown-field rejection
- [x] 2.2 Implement the finite effect registry, parameter bounds, compatibility rules, deterministic normalization, canonical encoding, and stable graph hashing
- [x] 2.3 Implement structured validation diagnostics, registered fallback warnings, work-class estimation, and disk-space preflight
- [x] 2.4 Implement the planner protocol and deterministic milestone planner that produces the requested anime, comic, and original/background/caption/beat-flash variants with honest provenance
- [x] 2.5 Add unit tests and JSON fixtures for valid graphs, unknown content, invalid intervals and parameters, conflicts, canonical hashes, estimates, and 2–5 meaningful variants

## 3. Local media projects

- [x] 3.1 Implement MP4/MOV selection, AVFoundation metadata analysis, supported-input diagnostics, source fingerprinting, and moved-source relinking
- [x] 3.2 Implement versioned local project JSON with relative media references, graph revisions, comparison state, render manifests, and atomic writes
- [x] 3.3 Add tests for project round trips, offline reopening, missing/mismatched source handling, schema versions, and persistence failure recovery

## 4. Renderer and batch coordination

- [x] 4.1 Compile normalized graphs through registered adapters for trim, crop/resize, speed, text overlays, color/preset recipes, simple transitions, and audio normalization
- [x] 4.2 Implement 720p preview and H.264 export with temporary outputs, atomic completion, exact graph/source manifests, and no arbitrary subprocess execution
- [x] 4.3 Implement the actor-based batch coordinator with queued, rendering, completed, degraded, failed, and cancelled states plus one-at-a-time memory-safe scheduling
- [x] 4.4 Implement registered passthrough degradation and per-variant failure isolation so completed siblings remain usable
- [x] 4.5 Add renderer/compiler tests using short generated fixture media for effect order, timeline bounds, output metadata, degradation, cancellation, and reproducibility

## 5. Native workflow and comparison UI

- [x] 5.1 Build the approved SwiftUI project shell with import, intent, output profile, resource estimate, graph review, and explicit render controls
- [x] 5.2 Build per-variant render cards and playable previews that become available independently and disclose approximation, progress, warnings, and failures
- [x] 5.3 Implement shared play, pause, seek, restart, drift indication, and synchronized playback across 2–5 playable variants
- [x] 5.4 Implement blinded mode, reveal, rating, preferred selection, plan-difference inspection, and validated direct parameter controls that create graph revisions
- [x] 5.5 Implement selected-video export, metadata-rich filenames, and JSON plus readable comparison-sheet export
- [ ] 5.6 Add accessibility labels, keyboard operation, reduced-motion behavior, empty/loading/error states, and focused UI tests for the primary ten-minute workflow

## 6. Acceptance and documentation

- [ ] 6.1 Verify the exact three-variant milestone request end to end on a 30–60 second local fixture and retain stage timing plus render-success evidence without retaining private media
- [ ] 6.2 Measure first-preview latency, preview playback, 30-second 720p draft time, cancellation, memory pressure, offline behavior, and disk preflight on a representative 16 GB Apple Silicon Mac; report misses honestly
- [x] 6.3 Run `swift test` and `swift build`, then resolve all product-caused failures
- [ ] 6.4 Run the Fleet design critique, polish, and audit; capture equivalent macOS window evidence, resolve all P0/P1 findings, record scores and the native-capture exception, and request final owner `keep` or `delegated` feedback
- [ ] 6.5 Update README usage and privacy documentation plus `PROJECT_STATUS.md` with only shipped truth, validate OpenSpec strictly, and archive the completed change after every required check passes
