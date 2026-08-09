GOAL:
Repair exactly two JSONL records, pilot-001-006 and pilot-001-009. Return two lines only. Do not use tools.

The previous graphs decoded structurally but failed the application validator because `title.card` used a `duration` parameter. Regenerate both records using the exact v0.2 record and graph contract below.

PARAMETER LAW (STRICT):
- strength: ONLY style.anime, style.comic, style.sketch, style.watercolor, style.cel, style.cinematic, style.noir, style.vhs, background.blur, subject.outline, subject.glow.
- intensity: ONLY beat.flash, beat.zoom, color.grade.
- rate: ONLY timeline.speed.
- duration: ONLY transition.crossfade.
- title.card may use text or preset, NEVER duration.
- timeline.trim uses no numeric parameter; segment start/end expresses the interval.

Each line includes record_id, category, prompt, constraints, capability_tags, teacher, raw_response, candidate_graphs, validation, human_review. teacher uses Devin/glm-5.2/discovery-v0.3. raw_response has only decision and reason. Graph shape is exactly schema_version,id,label,difference_summary,provenance,output,timeline; timeline is directly an array. Segment shape is id,start,end,effects. Effect shape is id,type,parameters,required. All graph/segment/effect IDs are canonical UUIDs. provenance is local_model / Devin GLM-5.2 / discovery-v0.3. validation is pending/studio-core-v1/[]; human_review is pending/empty notes.

INPUTS:
{"record_id":"pilot-001-006","category":"representative","prompt":"Produce three retro VHS product-demo cuts with different speeds. Add an opening title and normalize the voiceover, but do not add subtitles.","constraints":{"variant_count":3,"required_effects":["style.vhs","timeline.speed","title.card","audio.normalize"],"forbidden_effects":["caption.dynamic"]},"capability_tags":["vhs","speed","title","forbidden_caption"]}
{"record_id":"pilot-001-009","category":"representative","prompt":"Cut a 45-second landscape demo down to 15 seconds, speed up the middle section, add a crossfade at the transition, and finish with a title card. Create two pacing alternatives.","constraints":{"variant_count":2,"required_effects":["timeline.trim","timeline.speed","transition.crossfade","title.card"],"forbidden_effects":[]},"capability_tags":["timeline","segment_specific","duration"]}

VERIFY:
Two JSONL lines only; 3 and 2 graphs; timelines are arrays; UUIDs valid; title.card has no duration; only transition.crossfade has duration; no caption.dynamic.
