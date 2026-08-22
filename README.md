# Local AI Video Studio

A local-first macOS prototype that turns editing intent into strict, reproducible effect graphs, renders 2–5 video variants on-device, and compares them with synchronized playback.

## Requirements

- Apple Silicon Mac
- macOS 14 or newer
- Xcode 16 / Swift 6 toolchain
- MP4 or MOV source media

No account, cloud service, telemetry, or external runtime dependency is required.

## Run

```bash
swift run LocalVideoStudio
```

To open a source immediately:

```bash
swift run LocalVideoStudio /absolute/path/to/video.mov
```

Agents do not need to drive SwiftUI. The headless command uses the same native
planner, 23-effect registry, validator, graph editor, estimator, analyzer, and
renderer:

```bash
echo '{"schema":"fleet.video-agent-operation.v1","product":"studio","operation":"manifest","input":{}}' | swift run studio-agent
```

Available operations are discovered from `manifest`; `catalog` returns every
effect and its readiness. The command is local-only, strictly rejects unknown
or executable inputs, and emits one JSON result envelope with graph hashes,
fallbacks, provenance, and artifact paths.

### Structured timeline edits

The `edit` operation supports effect actions plus three bounded timeline
actions. Each request includes the complete `graph` returned by `plan`,
`validate`, or a previous edit:

```json
{"action":"split-segment","segmentId":"<uuid>","at":2.0,"graph":{}}
{"action":"trim-segment","segmentId":"<uuid>","start":0.5,"end":3.5,"graph":{}}
{"action":"remove-segment","segmentId":"<uuid>","graph":{}}
```

These actions change effect intervals, never the source file. Splits preserve
effects on both sides and are deterministic; invalid bounds, overlaps, unknown
fields, and removal of the final segment fail closed. Use the returned graph
and `graphHash` as the input to the next operation.

In the app: import a video, edit the instruction, plan 2–5 variants, then use
**Effects** to add, remove, or tune registered effects directly. Prompt planning
and buttons edit the same validated graph. Render drafts, compare them, save
promising variants for later, select one, and export. Export is enabled only
when the selected preview matches the current normalized graph revision.

Use **Plan Variants** to work without rendering. Video work starts only from
the separate **Plan & Render Previews** or **Rerender Changed Studies** action.

## Validate

```bash
npm run quality
```

The same gate is `node scripts/check-code-health.mjs all`. Those commands remain
authoritative; `package.json` only exposes them as `format:check`, `lint`,
`typecheck`, `test`, `test:coverage`, and `quality:*` selectors.

The gate runs 43 native tests, measures StudioCore and MediaEngine coverage,
builds every SwiftPM target, checks unused code, complexity, exact duplication,
the dependency graph, suppressions, repository hygiene, and the static site.
Existing formatter, complexity, duplication, and coverage gaps are ratcheted to
[issue #16](https://github.com/sass-maker/local-ai-video-studio/issues/16): a
change may improve those baselines, but may not make them worse. Run a narrower
selector such as `coverage`, `build`, `unused`, or `site` while iterating.

## Prepare a Mac application

Create a local Release bundle with the app icon and SwiftPM resources embedded:

```bash
./scripts/package-app.sh release
```

The default build is ad-hoc signed for local verification. When a personal
Developer ID Application certificate is installed, pass its complete Keychain
identity through `LOCAL_VIDEO_STUDIO_SIGNING_IDENTITY`; the script enables the
hardened runtime and timestamp required for direct distribution. The separate
`scripts/notarize-app.sh` helper fails closed unless the bundle has that
Developer ID signature and `LOCAL_VIDEO_STUDIO_NOTARY_PROFILE` names an existing
`notarytool` Keychain profile. Neither script publishes the app or creates a
store record.

The tests include strict schema validation, deterministic graph hashing, project persistence, batch failure isolation and cancellation, plus a real AVFoundation fixture render.

## Privacy and storage

- Source media and rendered variants stay on the Mac.
- Project state is JSON stored under the user's Application Support directory.
- Preview files are written to the system temporary directory.
- The planner cannot execute shell commands or arbitrary code.
- Unsupported effects are rejected or use registered, manifest-recorded fallbacks.
- The native 23-effect catalog discloses parameters, local cost, approximation,
  and fallback readiness without depending on Reel Pipeline, Mashup, or ComfyUI.

This milestone uses Apple’s on-device prompt model when available, a deterministic local fallback planner, and Core Image/AVFoundation effect adapters. Speech analysis, true beat analysis, and production-quality segmentation remain future work.

## Prompt planning

On macOS 26 or newer, the app prefers Apple's on-device Foundation Models
framework to convert editing instructions into guided structured plans. The
model receives the instruction, output profile, duration, variant count, and
finite supported-effect catalog; it does not receive video frames or file
paths. Generated effects are mapped through the registry and validated before
rendering. If Apple Intelligence is unavailable or generation fails, the app
uses the deterministic preset planner and discloses the fallback in **View
Plan**.

The disclosed reason is specific: model ineligibility, a disabled Apple
Intelligence setting, a model that is not ready, a rejected unregistered
effect, or a graph that failed validation. `studio-agent plan` reports the same
truth as `planner`, `plannerKind`, and `fallbackReason`. Local-model planning is
injectable, so the test suite exercises mapping, validation, and fallback with a
fake model and never requires Apple Intelligence to be enabled.
