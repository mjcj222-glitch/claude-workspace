# Checkpoint B: actual controller evidence

[Controlled fixture movie](checkpoint-b-fixtures.mp4) · [Ordinary controller movie](ordinary-controller.mp4) · [Source and file manifest](capture-manifest.json) · [Timing summary](timing-summary.json)

The fixture movie and `fixtures-movie/` stills use source `cec5b64f38fe8892411791477928c1ed29d72cdf`. They explicitly label controlled surface/bomb/turn setups on genuine physical poses. The real Battle controller, stored plans, combat rules and rigid bodies produce the displayed outcomes. These are controlled demonstrations, not naturally rolled expedition outcomes.

- [Direct eight plus four extra](fixtures-movie/fixture-direct8-extra4-preview.png): real held bomber portrait activation in a configured energy6/hero+bomber context pays6, leaving0. The stored plan shows damage34+3, healing3, energy4 and next blue bomb large. Actual union removes12, pending damage becomes37, pending healing3, energy becomes4, and three newborn blue bombs survive the old chain. The result accrues damage/healing before turn resolution; enemy HP168 is therefore still shown.
- [Solo bomb](fixtures-movie/fixture-solo-bomb-preview.png): `폭탄 1`, ten extra, damage0+10, energy0. Actual union removes11 and energy remains4.
- [Hero held target](fixtures-movie/fixture-hero-preview.png) and [own hero cutin](fixtures-movie/fixture-hero-cutin.png): portrait/destination/target follows the real controller interaction.
- [Strong intent weakened by42](fixtures-movie/fixture-strong-weaken42-preview.png): controlled turn4, pressure+4; real intent32 becomes20 while pressure persists. Direct damage120 and energy6 accrue after the42 union. This is a special all-board action.

`ordinary-realtime/`, `ordinary-movie/` and `ordinary-controller.mp4` retain source `4428d608a3eb0695a1728842f70c1901fa33a74c`. Those normal paths are unchanged by the subsequent transient-reset/preview-label fix. They use naturally generated boards in a configured BattleContext (gate enemy, HP60, energy4, hero), not an unmodified three-battle expedition witness. Five realtime scenarios use seeds41,73,991,20261020,121 and natural groups of4–7. The movie follows seed41's seven-piece action.

| Realtime seed | Removed | Lock simulation s | Lock wall s | Collapse s | Incoming s |
|---|---:|---:|---:|---:|---:|
|41|7|4.5667|4.5689|1.7917|2.6500|
|73|4|2.9583|2.9377|1.1750|1.6583|
|991|4|4.1917|4.1825|1.9333|2.1250|
|20261020|7|4.3333|4.3152|2.4083|1.8083|
|121|6|4.0167|3.9889|1.7833|2.1000|

Lock includes the intentional0.12s compression animation and callback alignment. Each physical phase includes the existing28-tick quiet gate, observed about0.24s after last above-threshold motion; phase summaries distinguish that tail from motion. During each physical phase, active bodies use normal dynamics with shape CCD2; final settlement freezes the board through the existing rule. These observations pass physical settlement requirements; the roughly2.94–4.57s ordinary wall locks still require visual/rhythm judgment. The continuous12s deadline is not a rhythm target.

The refreshed special42 movie lock is4.1583 simulation seconds (4.0250 incoming physical seconds, no survivor-collapse phase), wall7.9404s under Movie Maker. It must not be treated as an ordinary3–8 action measurement. The controlled12-removal and11-removal movie locks are6.0833s and5.4250s simulation respectively.

Movies are720×1280 H.264 at60fps. Fixtures:1979frames/32.9833s, capture wall79s. Ordinary:507frames/8.45s, capture wall27s. Movie Maker fixed60fps and Mesa llvmpipe rendering/capture/encoding costs affect wall time; realtime measurements use a separate graphical run without fixed-fps. Neither is mobile-device performance.

Initial/refill count, top vacancy, area coverage, overlap and support are recorded separately per seed/phase in each compact summary. The current seed121 initial top vacancy98.8525logicalpx remains visible. An earlier different capture path measured about96.56logicalpx; neither meets the internal90px initial visual hypothesis. No screenshot-specific physics tuning was applied. Natural pockets remain visible.

Every completed action records exact displayed union versus actual missing IDs, final42, support and overlap. All nine recorded actions agree. Bulk per-frame poses/velocities/modes, raw capture files and exact isolated-XDG/no-save commands are privately preserved; public summaries contain no authentication or private machine paths. This Task6 checkpoint passed independent source, visual and timing review. Tasks7–10 remain in progress. See the [dated report](../../../../../reports/2026-10-20/resonance-v2-checkpoint-b.md).
