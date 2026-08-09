## Context

The versioned effect graph already stores an ordered array of timeline segments, and the compiler consumes those intervals. The existing editor and headless agent can only add or remove effects. All edits must continue through the same validator and canonical hash path, remain local, and avoid media rendering.

## Goals / Non-Goals

**Goals:**

- Add a small set of bounded structural operations without introducing a second project model.
- Make identical split requests deterministic so idempotent agent calls retain stable graph hashes.
- Keep native API and headless-agent results behaviorally identical.

**Non-Goals:**

- Clip reordering, ripple editing, transitions between clips, or arbitrary timeline commands.
- UI timeline redesign or media generation.
- Filling timeline gaps; gaps remain valid passthrough intervals.

## Decisions

### Validate overlap centrally

The graph validator will reject adjacent sorted segments when the later start is before the prior end. Central validation protects planner, direct controls, stored projects, and agent requests equally. Gaps and touching boundaries remain valid because the current compiler can interpret them without inventing content.

Alternative considered: validate only editor operations. This would allow overlapping graphs to enter through planning or decoded project files.

### Derive the right-hand split identifier deterministically

The original segment keeps its identifier as the left result. The right result receives a UUID derived from SHA-256 over the graph ID, segment ID, and canonical split timestamp, with UUID version/variant bits normalized. This retains unique identity while ensuring retries produce the same graph hash.

Alternative considered: generate `UUID()` on every split. That makes an otherwise idempotent structured operation produce a different output hash on retry.

### Use explicit agent actions in the existing edit operation

The `edit` operation will accept `split-segment`, `trim-segment`, and `remove-segment`, alongside the existing effect actions. Required and forbidden fields are checked per action before graph mutation. This keeps capability discovery compact and avoids multiple one-off operations.

Alternative considered: add three top-level operations. That expands the protocol surface without improving safety or composability.

## Risks / Trade-offs

- [Timeline overlap validation can reject previously accepted hand-authored graphs] → Treat overlaps as ambiguous execution and return a precise diagnostic; touching boundaries and gaps remain compatible.
- [Floating-point timestamps can produce unstable identifiers] → Serialize the split timestamp using a fixed canonical representation before hashing.
- [The word trim may imply media destruction] → Define it narrowly as changing effect-segment bounds; rendering and source media remain untouched.
