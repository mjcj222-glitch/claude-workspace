# Quality performance follow-through

Goal: compare 86a827d and f0187ccc using the same pre-recorded legal input sequence, without policy search, screenshot readback, PNG encoding or disk writes inside timed windows. Preserve the chosen visuals and every gameplay/physics/readiness rule. The seed23 elite adversarial refill stall is separate and remains unresolved.

- [x] Prepare isolated copies of the two commits and a shared replay/instrumentation harness. Preload the recorded commands; write JSON only after the run. Alternate at least three runs per version in the same native environment. Measure accepted press CPU and first rendered feedback, clear/physics components, idle/selection/effect frames and render-command CPU separately. Distinguish initial glyph warm-up from repeated state rendering.
- [x] Verify canonical plan/event equality before interpreting timing. Identify a reproducible hotspot with distributions; test a single visual-only hypothesis if supported. Avoid physics, timeouts, readiness changes or arbitrary effect reductions.
- [x] For any retained fix, add a failing regression first, verify unchanged pixels and behavior, run the existing suite, repeat the controlled comparison and obtain independent review. Report noisy/non-improving results without asserting a speedup.
- [x] Save raw samples, method/limitations and verified PR3 commit. Update image/video only if appearance changes.

Files: tests/performance_replay.gd and tests/performance_compare.py own isolated measurement; evidence/quality-performance owns raw reports; a production change will be confined to a demonstrated drawing hotspot. No screenshot or policy work runs concurrently with measured playback.

Outcome: cached opaque frame geometry retained; repeat data, regressions, native small-window checks and independent review complete. Final commit/remote verification is recorded in the handoff. Long-tail latency and the old seed23 stall remain unresolved.
