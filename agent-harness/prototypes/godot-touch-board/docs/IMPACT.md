# Actual combat-impact checkpoint

Base8a017da. The prior version committed canonical damage on release but used independent0.36–0.52s ribbons, per-panel enemy reactions, generic clear tones and a finish number. The baked dragon only had a faint whole-stage tint. Those events did not communicate one coherent delivered attack.

## Implemented

Canonical rules/damage still commit once on release, preserving planner equality, outcome ordering and game RNG. Only presented enemy HP waits for a single action-impact event at the existing clear-duration/refill onset, then depletes over0.14s. This event drives the exact committed damage number, optional weakness bonus, stage-local recoil/flash, contact rays/ring and a cached impact sound. It never owns phase, physics, timers or readiness gates. The existing serial clear schedule and bounded refill limit are unchanged.

All eligible removed objects send damage energy except hearts, which send separate pink healing cues to the hero and show effective/overflow figures. Conversion itself produces no hit. Core delivery is heavier and actual core activation or long-clear metadata selects impact intensity; weakness has a distinct accent. No damage multiplier or fabricated skill damage was added. Conversion-link copy requires an actually color-changed ID that participates as an ordinary panel in the next clear and was not re-converted by a core. Merely using a skill cannot claim an unrelated clear.

Early enemies recoil and briefly brighten as their illustrated sprite. The final dragon uses a bounded91-vertex deformation/flash around the drawn head/neck; the surrounding arena remains fixed. This is a local illustrated reaction, not separate animated wings or a rigged dragon. Existing counter HUD was moved left at the same size to keep the boss-bound delivery route and head impact visible. Board coordinates/hit transforms remain unchanged.

Six original synthesized impact variants (small/long/core × weakness) are prepared before interaction and share the existing six audio voices. Panel tones and landing audio remain. The top 효과/절제 control reduces movement/flashes/rings/particles and freezes readiness pulsing while retaining exact numbers and clear feedback. It does not consume an action; its preference survives run reset. Existing mute is preserved.

## Verification and failures retained

New pure sync/audio tests and real-controller fixtures cover exact base+weakness figures, displayed HP hold/depletion, one-shot delivery, duplicate reachability/releases, heart-only clear, conversion, real ready timing, reduced effects, reset and new-encounter cleanup, third-action lethal priority, single reward and modal passthrough. Existing38 core scripts pass. Native360x640 and390x844 OS-pointer fixtures each pass57 checks, including effect control, mute, skill/cancel, modal/detail/restart. These injected acceptance states are explicitly separate from the ordinary native run.

The before/after ordinary captures use the same initial seed and policy, normal skill charge, earned rewards, route/shop choices and natural refill, without forced boards/HP/resources. Both reach victory in16 clears with HP24. Actual baseline and current clear plans/state are compared separately from visual HP.

Initial failures remain in `evidence/impact/`: a test's statically bound new signature initially failed parsing, then its dynamic baseline check correctly failed for the missing shared-impact behavior. A review found the unproven conversion-link label and it was fixed with RED/GREEN assertions. Native boss capture exposed a prematurely freed local mesh; the renderer pixel regression failed207 samples/mesh-null errors and passed0 after retaining the bounded mesh resource. Initial broken-boss evidence is not the final video. The old per-burst-hit assertion was updated intentionally; one rerun omitted the original --sandbox fixture flag, failed its starting-HP assumption, and was rerun correctly. None of these failures was reported as a successful final run.

Fixed30fps audio captures and screenshots demonstrate presentation, not native speed or hardware latency. Dedicated native comparisons exclude policy search, screenshots and file writes from measured interaction windows. See `evidence/impact/native-performance.json` for the actual sample distributions and caveats. Cloud llvmpipe is not mobile hardware, and audio stream verification is not physical-device listening validation. No current Windows/Web build, deployment, portrait retry or purchased asset was added. Existing older ZIPs remain historical.

A narrow seed23 inlet fix remains in place with its exact regression. Passing these runs does not prove every future refill or rare latency outlier is resolved. Human impact/fun assessment and final game completeness remain unverified. Missing systems and the next bounded run-completeness proposal are in `SYSTEMS_STATUS.md`; no character-selection or content expansion was added here.

## Native timing sample

One serial before/after pair, identical16-action recorded input and physics tick profiles, completed with identical final canonical state. Baseline/updated board press→first draw median18.574/19.535ms, maxima45.796/28.853ms (22 inputs each). Ordinary clear→ready median0.813/0.864s; updated range0.658–1.515s (15 samples). One core-clear sample1.102/1.144s. Updated ordinary median was51ms higher in this sample; this is not called parity or an optimization. More repeats/device runs would be needed to attribute that difference or rule out rare tails.

Clear-animation frame median19.648/19.233ms and fall-frame median24.441/23.574ms; corresponding main process command CPU medians0.634/0.631ms and7.002/6.386ms. These mixed distributions from one pair do not establish a speedup. UI command CPU during clear0.314/0.328ms. The implementation adds no gameplay wait, but display/audio/render work still has cost. The0.6–1.0s ordinary-clear target is not met for all samples. The fixed-frame video ran slower than real time while rendering/encoding and is not used as speed evidence.

## Delivery evidence

- `evidence/impact/combat-hit-before.mp4` and `combat-hit-after.mp4`: matching19-second excerpts from normal runs (first attacks/weakness, long clear/core, boss conversion chain, readable victory hold). H264720x1080/30fps +AAC48kHz. Both final frames were checked; no gray shutdown screen. The after audio is non-silent, peak−10.0dB versus baseline−12.8dB; this is a stream check, not physical listening approval.
- `after/capture-20261021-elite-pair0-intent-aware-movie/`: full16-action ordinary trace and actual hit stills; `boss-flight.png`/`basic-flight.png` show delivery in transit. The previous HUD-obstructed take is not the final clip. Before/after clear plans match exactly.
- `final-regression/results.json`:38 scripts,0failures/errors. `hit-render-green.log`:0mismatched samples, no mesh-null errors. Full native small-window fixtures57checks each; post-HUD effects/controls24checks each.
- `independent-review.md`: source and actual pixel review, including the found/fixed causal-label and HUD-occlusion issues. No claim of commercial quality or human-fun validation.
- `native-performance.json`, compressed raw samples and `SHA256SUMS`; `tests/impact_performance_prepare.py` recreates the two isolated timing copies. Original historical evidence is preserved; regenerated test outputs are archived separately here.
