# Effect graph planning delta

## ADDED Requirements

### Requirement: Prefer an available Apple on-device model

The application SHALL use Apple's on-device `SystemLanguageModel` for natural-
language planning when it is available and SHALL otherwise use the deterministic
fallback without blocking the workflow.

#### Scenario: Apple model is available

- **WHEN** the user creates previews on an eligible device with the model ready
- **THEN** the prompt is converted into 2–5 structured variants locally
- **AND** each graph records Apple Foundation Models provenance

#### Scenario: Apple model is unavailable

- **WHEN** eligibility, settings, region, or model readiness prevents access
- **THEN** deterministic planning remains available
- **AND** the interface explains why the fallback was used

### Requirement: Constrain and validate model output

The application SHALL accept only registered effect identifiers and bounded
parameters from generated plans, then run the existing graph validator before
any render work begins.

#### Scenario: Model proposes unsupported content

- **WHEN** generated output contains an unknown effect or invalid parameter
- **THEN** it is rejected or safely replaced by deterministic planning
- **AND** no unsupported operation is executed

### Requirement: Preserve local-first privacy

The application SHALL send no video frames, file paths, prompts, or plans to a
developer-operated service while using Apple Foundation Models.

#### Scenario: Planning a local video

- **WHEN** the Apple planner runs
- **THEN** only prompt metadata needed for planning is supplied to the on-device
  model session
- **AND** no networking or model tool invocation is configured

