## Purpose

Defines portable, offline project behavior so creators retain control of source
media, generated plans, comparison state, and outputs on their own Mac.

## ADDED Requirements

### Requirement: Supported video import
The application SHALL allow the user to select an MP4 or MOV file, SHALL read
its duration, dimensions, frame rate, and audio presence locally, and SHALL
reject an unreadable or unsupported file with a recoverable explanation.

#### Scenario: Import a readable local clip
- **WHEN** the user selects a readable MP4 or MOV file
- **THEN** the application creates a project and displays the clip metadata without uploading the file

#### Scenario: Reject an unreadable clip
- **WHEN** the selected file cannot be decoded or accessed
- **THEN** the application keeps the current workspace usable and explains that no project was created from that file

### Requirement: Local project persistence
The application SHALL save a versioned project document containing source
references, user intent, variant graphs, render state, ratings, and selections,
and SHALL preserve enough information to reopen the project without network
access.

#### Scenario: Reopen a saved project offline
- **WHEN** the user opens a previously saved project while the Mac has no network connection
- **THEN** the application restores all persisted project state and identifies any source or render file that has moved

### Requirement: Private-by-default operation
The application SHALL require no account, SHALL upload no media or project
metadata, and SHALL emit no telemetry by default.

#### Scenario: Complete the core workflow offline
- **WHEN** required local resources are installed and the Mac has no network connection
- **THEN** the user can import, plan, render, compare, and export a project without an account or network request

### Requirement: Resource visibility
Before rendering, the application SHALL show the selected output profile,
estimated work class, expected output location, and available local disk space,
and SHALL prevent starting when known free space is insufficient.

#### Scenario: Insufficient output space
- **WHEN** estimated required disk space exceeds currently available space
- **THEN** the application disables render start and explains how much additional space is required
