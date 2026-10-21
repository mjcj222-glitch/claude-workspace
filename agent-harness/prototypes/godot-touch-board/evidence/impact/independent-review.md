# Independent combat-hit integration review

Reviewed IMPACT_PLAN, current main/quality_fx/art/audio/UI/feedback changes and test_hit_sync source. No production edits, Godot runs or CPU-heavy checks were performed. Actual render/input/audio evidence is still pending.

## Initial material finding (resolved below)

`board_quality_fx.action_started` sets skill_link from `_skill_primed && damage_amount>0`, without checking the committed skill targets or their participation in the removed group. Reproduction: successfully convert a left-side group, then clear an unrelated existing right-side group of six or more normals. The next damaging action receives the causal `변환 연계` label despite being unrelated. The approved contract calls for actual skill-created connections. Track committed conversion provenance and qualify the removed/connected result, or omit the causal label when unproven. Parent was notified promptly. This affects presentation truth, not damage arithmetic.

## Other inspected paths

No duplicate canonical-damage application found: session commits immediately and FX only copies damage/base/weakness plus pre-hit HP. Display HP uses a separate hold and0.14-second interpolation; it does not call combat or change readiness. One pending impact is consumed once; reset/new encounter clear it. The existing clear duration triggers action_finished, followed by FX update/take_impact without await or a new refill gate. Heart-only actions and conversion do not emit enemy impacts. Eligible actual IDs and activated core kinds are deduplicated.

Attack trails target the encounter-specific impact point, hearts target the hero, and core trails have an explicit larger marker. Dragon response uses a local weighted91-vertex deformation of the baked texture, not an articulated dragon or full-arena displacement. Six cached impact streams share the existing six voices, reset per-voice volume for ordinary tones, and honor the existing mute flag. PCM caching is visible in source; audible quality has not been assessed.

Reduced mode suppresses enemy recoil/flash and detailed feedback particles/rings while retaining damage/HP information and subdued cues. The new toggle returns immediately and checks selection/modal/detail pointer ownership; screen-touch routing already rejects extra fingers. Modal/detail surfaces draw after FX and reset/new-fight cleanup is retained. Full reduced-mode lifecycle, modal transitions, held/canceled input and actual visual legibility still need integration/capture evidence. The dynamic dragon mesh allocates per active-hit frame; bounded duration/vertex count does not itself establish performance parity.

The pure hit test covers displayed-HP hold, event deduplication, immutable plan, heart/skill exclusion and reset. It does not currently prove related versus unrelated post-skill clears, and real controller death/reward/transition input tests remain separate. No optional redesign requested.

## Causality and renderer correction follow-up

The earlier unrelated-clear label finding is resolved in current source. Main compares original visual colors with the committed skill conversion map and passes only actually changed IDs/colors. FX deep-copies that provenance; its next clear must remove a participating normal of that tracked effective color, and a core-converted ID is excluded. The map is consumed by the clear and cleared on reset/new encounter. Unrelated/no-change skill targets no longer assert a causal link. Inspected skill-causality-green.log reports HIT_SYNC failures=0. This is conservative participation attribution, not a claim that every later clear involving those colors was created by the skill.

The local temporary dragon mesh was replaced with a retained static ArrayMesh reference, addressing its lifetime across deferred canvas drawing. Inspected hit-render-green.log reports0 mismatched samples; viewed dragon-render-check.png, where the retained undeformed mesh visibly matches the reference texture region. The pixel probe samples a regular grid at zero displacement/flash; it establishes the repaired render path, not final animated hit quality or a full-image equivalence guarantee. The initial broken boss film is explicitly not approved and must not serve as final evidence. Regenerated live hit frames and final captures remain pending. No source edits or test executions by this reviewer.

## Actual corrected normal-hit pixel review

Viewed after hit-01/05/11/16 and matched before hit-01/11 from the actual normal movie captures. Dragon rendering is restored, impact numbers now sit at the actual head target, weakness/core/converted-participation labels are legible, and displayed HP is visibly in its intended depletion interval rather than already committed before impact. Still samples alone cannot prove full projectile flight timing or sound synchronization.

One material composition obstruction remains: the existing destruction counter at(392,174),304x94 lies just12px below the boss target(548,162). It covers the last upward approach corridor, lower impact-ring region and dragon neck. In hit11/16 the number is visible above it but the lower local response is obscured. This directly weakens the requested energy-delivery/impact feedback, so a bounded counter relocation within the stage is justified (for example a left-stage position preserving its existing size and keeping the combat rail/board untouched). No general visual redesign or new effects are requested. Parent notified; pixel acceptance of this path remains pending that resolution or equivalent unobstructed evidence.

Causality/reset code finding remains resolved; no new duplicate-damage/readiness/input blocker found. Full native performance and small-window OS evidence are still separate pending checks.

## Final relocated-HUD acceptance

Directly viewed final boss-flight.png, basic-flight.png and regenerated normal hit-01/05/11/16. The counter now occupies the left stage at its existing size. The boss approach corridor and head/neck target are clear of the counter; the localized impact, damage number and weakness/conversion labels remain visible. The golem target and central impact ring are also visible, although the counter still overlaps the left edge of its illustration. That residual illustration overlap does not hide the destination or hit information and is not a blocker for this bounded pass. The earlier right-side obstruction finding is closed. No further visual change requested.

Source review status remains: the causal-label guard and retained-mesh correction are accepted, with no identified duplicate damage, stale reset effect, modal input passthrough or readiness-gating blocker in inspected paths. Directly inspected final-regression/results.json: all 38 scripts have exit 0 and empty error arrays. Inspected windows logs: full OS checks 57/57 and post-relocation effects checks 24/24 pass at both 360x640 and 390x844. These are existing execution logs, not test runs by this reviewer.

Directly inspected native-performance.json (the available final comparison artifact): the single native comparison reports identical canonical rows and physics profiles, but press median rose from 18.574 to 19.535 ms and ordinary-clear median from 0.813 to 0.864 s. This evidence does not establish performance parity or a general latency guarantee. The final before/after clips and nonzero AAC measurements are retained as delivery evidence; this review inspected actual captured stills, not full real-time playback or audio on a physical device. No claim of commercial quality, perceived fun, audible mix quality or complete motion synchronization follows from this pixel spot-check. No remaining blocking finding from this review; production and test execution remained untouched.
