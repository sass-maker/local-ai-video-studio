## Purpose

Defines a safe and inspectable contract between natural-language editing intent
and the finite set of pipelines the local renderer is allowed to execute.

## ADDED Requirements

### Requirement: Versioned strict graph
Every variant plan SHALL conform to a versioned schema defining output profile,
timeline intervals, supported effect identifiers, typed parameters, stable
variant identity, and planner provenance.

#### Scenario: Accept a valid plan
- **WHEN** a plan contains a supported schema version, valid output profile, ordered timeline intervals, supported effects, and parameters within their declared ranges
- **THEN** validation returns a normalized immutable graph suitable for cost estimation and compilation

#### Scenario: Reject unknown graph content
- **WHEN** a plan contains an unknown effect, unknown required field, unsupported schema version, invalid time interval, or out-of-range parameter
- **THEN** validation rejects the plan with field-specific diagnostics before rendering begins

### Requirement: No arbitrary execution
Planner output SHALL be treated only as data and SHALL NOT supply shell
commands, file-system commands, executable code, dynamic libraries, shader
source, model paths, or unregistered effect implementations.

#### Scenario: Planner attempts to include executable content
- **WHEN** planner output includes a command or code-like field outside the schema
- **THEN** strict decoding rejects the output and no executable content is invoked

### Requirement: Meaningfully varied batch plans
Given a request for 2–5 versions, the planner SHALL produce that number of
graphs with explicit difference summaries and SHALL vary at least one requested
dimension per variant while retaining shared source and output constraints.

#### Scenario: Request three vertical styles
- **WHEN** the user requests three vertical versions with anime, comic-book, and original-with-background/captions/beat-flashes treatments
- **THEN** the planner returns three valid 9:16 graphs whose labels and parameters explain their distinct style and effect choices

### Requirement: Compatibility resolution
Validation SHALL identify incompatible effect combinations and SHALL either
apply a registered deterministic resolution with a visible warning or reject
the affected variant with a corrective diagnostic.

#### Scenario: Registered conflict has a fallback
- **WHEN** two requested effects conflict and the effect registry defines a precedence or fallback rule
- **THEN** the normalized graph uses that rule and records a user-visible warning describing the change

### Requirement: Render estimate
The application SHALL classify each normalized graph's expected work using
media duration, output pixels, frame rate, and registered effect costs without
claiming a precise completion time it cannot substantiate.

#### Scenario: Expensive effect lowers preview profile
- **WHEN** a graph contains an effect marked expensive for the available hardware
- **THEN** the estimate recommends a lower preview resolution and identifies the effects responsible
