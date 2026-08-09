GOAL:
Return exactly two semantic-plan JSONL records, one for pilot-001-001 and one for pilot-001-002. Do not use tools or Markdown.

Exact top-level keys: record_id, decision, reason, variants. Exact variant keys: label, output, effects. Each effect has type plus only meaningful parameters. No UUIDs, timelines, dimensions, provenance, or metadata.

pilot-001-001 must be a plan with exactly 3 vertical variants:
1. cel-shaded anime; 2. comic-book; 3. clean original with background replacement.
Every variant MUST include crop.auto_subject, caption.dynamic, and beat.flash. Variant 1 MUST include style.cel. Variant 2 MUST include style.comic. Variant 3 MUST include background.replace.

pilot-001-002 must be a plan with exactly 2 landscape variants. Both variants MUST include style.cinematic, audio.normalize, and color.grade. Only variant 2 includes title.card. Neither may include style.anime or style.comic.

Parameter law: style strength 0...1; color.grade and beat.flash intensity 0...1; crop.auto_subject may use target; text/preset may be used for captions, titles, and background replacement.

RETURN:
Two compact JSON objects separated by one newline and nothing else.
