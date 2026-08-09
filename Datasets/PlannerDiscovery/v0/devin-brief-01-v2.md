GOAL:
Generate exactly five compact JSONL records from the embedded inputs. Your output will be decoded by Swift's `JSONDecoder` into the exact application types. Return JSONL only. Do not use tools.

SCOPE:
Each line must contain: record_id, category, prompt, constraints, capability_tags, teacher, raw_response, candidate_graphs, validation, human_review. Copy the input metadata exactly. Set teacher to {"provider":"devin","model":"glm-5.2","prompt_version":"discovery-v0.2","generated_at":"2026-08-09T00:00:00Z"}. Set raw_response to {"decision":"plan","reason":"one short sentence"}; do not duplicate graphs there. Set validation to {"status":"pending","validator_version":"studio-core-v1","findings":[]} and human_review to {"status":"pending","notes":""}.

EXACT GRAPH SHAPE:
`candidate_graphs` is an array of graphs. `timeline` is DIRECTLY AN ARRAY OF SEGMENTS. Never use a `segments` wrapper. Every graph, segment, and effect `id` must be a canonical UUID. Every object must use exactly the shown keys:

{"schema_version":1,"id":"11000000-0000-4000-8000-000000000001","label":"Example","difference_summary":"Example difference","provenance":{"kind":"local_model","name":"Devin GLM-5.2","version":"discovery-v0.2"},"output":{"aspect_ratio":"9:16","width":1080,"height":1920,"fps":30},"timeline":[{"id":"22000000-0000-4000-8000-000000000001","start":0,"end":15,"effects":[{"id":"33000000-0000-4000-8000-000000000001","type":"style.cel","parameters":{"strength":0.7},"required":true}]}]}

SUPPORTED EFFECTS:
crop.auto_subject, frame.resize, timeline.trim, timeline.speed, caption.dynamic, title.card, transition.crossfade, color.grade, audio.normalize, background.blur, background.replace, subject.outline, subject.glow, beat.flash, beat.zoom, style.anime, style.comic, style.sketch, style.watercolor, style.cel, style.cinematic, style.noir, style.vhs.

CONSTRAINTS:
Use 2–5 variants exactly as requested. `parameters` may contain only target, preset, text, strength, intensity, rate, duration. Strength/intensity are 0...1; speed rate 0.25...4; crossfade duration 0.05...2. The effect `timeline.trim` has no registered duration parameter, so express the chosen interval with segment start/end. Use one segment per graph unless timing differs. A required effect can be variant-specific: satisfy the natural-language instruction, not every effect in every graph. Do not invent a pan effect; describe subject-following reframing as crop.auto_subject only.

VERIFY:
Exactly five lines; IDs pilot-001-001 through 005; variant counts 3,2,4,3,2; `timeline` is an array in every graph; all IDs are UUIDs; only supported effects and bounded parameters; no forbidden effects.

RETURN:
Exactly five compact JSON objects separated by newlines, with no code fence or commentary.

INPUTS:
{"record_id":"pilot-001-001","category":"representative","prompt":"Create three vertical reel versions: cel-shaded anime, comic-book, and clean original with background replacement, bold captions, and beat-synced flashes.","constraints":{"variant_count":3,"required_effects":["crop.auto_subject","style.cel","style.comic","background.replace","caption.dynamic","beat.flash"],"forbidden_effects":[]},"capability_tags":["multi_variant","vertical","style","background","captions","beat"]}
{"record_id":"pilot-001-002","category":"representative","prompt":"Make two 16:9 cinematic variants of this interview. Keep faces natural, normalize speech, use restrained color grades, and add a title card only to the second version.","constraints":{"variant_count":2,"required_effects":["style.cinematic","audio.normalize","color.grade","title.card"],"forbidden_effects":["style.anime","style.comic"]},"capability_tags":["landscape","interview","audio","variant_specific"]}
{"record_id":"pilot-001-003","category":"representative","prompt":"Create four square teasers with different opening hooks, dynamic captions, subject tracking, and progressively faster pacing. Keep each under 20 seconds.","constraints":{"variant_count":4,"required_effects":["caption.dynamic","crop.auto_subject","timeline.trim","timeline.speed"],"forbidden_effects":[]},"capability_tags":["square","hooks","duration","pacing"]}
{"record_id":"pilot-001-004","category":"representative","prompt":"Turn the music performance into three noir versions: subtle, medium, and intense. Sync zooms to the beat and preserve the original audio level.","constraints":{"variant_count":3,"required_effects":["style.noir","beat.zoom"],"forbidden_effects":["audio.normalize"]},"capability_tags":["intensity_ladder","music","beat","negative_constraint"]}
{"record_id":"pilot-001-005","category":"representative","prompt":"Make two watercolor travel edits, one vertical and one landscape, with gentle crossfades and slow pans around the primary person.","constraints":{"variant_count":2,"required_effects":["style.watercolor","transition.crossfade","crop.auto_subject"],"forbidden_effects":[]},"capability_tags":["mixed_output_profiles","transition","reframing"]}
