# PRD — Local Video Planner Training Corpus

## Objective

Create a large, reproducible supervised corpus that teaches a small model to
convert natural-language video-editing requests into the application's strict
effect graphs.

## Target deliverable

- 25,000 accepted training examples
- 2,000 accepted validation examples
- 1,000 sealed test examples
- rejected-example evidence and exact manifests
- no video or private user data

An example contains the prompt, requested variant count, output profile,
duration, required and forbidden effects, expected graphs, difficulty,
capability tags, approximation expectations, source family, and provenance.

## Curriculum

- 35% atomic requests: one principal effect or edit
- 35% compound requests: 2–5 compatible requirements
- 15% negative constraints and conflicts
- 10% unsupported requests requiring honest approximation
- 5% parameter boundaries, ambiguous wording, and adversarial structure

Variant counts 2–5 and output ratios 9:16, 16:9, and 1:1 are balanced. Every
registered effect receives atomic, compound, negative, and boundary coverage.

## Quality gates

Teacher output is accepted only when it has exact schema shape, registered
effects, bounded parameters, valid compatibility, complete required-effect
coverage, zero forbidden effects, meaningful variant differences, honest
unsupported disclosures, and no near-duplicate or split-family leakage.

## Generation strategy

Devin GLM-5.2 authors diverse seed families and critiques difficult examples.
A deterministic local expander produces controlled paraphrases and parameter
variations. This makes scale reproducible and affordable without pretending
that thousands of nearly identical LLM outputs are useful data.

## Success criteria

- ≥95% sampled human acceptance
- 100% structural validity
- ≥98% required-effect recall
- zero unsupported identifier leakage
- zero known family leakage across splits
- balanced coverage within ±5% of curriculum targets
- exact regeneration from manifests

