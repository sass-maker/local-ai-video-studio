## Operating rules

- Do not run destructive commands or touch secrets and credentials.
- Inspect git state and the smallest relevant source and tests before editing.
- Preserve unrelated work, prefer small diffs, and run the narrowest relevant
  check first.
- Do not commit, push, release, add production dependencies, or render large
  media unless explicitly authorized.
- Use the repo-local OpenSpec workflow for non-trivial features and preserve the
  validated design-review receipt for meaningful visual changes.

## Project

- Stack: Swift 6, SwiftUI, AVFoundation, Core Image, XCTest
- Local dev: `swift run LocalVideoStudio`
- Checks: `node scripts/check-code-health.mjs all`; use a narrower selector such
  as `coverage`, `build`, `unused`, or `site` while iterating.
- Platform: macOS 14+ on Apple Silicon

## Boundaries

- Keep media processing local and offline-capable.
- The planner may emit only the versioned effect-graph schema; it must never
  execute shell commands or arbitrary code.
- Do not add model runtimes, FFmpeg, or other production dependencies without
  explicit approval and a documented licensing/size rationale.
- Preserve graceful fallback: an unsupported effect must not invalidate an
  otherwise renderable variant.

## Agent operation

- Use `swift run studio-agent` with one `fleet.video-agent-operation.v1`
  request on stdin or via `--request`. Begin with `manifest` and `catalog`.
- Use `validateOnly: true` before render, project selection, or export. The
  CLI emits one JSON result envelope and never publishes externally.
- Prefer structured project files and effect graphs over UI automation.
- Treat SwiftUI as a human control surface, not the canonical automation API.
- Keep agent actions bounded to registered effect IDs and validated parameters.
- Surface planner provenance, graph hashes, fallback reasons, estimated cost,
  and artifact paths in machine-readable results.
- Never allow a model to execute shell commands or arbitrary code.

## Code health

- Keep the checked-in quality baselines non-regressing. When a metric improves,
  lower its ceiling or raise its floor in the same change.
- Do not introduce inline lint or coverage suppressions. Durable cleanup belongs
  in GitHub issue #16 rather than source TODOs.

## Visual work

The owner-approved Optical Printer Bench direction is established. New UI work
defaults to the `preserve` lane unless the owner explicitly approves another
overhaul. Follow the Fleet `design-workflow` and do not claim completion until
its receipt passes.
