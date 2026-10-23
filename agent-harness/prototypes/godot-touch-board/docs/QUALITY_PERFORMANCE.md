# Quality performance follow-through

Compared86a827d (before quality), f0187ccc (saved quality checkpoint), and the retained drawing fix. This is a performance checkpoint, **not approval of commercial visual quality**. The separate approved violet/gold battle concept is not implemented here.

## Cause and change

The large board frame drew four full opaque gradients every frame, including surfaces hidden by later opaque interiors. Three isolated idle ablations removed only this frame: wall-frame medians were12.87–13.29ms without it versus20.37–26.15ms with it; software GL timer medians were9.42–9.53 versus16.79–19.41ms. This established substantial overdraw cost.

Only `scripts/board_skin.gd` changes production rendering. An opaque frame now uses one cached mesh containing its visible shadow, two perimeter bands and center, retaining the original gradient coordinates and ornaments. Cache keys include rect/tint, bounded to64 entries. Tiny/translucent-tint callers retain the old path. Three real frame shapes, including the gold portrait frame, compare to the frozen f0187ccc renderer within **one8-bit channel unit (1/255)**. Board opaque triangle area is403,584px² versus a403,872px² silhouette bound.

No physics, gravity, input transform, readiness, timeouts, damage, relics, rewards, particles, fonts or gameplay RNG changed. Current callers have opaque CanvasItem modulation. Future parent/self alpha fades need a compositing review; tint-alpha fallback does not detect inherited modulation.

## Controlled comparison

Godot4.6.3, native X11,720×1080, Mesa llvmpipe software rendering, Dummy audio; same cloud executor. Commands are preloaded from the existing legal normal run. No policy search, screenshot readback/PNG encoding or file write occurs inside measured playback; JSON is written after recording stops. Shared copies have function CPU instrumentation and in-memory frame logging, with timing stdout removed. Order: before/after/after/before/before/after, then fixed/after-control/fixed/fixed.

All10 runs have the same54 canonical gesture/resolution rows, exact clear/skill plans and physics tick/iteration/inlet profiles. Each completes15 normal clears, six skills, earned rewards/route/shop, HP20, three relics,12G spent/0 remaining and victory. No board/health/gold/charge injection. [Per-run distributions and comparison](../evidence/quality-performance/comparison.json); raw JSON remains as `.json.gz` files.

| Pooled measure | Before,3 runs | f0187ccc,4 runs | Fixed,3 runs |
|---|---:|---:|---:|
| Idle wall frame median |14.991ms|20.822ms|15.164ms|
| Idle software GL timer median |11.152ms|16.911ms|11.525ms|
| Board press→post-draw median |19.715ms|27.222ms|20.642ms|
| Press p95 |61.144ms|63.369ms|64.054ms|
| Press maximum |220.100ms|218.515ms|256.319ms|
| Presses exceeding100ms |1/63|2/84|1/63|
| Ordinary clear median |1.190s|1.200s|1.158s|
| Ordinary clear p95 |1.643s|1.492s|1.454s|

The fix recovers the persistent idle raster/frame regression and lowers typical feedback latency in this sample. It **does not fix long-tail latency or establish a general clear-speed improvement**. Clear timing varies across repeats; the0.6–1.0s target remains unmet throughout. Per-action physics CPU medians287.6/279.3/272.0ms have wide overlapping distributions and identical fixed-step work; this is not a physics optimization. More per-frame physics CPU in the slower renderer reflects ticks batched into longer frames.

UI command CPU is sub-millisecond (roughly0.4–0.6ms); planner/selection work is typically1–2ms per press. No custom shader, effect reduction or font replacement was added. The remaining256ms skill-preview outlier has1.793ms press CPU and about2ms UI/panel command CPU; those do not explain the whole gap. Driver/render-thread scheduling and first-use glyph/pipeline contributions remain unisolated. Long outliers also occur without capture/policy work.

Logging adds shared allocations; engine monitors are coarse, GL counters may lag a frame, and stage boundaries are approximate. Frame-aligned programmatic presses do not model random OS arrival. Fixed-frame holds cover different wall durations. Warm-up does not preload every future glyph/outline size. No physical-device performance or100ms guarantee is asserted. The old fixed-frame movie remains visual evidence only.

## Verification and reproduction

- Original renderer RED: cache/overdraw contract fails once as expected. Final real renderer GREEN:10 geometry/cache/pixel checks, all three comparisons within1/255.
- Existing31 rules/growth/combat/economy/input/presentation/physics regressions pass again. The legacy reward test was initially invoked in actual-run mode by mistake:11 failures are preserved in `test_reward_input-wrong-mode.log`; its documented `--sandbox` invocation then passed without production changes.
- Actual OS clicks at360×640 and390×844 each pass50 checks (36 handshake stages plus14 outcomes), including skill/charge, palette, rewards, route/shop, details/reset and terminal screens. Small ready PNGs support those input checks, not a redesign or mobile benchmark.
- [Independent source/evidence review](../evidence/quality-performance/independent-review.md): no blocking current-call correctness issue; long-tail timing and future inherited-alpha limitation remain.

Reproduce with `python tests/performance_compare.py`; import each `/tmp/chroma-performance/{before,after,fixed}` using Godot `--headless --editor --import --quit`; run serial native `godot --path <copy> --audio-driver Dummy --position 0,0 --script tests/performance_replay.gd -- --result=/tmp/chroma-performance/<label>-repeat-N.json`. Use the recorded writable XDG/display environment. `python tests/performance_report.py /tmp/chroma-performance` regenerates the report. `performance_idle.gd` is the short diagnostic; the omitted-frame variant is never product code. Pixel tests require the real renderer.

Harness bring-up caught a nested `_draw` replacement mismatch, JSON float/int comparison and a test constant colliding with native `Skin`; corrected before retained product changes. The failed initial replay is preserved as `before-0.json.gz`. Existing seed23 elite adversarial clear20/HP2 refill stall remains unresolved with unchanged serialized checksums. No timeout extension, forced movement or physics rescue. No new video is needed because appearance is preserved within1/255.
