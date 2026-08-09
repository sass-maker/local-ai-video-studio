# Pilot 001 review

## Outcome

The first discovery shard is complete and stopped at its approval gate.

- Records: 20
- Effective executable graphs: 29
- Planner decisions: 10 plan, 7 clarify, 3 unsupported
- Swift decoding: 29/29 pass
- `EffectGraphValidator`: 29/29 pass
- Video renders: 0

The final teacher target is `semantic-plan.schema.json`, not the application
effect graph. Two small semantic repairs corrected missing required effects in
records 001 and 002. The effective 20-record set passes required and forbidden
effect obligations in addition to structural compilation.

Raw failed attempts remain beside accepted and normalized records. Fleet skill
run IDs in the manifest provide exact invocation provenance.

## What improved with prompting

An explicit canonical graph object fixed the original timeline-wrapper and UUID
failures. An immutable record envelope fixed most outer-record drift. Explicit
effect-specific parameter rules fixed title-card duration and outline/glow
parameter mistakes.

## What prompting did not solve reliably

When the full application schema was shortened in a repair prompt, the teacher
regressed to string schema versions, flattened provenance/output, non-Boolean
`required`, and misplaced metadata. Even a semantically correct retry could
rename `aspect_ratio` and omit `fps`.

This indicates that GLM-5.2 is suitable for semantic planning, but exact UUIDs,
provenance, output boilerplate, and application serialization should be owned by
a deterministic compiler. The effective record for 010 therefore preserves
the teacher's correct plan while locally normalizing `intensity` to the
registry-supported `strength` for outline and glow.

## Recommended planner boundary

Devin should emit a smaller semantic draft:

- decision and reason;
- variant labels and differences;
- output intent;
- timeline intent;
- registered effect types and meaningful parameters;
- clarification or unsupported response.

Local code should assign UUIDs, provenance, exact output dimensions, defaults,
schema version, and canonical JSON before decoding and validation. Failed raw
teacher responses must remain available for later training decisions.

## Gate

The semantic-draft schema and deterministic mapping into `EffectGraph` are now
implemented and mechanically validated. Do not generate shard 002 under this
change. Before a larger corpus, product review must still freeze timeline
semantics, per-variant obligations, effect taxonomy, and the human usefulness
rubric. Structural success alone is not a training-corpus approval.
