GOAL:
Return exactly two JSONL records for pilot-001-006 and pilot-001-009. Do not use tools. The prior repair was rejected. Copy the canonical shapes below exactly and change values only.

RECORD SHAPE AND TYPES:
{"record_id":"pilot-001-006","category":"representative","prompt":"string","constraints":{"variant_count":3,"required_effects":["string"],"forbidden_effects":["string"]},"capability_tags":["string"],"teacher":{"provider":"devin","model":"glm-5.2","prompt_version":"discovery-v0.4","generated_at":"2026-08-09T00:00:00Z"},"raw_response":{"decision":"plan","reason":"string"},"candidate_graphs":[],"validation":{"status":"pending","validator_version":"studio-core-v1","findings":[]},"human_review":{"status":"pending","notes":""}}

GRAPH SHAPE AND TYPES — COPY EXACTLY:
{"schema_version":1,"id":"11000000-0000-4000-8000-000000000001","label":"string","difference_summary":"string","provenance":{"kind":"local_model","name":"Devin GLM-5.2","version":"discovery-v0.4"},"output":{"aspect_ratio":"9:16","width":1080,"height":1920,"fps":30},"timeline":[{"id":"22000000-0000-4000-8000-000000000001","start":0,"end":15,"effects":[{"id":"33000000-0000-4000-8000-000000000001","type":"style.vhs","parameters":{"strength":0.7},"required":true}]}]}

NON-NEGOTIABLE TYPES:
- schema_version is integer 1, never a string.
- provenance is the exact object shown, never a string.
- output is the exact object shown, never a string.
- timeline is directly an array.
- required is a Boolean true/false, never an array.
- validation uses validator_version and findings exactly.
- raw_response.decision is plan.
- Every id is a canonical UUID.

EFFECT PARAMETER LAW:
- strength only for style.vhs and the other style effects, background.blur, subject.outline, subject.glow.
- intensity only for beat.flash, beat.zoom, color.grade.
- rate only for timeline.speed.
- duration only for transition.crossfade.
- title.card may use text or preset but MUST NOT use duration.
- timeline.trim uses empty parameters; segment start/end carries timing.
- audio.normalize uses preset or empty parameters.

INPUT 006:
{"record_id":"pilot-001-006","category":"representative","prompt":"Produce three retro VHS product-demo cuts with different speeds. Add an opening title and normalize the voiceover, but do not add subtitles.","constraints":{"variant_count":3,"required_effects":["style.vhs","timeline.speed","title.card","audio.normalize"],"forbidden_effects":["caption.dynamic"]},"capability_tags":["vhs","speed","title","forbidden_caption"]}
Return 3 graphs. Each has style.vhs, timeline.speed, title.card without duration, audio.normalize, and no caption.dynamic. Use 9:16 output.

INPUT 009:
{"record_id":"pilot-001-009","category":"representative","prompt":"Cut a 45-second landscape demo down to 15 seconds, speed up the middle section, add a crossfade at the transition, and finish with a title card. Create two pacing alternatives.","constraints":{"variant_count":2,"required_effects":["timeline.trim","timeline.speed","transition.crossfade","title.card"],"forbidden_effects":[]},"capability_tags":["timeline","segment_specific","duration"]}
Return 2 graphs. Use 16:9 output and timeline segments 0–5, 5–10, 10–15. Include timeline.trim with empty parameters, timeline.speed in the middle, transition.crossfade with duration 0.5, and title.card without duration at the end.

VERIFY:
Two JSONL lines only; exact field names and types; 3 and 2 graphs; title.card never has duration; no Markdown.
