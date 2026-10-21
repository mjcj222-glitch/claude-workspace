# Seed23 refill correctness follow-through

Basead114ff5. Fixed the archived seed20261023 elite/adversarial clear20 refill in the saved checkpoint. The original archive and its historical UNRESOLVED status remain untouched. This is not a balance, UI or broader physics redesign.

## Cause and minimal correction

The exact before run restores `survivors_before_refill`, `session_next_id` and the int64 `rng_state_before_motion` from `evidence/balance/stall-reproduction/state.var`. It consumes the identical pending colors/RNG, and the diagnostic verifies final panel dictionaries equal the archived stalled state, including positions and velocities.

At0.491667s the best instantaneous inlet was the right wall,x653, with first-hit center height332.872. Its surface was ID248, already rising at−0.776px/s and not anchored. ID255 spawned above the board at0.5s and entered normally. Subsequent contact moved248 right by~10px/up~3.3px; wall-bound255 rose fromy329.47 at0.7s toy326.19 by1s. It ended with top289.21, outside the290 boundary. All bodies had briefly been inside at0.7333s; this is re-extrusion after entry, not a full-board capacity problem or a missing pending spawn. Readiness correctly remained false.

`Motion._spawn` now tracks the actual first-hit surface of each current inlet and skips it while that surface's vertical velocity is negative. Other current inlets continue to compete; stationary and descending surfaces remain eligible. The corrected255 enters atx378.3125 at the same0.5s, via the top. No survivor position or velocity is forcibly reassigned, and no future destination is planned. RNG consumption, body size, gravity, speed, collision solver/order, contact tolerance, readiness condition and4s timeout are unchanged. There is no requirement that the whole board settle before supplying a new panel.

## RED → GREEN

`tests/test_balance_refill.gd` first failed on original source: rising-surface admission, unresolved4.008333s refill and outside255. A preliminary lateral assertion incorrectly rejected existing post-contact inertia; that test error and its original log are retained. The corrected assertion distinguishes inertial movement, current collision and walls from unexplained displacement. Before production edits it still failed for the intended admission/containment reasons.

After the minimal admission correction, the exact checkpoint reaches ready at0.991667 simulated seconds, all48 inside, pending0. Newborns enter from above. Maximum intermediate overlap0.102013px, swept overlap0.113281px and per-substep travel9.18127px are unchanged from the red path maxima; unexplained lateral movement0. The final ready board has a continuous downward contact path from every body to the floor. These are fixed-step simulation results, not real-time interaction speed. The complete board was resolved physically; readiness tolerances were not relaxed.

Evidence: `evidence/refill-stall/exact-red.json`, `exact-green.json`, lossless frame `.var` files, original `probe-before.json`, and `independent-review.md`. The five-second `refill-fixture-comparison.mp4` is explicitly a stored-state diagnostic, with fixed30fps playback of120Hz frames; it is not normal play or a performance benchmark.

## Full sequence and regressions

- 35 core regression scripts passed, including original rules, growth, input/cancellation, route/shop, elements, boss, premium presentation and motion/path/refill cases. `regression/results.json` records every command/result. The strengthened exact ready-support assertion passed again afterwards.
- Strict archived input replay completed5 clears, then changed actual contacts at action6: ID110 removes[110,115,113], while the old recording also removed129. The old20-action sequence is therefore **inconclusive**, not represented as an identical replay victory. No old group, board, charge or health was forced to continue it.
- Seven fresh ordinary runs had no incomplete outcomes or audit errors: both routes with all3 original relic pairs on seed20261021 (12–17 clears), plus seed20261023 elite/adversarial policy (17 clears, HP12, victory). They use normal initialization and legal policy-selected input, without injected intermediate state/resources. The latter is a new sequence under changed contacts, not the old20-action trace.
- Original center/left-column regression paths remain byte-identical. The2-panel case first differs at tick5/0.041667s: only newborn49's inlet changes x360→378.3125; subsequent contacts differ naturally, duration0.366667→0.416667s. The old byte-hash audit fails on that current trace, as preserved in `motion-equivalence.log`; no equality is claimed. `path-comparison.json` explains the difference and `path-audit.json` verifies containment, actual support, no floor drift, bounded intermediate overlap/swept paths and no unexplained lateral movement. The historical path file is preserved unchanged; new frames are `current-path-traces.json.gz`.

## Reproduce

Use Godot4.6.3 with writable XDG data/cache directories. In this cloud, source `/tmp/chroma-tools/env.sh` first. The initial command without that environment failed before test execution because `/home/agent/.local/share/godot` was unwritable; its crash log is retained, and no permissions or security settings were changed. The first diagnostic movie resized its viewport after writer initialization and was cropped incorrectly; startup `--resolution` did not change the project viewport used by MovieWriter either. The final take keeps the native720x1080 viewport and records the720x430 diagnostic region without changing runtime viewport geometry; FFmpeg crops that region. Failed sizing command logs are preserved.

```
godot --headless --path . --script tests/test_balance_refill.gd
godot --headless --path . --script tests/replay_balance_archive.gd
godot --headless --path . --script tests/play_refill_followthrough.gd
python tests/audit_refill_paths.py
```

The probe and archived runs are diagnostics, not human difficulty/fun or mobile performance evidence. Independent review found no blocking source defect in this narrow change; currently-rising admission alone is not a proof that every possible future jam is impossible. Horizontal support motion or later reversals remain a possible general risk. No larger recovery/repacking system was added.

No portrait download was attempted. The new violet portrait remains unavailable and the approved original temporary portrait is unchanged. Premium controls, skill/charge rules, combat, shop and weakness behavior are unchanged. Existing older executable ZIPs and the prior premium normal-play video were not rebuilt and do not establish this corrected inlet sequence.
