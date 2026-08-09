# Devin GLM-5.2 effect-graph evaluation

Date: 2026-08-09  
Model: `glm-5.2` through the local Devin CLI (external inference)  
Permission mode: read-only auto approval  
Input: eight synthetic prompts plus the finite effect schema; no media or project files  
Duration: 48.9 seconds for one batched response

## Result

- Cases: 8/8
- Requested variants: 24/24
- Exact object shape: pass
- Registered effect identifiers only: pass
- Numeric parameter bounds: pass
- Variant-specific required-effect obligations: 54/54
- Forbidden-effect hits: 0
- Unsupported-request disclosure: 2/2 variants

## Comparison

| Planner | Semantic coverage | Fallbacks | Batch duration |
|---|---:|---:|---:|
| Apple Foundation Models | 68.8% | 2/8 | 387.7s |
| Codex `gpt-5.6-sol` | 100% after review | 0 | 73.1s |
| Devin `glm-5.2` | 100% | 0 | 48.9s |

## Fitness verdict

GLM-5.2 passes this initial structure and semantic benchmark and is the best
candidate of the three for bulk synthetic prompt-to-graph generation. It was
faster than Codex on the identical batched suite and substantially more reliable
than Apple Foundation Models.

The Devin CLI does not expose session cost in its terminal result. Devin bills
self-serve usage through included quota and then on-demand credits, with usage
based on work performed. Therefore this run does not establish a measured
per-example price. Before generating a large corpus, run a 100–500 example
pilot and compare the account usage delta, acceptance rate, duplication, and
human correction rate.
