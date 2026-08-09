## Purpose

Defines a comparison workspace that makes multiple edits easy to judge while
keeping their concrete differences understandable and exportable.

## ADDED Requirements

### Requirement: Two-to-five variant workspace
The comparison workspace SHALL display 2–5 planned variants, their render
states, labels, duration, aspect ratio, and concise difference summaries.

#### Scenario: Compare three completed variants
- **WHEN** three preview renders are available
- **THEN** the user can see all three variants and their distinguishing plan attributes in one workspace

### Requirement: Synchronized playback
The user SHALL be able to play, pause, seek, and restart all playable variants
from a shared timeline, and the application SHALL visibly identify a variant
that cannot maintain synchronization.

#### Scenario: Seek all variants
- **WHEN** the user seeks the shared timeline to a time present in every variant
- **THEN** each playable variant seeks to the corresponding comparison time and resumes according to the shared playback state

### Requirement: Blinded comparison and rating
The application SHALL offer a blinded mode that conceals style and plan labels
until the user reveals them, and SHALL let the user rate and select a preferred
variant without changing its graph.

#### Scenario: Select while blinded
- **WHEN** the user enables blinded mode and selects a preferred variant
- **THEN** the application records the stable variant identity while withholding descriptive labels until reveal

### Requirement: Direct parameter adjustment
The user SHALL be able to adjust registered, user-editable graph parameters
through direct controls, SHALL see validation feedback before rerendering, and
SHALL preserve the prior completed variant until a replacement succeeds.

#### Scenario: Adjust style strength
- **WHEN** the user changes a supported style-strength control within its allowed range
- **THEN** the application creates a revised graph revision and offers rerender without overwriting the prior completed output

### Requirement: Comparison sheet export
The application SHALL export a human-readable and machine-readable comparison
sheet containing variant identity, label, style, hook, duration, aspect ratio,
effect parameters, rating, selection state, and degradation notes.

#### Scenario: Export comparison metadata
- **WHEN** the user exports selected results
- **THEN** the export folder contains comparison metadata for every compared variant, including variants not selected for video export
