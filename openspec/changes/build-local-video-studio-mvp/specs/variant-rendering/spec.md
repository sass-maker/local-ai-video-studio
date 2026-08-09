## Purpose

Defines safe local compilation, preview, and export behavior for reproducible
variant graphs while keeping partial effect failures recoverable.

## ADDED Requirements

### Requirement: Registry-bound compilation
The compiler SHALL translate only normalized graph nodes found in the local
effect registry into renderer operations and SHALL preserve effect order and
timeline bounds.

#### Scenario: Compile a supported graph
- **WHEN** the compiler receives a normalized graph whose effects all have registered implementations or fallbacks
- **THEN** it produces an executable local pipeline containing only those registered operations

### Requirement: Draft preview rendering
The renderer SHALL produce a lower-cost preview for each variant and SHALL make
the first playable result available independently of later variants.

#### Scenario: First variant finishes before the batch
- **WHEN** one preview completes while other variants remain queued or rendering
- **THEN** the completed preview becomes playable and the remaining per-variant states stay visible

### Requirement: Graceful effect degradation
A recoverable effect failure SHALL NOT fail the entire render when a registered
fallback exists, and the output SHALL record which effect degraded or was
skipped.

#### Scenario: Optional style operation fails
- **WHEN** an optional style operation fails and the registry permits passthrough fallback
- **THEN** rendering continues without that operation and marks the completed variant as degraded with a visible reason

#### Scenario: Required operation fails
- **WHEN** a required operation fails and no registered fallback exists
- **THEN** only the affected variant fails, its partial output is not presented as complete, and other variants continue

### Requirement: Cancellable background batch
The application SHALL render variants without blocking workspace interaction,
SHALL expose queued, rendering, completed, degraded, failed, and cancelled
states, and SHALL let the user cancel pending or active work.

#### Scenario: Cancel an active batch
- **WHEN** the user cancels rendering
- **THEN** pending variants become cancelled, active work stops at a safe boundary, completed outputs remain available, and no partial file is labeled complete

### Requirement: Reproducible export
Each exported video SHALL be associated with its exact normalized graph, source
fingerprint, output profile, application schema version, degradation record,
and stable variant identifier.

#### Scenario: Export a selected variant
- **WHEN** the user exports a completed or explicitly accepted degraded variant
- **THEN** the application writes the video and machine-readable metadata that can identify the exact plan used
