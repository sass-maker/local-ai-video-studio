GOAL:
Convert each of the ten editing requests below into one semantic-plan JSON object. Return exactly ten JSONL lines in input order. Do not use tools or Markdown.

EXACT SCHEMA:
{"record_id":"case-01","decision":"plan","reason":"short sentence","variants":[{"label":"Soft anime","output":"vertical","effects":[{"type":"style.anime","strength":0.5},{"type":"crop.auto_subject"}]}]}

RULES:
- Top-level keys are exactly record_id, decision, reason, variants.
- decision is plan, clarify, or unsupported.
- A plan has 2–5 variants as requested. Clarify/unsupported has an empty variants array.
- Each variant has exactly label, output, effects.
- output is vertical, landscape, square, or source.
- Each effect must contain type and may contain only strength, intensity, rate, duration, target, preset, text.
- No UUIDs, schema versions, resolutions, FPS, provenance, timelines, hashes, or implementation metadata.
- Supported effects only: crop.auto_subject, frame.resize, timeline.trim, timeline.speed, caption.dynamic, title.card, transition.crossfade, color.grade, audio.normalize, background.blur, background.replace, subject.outline, subject.glow, beat.flash, beat.zoom, style.anime, style.comic, style.sketch, style.watercolor, style.cel, style.cinematic, style.noir, style.vhs.
- strength/intensity 0...1; rate 0.25...4; duration 0.05...2.
- Contradictory or materially underspecified requests should clarify. Unsupported requests should be unsupported.

INPUTS:
case-01 | 3 variants | Create three vertical reels: soft anime, comic-book, and clean original with background replacement. Add bold captions and beat flashes to all three.
case-02 | 2 variants | Make two landscape cinematic interview versions. Normalize speech and add a title card only to the second.
case-03 | 5 variants | Make five sketch-style reels differing only in strength from very light to very strong.
case-04 | 2 variants | Create two clean podcast Shorts with background blur, both speakers framed, bold captions, and no style filter.
case-05 | 3 variants | Make three noir music edits with subtle, medium, and intense styling plus beat-synced zooms. Preserve original audio level.
case-06 | 3 variants | Make three variants but exactly two variants, and make every output both square and vertical.
case-07 | 2 variants | Use anime strength 1.7 and speed 8x without changing those values.
case-08 | 3 variants | Make it pop and feel expensive. Give me three options.
case-09 | 2 variants | Generate a photorealistic dragon, replace the actor with it, and give it perfect lip sync.
case-10 | 3 variants | Upload three variants to TikTok, run an A/B test for a week, and choose the winner from retention data.

VERIFY:
Exactly ten parseable JSON lines. Exact keys. Correct variant counts for plans. No unknown effects or forbidden metadata.

RETURN:
Ten compact JSON objects separated by newlines and nothing else.
