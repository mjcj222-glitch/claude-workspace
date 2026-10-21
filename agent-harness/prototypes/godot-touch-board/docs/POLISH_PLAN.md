# First-board quality pass — 2026-10-21

Baseline remote d42fd818ce4f26f97549972a81b459e7333c4fc2 confirmed.

- Root: clear timeline compression tests and implementation, main input/render coordinate integration, asset integration after parent delivery, final evidence and commit.
- Visuals agent: new board_ui.gd only, compact HUD and conditional skill-color palette; no original asset generation.
- Render_env agent: read-only exact-semantic motion CPU review; no parallel benchmarks.
- Independent review: final source read and targeted checks.

Keep physics BOARD/radius/IDs/rules, full visible body extent, collision trajectories and top inlet. Translate board for layout with matching input coordinate conversion; do not fill empty space by moving bodies. Shorten only excessive serial clear animation after preview commits, with deterministic order and all effects accounted for before refill. Measure ordinary and long chain separately, including clear/fall wall times and motion CPU/supply/quiet phases.

Validate rules, input/cancellation/multitouch, preview=release, path golden equivalence, ten refills, layout hit regions and hidden palette. Capture first UI even before original character/target assets arrive; label placeholders. Final screenshot/audio movie are separate from live benchmark and human/real-device judgement. No Windows builds or new content.
