# Amethyst playable battle checkpoint

Base6366d33. This pass integrates separate original dragon-arena and gold/amethyst skill-button PNGs into the actual game, with a large upper battle stage, compact real enemy HP/weakness/intent, dark natural-contact board and bottom hero/skill/relic dock. Dragon artwork is restricted to the final encounter; the earlier golem remains identifiable, with elite labeling. The reference concept is not a runtime background or a source of fake statistics. No dragon wing animation is claimed.

The same skill-button geometry is lit only when the actual skill is available, labeled 준비; unavailable states are dim and display the current charge/requirement, including Ash2. Targeting, cancellation and detail modals do not create readiness or activate the cut-in. The temporary original portrait remains bottom-only except the successful-use footer cut-in. Element colors, counts, damage, growth, route/shop economy, contact rules and gravity were preserved. Board display translation is separate from unchanged logical physics bounds, with uniform invertible mapping for input.

## Original assets and remaining blocker

`assets/premium/PROVENANCE.json` records exact supplied File Service/Library references, versions, SHA256 and unchanged PNG originals. The approved concept original is in `references/premium/` and excluded from export. Sources are project-specific built-in image generation supplied by the parent; no purchased or copied commercial assets were added. Existing OFL fonts/notices remain unchanged.

Three supplied originals successfully materialized through the official unchanged helper reused within this continuous request. The fourth, `alchemist-portrait-amethyst-v2.png` (`libfile_975a958b5f2881918953d4f67816a6a2`, `file_00000000ebdc820e914510616cbd2fff`, version0), failed both permitted attempts: helper exit1, `library file transfer failed: download failed`, host `sdmntprbrazilsouth.oaiusercontent.com`. The explicit consumer destination `/workspace/chroma-premium-downloads/alchemist-portrait-amethyst-v2.png` is absent. This is a failed transfer, not a pending or uncertain write. No guessed URL, alternate transfer route or additional retry was used. Parent expressly authorized the already present original portrait temporarily; it is not the new violet portrait.

## Evidence

- `evidence/premium/regression-results.json`:34 scripts passed, covering existing rules, growth, combat, route/shop, elements, boss, cancellation/modals, contacts, intermediate paths and repeat refills, plus new art/layout/skill-state checks. Intentional assertions tied to old display geometry were updated; original failures remain in separately named logs. New mapping suite2677 checks, skill-state31, art12.
- Native OS pointer fixtures at360x640 and390x844:50 checks each, zero failures; ready, charging3/2, targeting/cancel, reward press, shop, relic details, victory/defeat. These controlled state fixtures are separate from ordinary gameplay. Corrected aspect-preserving activation crops were captured again afterwards at both sizes (17 checks each, zero failures). Six affected suites were rerun after the final visual text/crop corrections and passed; the cached-frame renderer check also passed.
- `before-6366-ready.png` and `before-6366-charging.png` are freshly captured saved-baseline6366 screens using the same ordinary initial skill sequence. `ready-first-actual.png` and `charging-first-actual.png`: ordinary initial scene and a successfully executed real skill, no board/HP/charge injection. Charge3/3→0/3 with no clear consumed.
- `capture-20261021-elite-pair0-intent-aware-movie/`: actual ordinary15-clear run, one initial seed, elite route, two rewards, both shop purchases, counterattacks and final victory; HP20, three relics,12 gold spent/0 left. Policy search selects legal actions, not fixture-injected boards or forced charge. The final `chroma-amethyst-playable.mp4` is63.1s H264720x1080/30fps with AAC48kHz audio (9,626,955bytes). The last frame is held victory, not a gray exit. Audio stream is present and non-silent (mean−36.4dB, peak−12.8dB), not a physical listening-quality test. The fixed30fps audiovisual movie is evidence of the rendered sequence, not live speed.
- `independent-review.md`: code and actual reference/720/small-window visual comparison. Composition is materially different; temporary portrait and remaining concept/detail gap are explicit. It is not commercial-quality approval or human-fun validation.

## Real native timing, separate from capture

`native-performance.json` and compressed raw runs compare saved6366d33 against current artwork/layout in serial native Godot4.6.3 llvmpipe runs with preloaded identical inputs. Screenshot/file I/O and policy search are excluded from timed windows. Both completed15 clears with identical canonical plan/state rows, final state and deterministic physics tick profiles. Both use the same0.8s route/shop transition hold for the unchanged500ms stale-release guard. The initial shorter-hold attempt is retained separately as an ignored guarded input, not a physics failure, defeat or completed run.

| Metric | Before | Amethyst |
|---|---:|---:|
|Board press→first draw, median / max|19.639 /21.366ms|18.882 /22.285ms|
|Ordinary clear→ready, median / range|1.170 /0.675–1.406s|1.168 /0.674–1.418s|
|Core clear→ready, median / max (2 samples)|1.300 /1.492s|1.305 /1.501s|
|Idle frame, median (24 intervals)|19.996ms|16.748ms|
|Idle software GL timer, median|11.872ms|13.473ms|

One run per version cannot establish statistical performance parity or a speedup. Frame-aligned programmatic input does not establish actual OS touch latency; cloud software GL is not a mobile GPU. The GL timer can lag a frame. Ordinary clear0.6–1.0s target remains unmet on some clears. Prior rare long-tail latency remains unproven, not erased by this sample. No Android/iOS physical device, current Windows/Web package or physical audio-device validation was performed. Existing older ZIPs are not this version.

The seed23 elite adversarial clear20 refill stall remains unresolved and preserved in `evidence/balance/stall-reproduction/`. No physics coefficients, readiness criteria, timeout or hidden repositioning changed to conceal it. Visual quality and readability were reviewed, but this checkpoint is not final art, validated difficulty or commercial-quality certification.
