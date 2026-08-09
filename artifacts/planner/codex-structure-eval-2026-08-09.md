# Codex effect-graph structure evaluation

Date: 2026-08-09  
Model: `gpt-5.6-sol` through local Codex CLI (cloud inference)  
Sandbox: read-only, ephemeral  
Input: eight synthetic prompts plus the finite effect schema; no media or project files  
Duration: 73.1 seconds for one batched response  
Output: 8 cases, 24 variants, 20,196 tokens

## Mechanical result

- JSON Schema compliance: pass
- Exact case count and requested variant counts: pass
- Registered effect identifiers only: pass
- Numeric parameter bounds: pass
- Required-effect obligations: 57/58 by the generic mechanical scorer
- Forbidden-effect hits: 0
- Unsupported-request disclosure: 2/2 variants

The scorer's sole apparent miss is not a semantic failure: it expected slow
motion in both watercolor variants, while the prompt requested one slow-motion
version and one lighter watercolor version. Human review therefore finds all
explicit effect requirements satisfied.

## Fitness verdict

Codex passes the structure and semantic-planning requirement on this suite. It
is substantially more reliable than the current Apple-only result (68.8%
requested-effect recall with two fallbacks), but it is cloud-backed despite
being invoked through a local CLI. It is appropriate as a development-time
teacher and synthetic-data generator. Using it inside the shipped local-first
app would require an explicit product/privacy change and must not be implemented
by shelling out from the app.
