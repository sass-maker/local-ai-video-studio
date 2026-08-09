# Pilot 001 early structure review

The first five of twenty planned records were generated with Devin GLM-5.2.
Generation is intentionally paused before the remaining fifteen because the
sub-batch exposed contract ambiguities that should be fixed first.

## Mechanical observations

- Five valid JSONL records were returned in input order.
- Requested variant counts were correct: 3, 2, 4, 3, and 2.
- All emitted effect identifiers belong to the current 23-effect registry.
- Numeric strengths, intensities, speed rates, and transition durations stayed
  within the stated bounds.
- The teacher represented `timeline` as `{ "segments": [...] }`; the Swift
  `EffectGraph` contract expects `timeline` to be the segment array itself.
- Segment and effect IDs were readable symbolic identifiers rather than UUIDs,
  despite the application contract requiring UUIDs.

## Product/schema observations

- The provisional discovery-record schema intentionally accepts arbitrary
  candidate graph objects, so it preserved these failures but did not detect
  them. A separate exact application-graph schema or decoder check is needed.
- “Slow pans” has no faithful registered effect. Devin approximated it with
  `crop.auto_subject`, showing that automatic reframing and authored pan motion
  need distinct semantics if the product promises both.
- Required effects currently describe the request as a whole. They cannot state
  cleanly that `title.card` belongs only to variant two or that different style
  effects belong to different named variants.
- Raw response graphs duplicate normalized candidate graphs, roughly doubling
  output size. Raw teacher text and normalized candidates should be stored
  separately rather than embedded twice in each record.

## Recommendation before continuing

Revise discovery v0 before generating records 006–020:

1. Reference an exact application graph schema and validate by decoding with
   `StudioCore`.
2. Add per-variant obligations instead of only record-level required effects.
3. Decide whether subject-following pan needs a distinct effect type.
4. Store one raw response envelope and normalized graphs without duplication.
5. Generate the remaining fifteen records only after those decisions are made.

This is a successful discovery stop, not an accepted training-data batch.
