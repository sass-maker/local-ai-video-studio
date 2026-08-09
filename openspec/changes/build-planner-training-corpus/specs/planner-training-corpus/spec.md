# Planner schema-discovery pilot

## ADDED Requirements

### Requirement: Versioned discovery records

Each record SHALL contain an editing prompt, explicit constraints, teacher raw
output, a minimal semantic plan, capability tags, compiled effect graphs,
validation findings, human disposition, and exact generation provenance.

#### Scenario: Reviewing teacher output

- **WHEN** Devin generates a candidate record
- **THEN** the raw response, semantic plan, and locally compiled result are
  stored with a stable record ID and provenance whether validation passes or fails

### Requirement: Minimal teacher contract

The teacher SHALL emit only a decision, reason, and variant creative intent.
Variant intent SHALL contain a label, output intent, and registered effects with
meaningful parameters. It SHALL NOT contain UUIDs, application schema versions,
exact dimensions, frame rate, provenance, timelines, or hashes.

#### Scenario: Planning a supported request

- **WHEN** the teacher can satisfy a supported editing request
- **THEN** it returns two to five semantic variants without application bookkeeping

### Requirement: Deterministic graph compilation

Trusted local code SHALL compile semantic variants into strict `EffectGraph`
values by assigning identifiers, provenance, output defaults, timeline bounds,
schema version, and canonical validation.

#### Scenario: Compiling a semantic variant

- **WHEN** a semantic plan contains registered effects with valid parameters
- **THEN** the compiler produces a graph accepted by `EffectGraphValidator`

#### Scenario: Invalid effect parameter

- **WHEN** a semantic effect uses a parameter unsupported by its registry definition
- **THEN** compilation fails with a field-specific diagnostic instead of guessing

### Requirement: Honest rejection

Invalid, weak, or structurally disputed outputs SHALL be retained as discovery
evidence and SHALL NOT be represented as training-ready examples.

#### Scenario: Missing explicit instruction

- **WHEN** a variant omits a required effect or includes a forbidden effect
- **THEN** the example is rejected with a machine-readable reason

### Requirement: Staged generation gate

Generation SHALL contain exactly one 20-record discovery shard under this change.

#### Scenario: Completing the first shard

- **WHEN** 20 records have been generated and validated
- **THEN** generation stops and any additional shard requires a separate change

### Requirement: Deferred corpus production

The pilot SHALL NOT create training, validation, or sealed-test splits, perform
deterministic corpus expansion, or initiate the proposed 25,000-example run.

#### Scenario: Reaching a promising schema

- **WHEN** pilot review indicates the structure may be suitable for post-training
- **THEN** the larger corpus remains blocked until schema v1, the effect taxonomy,
  timeline semantics, ambiguity behavior, and evaluation rubric are frozen in a
  separately approved change
