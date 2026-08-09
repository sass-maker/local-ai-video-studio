GOAL:
Return exactly one JSON object on one line for pilot-001-009. Do not use tools or Markdown.

COPY THIS RECORD ENVELOPE EXACTLY. Do not move, rename, add, or remove any envelope field. Replace only REASON and the candidate_graphs array.

{"record_id":"pilot-001-009","category":"representative","prompt":"Cut a 45-second landscape demo down to 15 seconds, speed up the middle section, add a crossfade at the transition, and finish with a title card. Create two pacing alternatives.","constraints":{"variant_count":2,"required_effects":["timeline.trim","timeline.speed","transition.crossfade","title.card"],"forbidden_effects":[]},"capability_tags":["timeline","segment_specific","duration"],"teacher":{"provider":"devin","model":"glm-5.2","prompt_version":"discovery-v0.5","generated_at":"2026-08-09T00:00:00Z"},"raw_response":{"decision":"plan","reason":"REASON"},"candidate_graphs":[],"validation":{"status":"pending","validator_version":"studio-core-v1","findings":[]},"human_review":{"status":"pending","notes":""}}

Insert exactly two graphs. Each graph uses exactly: schema_version integer 1; UUID id; nonempty label; nonempty difference_summary; provenance object {"kind":"local_model","name":"Devin GLM-5.2","version":"discovery-v0.5"}; output object {"aspect_ratio":"16:9","width":1920,"height":1080,"fps":30}; timeline array.

Each timeline contains segments 0–5, 5–10, 10–15. Every segment has UUID id, numeric start/end, and effects array. Every effect has UUID id, registered type, parameters object, and Boolean required. Use timeline.trim with {}, timeline.speed only in the middle with rate 1.5 or 2.0, transition.crossfade with duration 0.5, and title.card at the end with text only. Never put duration on title.card.

RETURN:
One compact JSON line only. Before returning, confirm capability_tags is a sibling immediately after constraints, not inside it.
