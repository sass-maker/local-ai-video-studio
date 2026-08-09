## Purpose

Provides safe, reproducible timeline-structure edits that creators and automated agents can inspect, validate, and replay without arbitrary code execution.

## ADDED Requirements

### Requirement: Split an existing segment
The system SHALL split a named timeline segment at an interior timestamp, preserve its effects on both resulting segments, and produce the same graph identifiers and hash for identical inputs.

#### Scenario: Valid split
- **WHEN** a client splits a segment at a finite timestamp strictly inside its bounds
- **THEN** the system returns two adjacent segments covering the original interval with preserved effects and a validated canonical hash

#### Scenario: Invalid split point
- **WHEN** a client supplies a timestamp on or outside the segment bounds
- **THEN** the system rejects the edit without changing the graph

### Requirement: Change segment bounds
The system SHALL allow a named segment's start and end to be changed when the resulting interval is finite, non-negative, non-empty, and does not overlap another segment.

#### Scenario: Valid bound change
- **WHEN** a client supplies valid new start and end times for an existing segment
- **THEN** the system returns the updated, time-sorted graph and a new canonical hash

#### Scenario: Overlapping bound change
- **WHEN** a bound change would overlap another timeline segment
- **THEN** the system rejects the graph with a diagnostic identifying the overlap

### Requirement: Remove a segment safely
The system SHALL remove a named segment only when at least one other segment remains.

#### Scenario: Remove one of several segments
- **WHEN** a client removes an existing segment from a graph containing multiple segments
- **THEN** the system returns the remaining validated timeline

#### Scenario: Remove the final segment
- **WHEN** a client attempts to remove the only timeline segment
- **THEN** the system rejects the edit without changing the graph

### Requirement: Agent operations match native graph behavior
The headless agent SHALL expose split, bound-change, and remove-segment actions through strict structured inputs and SHALL return the normalized graph, canonical hash, and warnings produced by the native validator.

#### Scenario: Structured agent edit
- **WHEN** an agent submits a valid segment action using a segment UUID and the required timing values
- **THEN** the operation returns the same normalized result as the native graph API

#### Scenario: Unknown agent edit field
- **WHEN** an agent edit request contains an unknown, executable, or action-incompatible field
- **THEN** the operation fails closed with a machine-readable input error
