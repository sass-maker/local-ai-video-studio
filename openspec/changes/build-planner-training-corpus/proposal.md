# Proposal: Run a planner schema-discovery pilot

## Why

Apple's on-device planner is structurally safe but semantically inconsistent,
while Codex and Devin GLM-5.2 passed the initial prompt-to-graph benchmark. The
effect-graph structure and final output contract are still evolving, so a large
training corpus would prematurely encode unsettled product decisions.

## What changes

- Define a provisional, versioned prompt-to-semantic-plan discovery record.
- Use Devin GLM-5.2 to generate one 20-example shard for joint schema review.
- Compile semantic plans into exact application effect graphs deterministically.
- Include representative, adversarial, ambiguous, and unsupported requests.
- Preserve raw output, validation results, human review decisions, and exact
  provenance so schema alternatives can be compared honestly.
- Keep UUIDs, schema versions, output dimensions, provenance, defaults, and
  canonical hashes out of teacher output and inside trusted Swift code.
- Explicitly defer training splits, deterministic expansion, and any 25,000
  example run until a separately approved schema-freeze milestone.

## Boundaries

No video generation, private prompt history, source paths, cloud rendering,
model training, or production planner integration. Pilot records are disposable
design evidence, not a training or benchmark corpus. This change ends after the
20-record pilot and does not authorize a second shard.
