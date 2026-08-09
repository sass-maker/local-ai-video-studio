# Proposal: Add Apple Foundation Models planner

## Why

The current `DeterministicDemoPlanner` ignores most prompt semantics and always
returns fixed recipes. The installed macOS 27 SDK includes Apple's
Foundation Models framework, which can interpret editing intent locally and
produce guided structured output without uploading prompts or media.

## What changes

- Add an Apple on-device planner using `SystemLanguageModel` and guided
  generation.
- Constrain generated effects to the existing finite registry and validate the
  resulting graphs through the existing validator.
- Make Apple planning the preferred path when the OS, device, region, Apple
  Intelligence setting, and downloaded model permit it.
- Retain the deterministic planner as an explicit fallback and disclose which
  planner produced each plan.
- Show model availability and actionable fallback reasons in the app.

## Scope

In scope: prompt-to-plan only, 2–5 variants, registered effects, bounded
parameters, availability UI, offline execution, tests with an injected fake.

Out of scope: video understanding by the model, model downloads/settings
automation, cloud inference, arbitrary tools/code execution, or rendering
changes.

## Impact

No new dependency or cloud service. The package retains macOS 14 compatibility;
Foundation Models is compiled conditionally and called only on macOS 26+.

