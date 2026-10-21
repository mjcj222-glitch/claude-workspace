# Independent visual performance follow-through review

Reviewed the isolated measurement harness, f0187ccc versus86a827d drawing changes, the single board_skin.frame_mesh fix and its pixel/area test, and final comparison.json. No Godot/test/benchmark process was launched by this reviewer. Production code was not edited; this report is the only deliverable written.

## Finding and fix

No blocking correctness defect found in the current opaque UI callers. The measured ablation supports the large board frame as a material contributor: removing that frame from an isolated control reduces idle llvmpipe GL timer medians from roughly16.8–19.6ms to9.4–9.5ms across three runs. Production does not remove the frame or change its design; it caches visible geometry, replacing four full opaque surfaces with visible shadow, perimeter rings and center. Original per-surface vertical gradients and ornaments are retained. Transparent tint/tiny rectangles keep the original drawing path.

The cache includes rect position/size and tint, is bounded at64 entries, and returns reusable ArrayMesh resources. Current stable UI geometry does not suggest eviction churn. The test verifies reuse, bounded triangle area and rendered channel error<=1 against the frozen reference for three real rects. Area bounded by the enclosing rectangle alone is not a complete nonoverlap proof; source geometry plus pixel comparison provide the complementary evidence. Coordinator reports the existing10-check pixel suite green; additional gold-tint rerun was pending at handoff and is not independently claimed here.

Future limitation: CanvasItem/ancestor alpha modulation is not covered by the tint.a fallback. Fading an otherwise opaque cached frame would differ from compositing the old overlapping surfaces. No such modulation exists in the inspected current UI/scene paths; this is not a present blocker. Future translucent usage must preserve original compositing or explicitly adopt a new visual contract.

## Controlled evidence

The shared harness replays recorded legal commands without policy search, screenshots or file output during measurement. Instrumentation is identical in isolated copies. Final comparison includes3 old,4 quality,3 fixed normal runs. All ten entries report equal canonical rows and equal physics tick profiles with errors=[]; coordinator records54 rows per run and unchanged final15 clears/HP20/three relic victory. This supports that replay, not universal behavior equivalence.

| Pooled measurement | Old86a827d | Qualityf0187ccc | Fixed |
|---|---:|---:|---:|
| Board press-to-first-draw median(ms) |19.715|27.222|20.642|
| p95(ms) |61.144|63.369|64.054|
| Maximum(ms) |220.100|218.515|256.319|
| Samples>100ms |1/63|2/84|1/63|
| Idle GL timer median(ms) |11.152|16.911|11.525|
| Idle wall frame median(ms) |14.991|20.822|15.164|

The fix substantially recovers the typical idle-render and first-feedback regression in this environment while retaining the visual design. It does not improve the measured tail: fixed p95 is slightly higher and maximum is256ms. There is no universal under100ms guarantee. Ordinary-clear medians near1.190/1.200/1.158seconds have mixed wide distributions and do not justify a clear-speedup claim. Physics/readiness/timeouts were not tuned, and the separate seed23 motion stall remains unresolved and preserved.

## Measurement limits and disposition

Inputs are frame-aligned programmatic calls, not real OS-touch arrival. Fixed-frame holds have different wall durations at different FPS and can cover different effect ages. GL counters may lag and are software llvmpipe values, not device GPU performance. In-memory logging/wrappers add common overhead; warmup does not prewarm every later glyph/outline. Pooled frames are correlated observations from a small number of runs, not independent statistical trials. These controls improve on the earlier capture-heavy comparison but do not identify the rare outlier cause or establish mobile performance.

Accept the bounded geometry optimization as an evidence-supported performance correction for the current prototype. Preserve the tail-latency limitation and known physical stall explicitly. This is neither commercial visual-quality approval nor certification that response-time goals are met. No redesign, blind effect reduction, or further optional benchmark loop is requested. Root's final serial regression run remains separate from this review.
