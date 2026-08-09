# Apple Foundation Models planner evaluation

Date: 2026-08-09  
Command: `RUN_APPLE_MODEL_EVAL=1 swift test --filter applePlannerSemanticEvaluation`  
Media work: none; text-only on-device planning  
Duration: 387.716 seconds for eight prompts

## Result

- Apple model used successfully: 6/8 cases
- Deterministic fallback: 2/8 cases
- Requested-effect semantic recall: 68.8%
- Forbidden-effect hits: 3, all introduced by the fixed fallback recipes
- All Apple-produced effect identifiers remained inside the registered catalog
- All accepted Apple graphs passed the existing validator

## Case observations

| Case | Outcome |
|---|---|
| Watercolor + slow motion | Watercolor selected; speed omitted |
| Restrained noir with negative constraints | Correct noir selection and exclusions |
| VHS title hook + beat flash | Apple generation failed; deterministic fallback did not preserve the request |
| Comic + outline + glow | All requested effects selected |
| Cinematic + background blur + grade | Blur and grade selected; cinematic style omitted |
| Clean original + normalize + reframe | Apple generation failed; fallback introduced forbidden cel/comic styles |
| Captions + automatic framing | Framing selected; captions omitted |
| Unsupported 3D world replacement | Stayed inside the catalog and chose an explicit approximation |

## Fitness verdict

The on-device model is a useful semantic proposal engine for direct style
requests, negative constraints, and safe approximation. It is not reliable
enough to be the sole planning authority for compound editing instructions.

The production planner should use a hybrid design:

1. deterministically extract explicit required and forbidden effects;
2. ask Apple Foundation Models to propose creative variants within those
   constraints;
3. reconcile the proposal against required/forbidden sets;
4. validate the final graphs;
5. use a request-aware fallback rather than fixed recipes.

Latency averaged roughly 48 seconds per prompt in this test process. The app
should prewarm the model, reuse a session where safe, and set a bounded timeout
before relying on it for an interactive planning experience.
