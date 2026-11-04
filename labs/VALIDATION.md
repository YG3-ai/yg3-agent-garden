# Public snapshot validation

Checked on Windows with Godot 4.7.2 and an RTX 5080 on 2026-11-04:

- Existing repository tests: 10/10 passed.
- Home and showroom dependencies install independently with their pinned lockfiles.
- Home walking worker imports the separately prepared apartment, builds 241 static colliders and reports `HOME_READY`.
- Showroom worker imports separately prepared assets and reports `SHOWROOM_READY wheels=4`.
- Navigation creates its posed collision cache from a fresh public checkout layout: 94 colliders, 66 character bones, horizontal animation-root travel locked.
- Manual movement smoke check passes floor settling, forward motion, animation and wall blocking.
- Navigation mesh rebuild produces 226 polygons / 238 vertices.
- Included FFN reaches the illustrative `test-0005` destination in 10.72 simulated seconds from the public folder layout, matching the original result. The full 50-episode measurements were made before the public path cleanup, not remeasured here.
- JSON parsing, Python compilation, JavaScript syntax and PowerShell launcher parsing pass. Local Markdown links resolve. Staged files contain no GLBs, textures, geometry caches, raw image sessions, machine-specific user paths or detected credential patterns.
- Published navigation MP4 is byte-identical to the locally reviewed 13.12-second recording.

No new Codex recording was launched for these publication checks. Home/showroom video editors require the historical capture sequences and Windows fonts, so exact social-edit regeneration was not tested from this source-only snapshot. Whole navigation retraining was not repeated for the path cleanup. The inherited dependency lockfiles also retain npm's existing moderate-severity audit finding; dependency upgrades are outside this publication change.
