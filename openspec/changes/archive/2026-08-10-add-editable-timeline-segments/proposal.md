## Why

The effect graph can describe multiple timeline segments, but creators and agents can only edit effects inside an existing segment. Adding bounded segment operations makes common timing changes reproducible and inspectable without exposing an unrestricted timeline engine.

## What Changes

- Add validated graph operations to split a segment, change its time bounds, and remove it.
- Reject invalid segment identifiers, out-of-bounds splits, overlapping intervals, and removal of the final segment.
- Extend the headless agent `edit` operation with the same segment actions and strict payload validation.
- Preserve deterministic graph hashes so identical edit requests produce identical structured output.

## Capabilities

### New Capabilities

- `timeline-segment-editing`: Bounded, deterministic editing of timeline segment structure through both the native graph API and the headless agent.

### Modified Capabilities

None.

## Impact

This affects `StudioCore` graph editing and validation, `StudioAgentSupport` request handling and manifest discovery, plus their tests and operator documentation. It adds no runtime dependency and does not change rendering or execute media work.
