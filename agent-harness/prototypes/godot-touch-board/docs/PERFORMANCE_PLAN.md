# Motion performance pass — 2026-10-21

Scope: instrument current motion/scene and deterministic benchmark; optimize only measured computation while preserving gravity, contacts, inlet, order, and readiness. No design/content/build packaging changes.

1. Baseline same seeded scene and automatic input; separate clear wall time, fall wall time, solver/support/inlet CPU, supply interval, first contained state, final quiet interval. Simulation phases overlap CPU, so do not sum them as wall-time categories.
2. Inspect dominant cost. Prefer reusing invariant collision candidates/data over changing iteration cap or numerical thresholds.
3. Compare exact per-substep paths before/after, three path fixtures, ten repeated refills, rules and scene tests. Independently review optimized code.
4. Repeat live benchmark without concurrent tests or encoding. Record failure/outliers and remaining target gap; publish only to existing PR branch.

Ownership: primary edits board_motion.gd, main.gd instrumentation, benchmark and report. Independent reviewer reads only. Original game, visual assets, rules and Windows artifacts excluded.
