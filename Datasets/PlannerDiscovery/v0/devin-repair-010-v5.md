GOAL:
Return one compact JSON line for pilot-001-010. Do not use tools or Markdown. Copy the record envelope exactly; replace only REASON and candidate_graphs.

{"record_id":"pilot-001-010","category":"representative","prompt":"Create three anime reel variants with recognizable faces: soft anime, cel-shaded, and anime with subject outline and glow. All need automatic vertical reframing.","constraints":{"variant_count":3,"required_effects":["crop.auto_subject","style.anime","style.cel","subject.outline","subject.glow"],"forbidden_effects":[]},"capability_tags":["face_preservation","style_comparison","compositing"],"teacher":{"provider":"devin","model":"glm-5.2","prompt_version":"discovery-v0.5","generated_at":"2026-08-09T00:00:00Z"},"raw_response":{"decision":"plan","reason":"REASON"},"candidate_graphs":[],"validation":{"status":"pending","validator_version":"studio-core-v1","findings":[]},"human_review":{"status":"pending","notes":""}}

Insert exactly three graphs: soft anime, cel-shaded, and anime with outline plus glow. Every graph must include crop.auto_subject and 9:16 1080x1920 output. Graph shape is exactly schema_version integer 1, UUID id, label, difference_summary, provenance object, output object, timeline array. provenance is {"kind":"local_model","name":"Devin GLM-5.2","version":"discovery-v0.5"}. Each segment has UUID id,start,end,effects. Each effect has UUID id,type,parameters,Boolean required.

CRITICAL PARAMETER LAW:
- style.anime and style.cel use strength 0...1.
- subject.outline uses strength 0...1, NEVER intensity.
- subject.glow uses strength 0...1, NEVER intensity.
- crop.auto_subject may use target.
- Do not use any other effects or numeric parameter names.

RETURN:
One JSON line only. Confirm capability_tags is outside constraints, timeline is an array, and all required values are Boolean.
