# Independent route/shop review

Reviewed the approved `docs/ROUTE_SHOP_PLAN.md` contract, Combat/RunSession changes, controller modal routing, UI, and the new economy/input assertions. Read-only production review; no tests launched and no production edits or commits.

## Finding and coordinator resolution

P2: The second press/release of a real mouse double-click can cross the route/shop-exit transition into a fresh board. `main.gd` commits route/exit and immediately calls `_advance_fight()`, leaving the session ready. `_input()` forwards the next left-button down regardless of `InputEventMouseButton.double_click`. If its position covers a valid group in the fresh board, the subsequent up clears it. Current input tests check duplicate releases, but not the flagged second down/up of an actual double-click. This conflicts with the contract's requirement that double-clicks not pass through into unintended clears. This is a source-level finding; it was not reproduced by launching a test during this review.

## Other reviewed behavior

No additional concrete blocker found. Per-encounter payout tracking and phase checks prevent repeated currency/rewards; safe/elite HP and all attack values match the contract. Full-HP healing, insufficient funds, and sold items return before mutation. Valid purchase applies balance/effect/stock atomically, advances the offer serial, and does not change actions, combat turn, charge, or ash reservation. Both purchase orders are supported by the session logic. Shop exit is latched and final victory pays no gold. A third relic is appended without retroactively applying its effect; later plans use normal owned-relic evaluation. Reset constructs a new session and clears controller candidates.

Visual captures and normal-flow evidence were reviewed in the follow-up below.

Coordinator verification: the departing-control mouse double-click and touch double-tap were reproduced in `transition-reentry-red.log` (4 behavioral failures). `test_transition_reentry.gd` now passes22checks with `transition-reentry-green.log` and the final suite. A500ms/44logicalpx guard suppresses only the same departing-control target; other board targets work immediately, and restart clears it. Recognized OS double-clicks at that same target are also ignored. Post-fix actual XTest route/shop windows passed44/44 at both360x640 and390x844; the legacy window passed39/39. This evidence addresses the P2. The coordinator chose this small guard rather than delaying board physics/readiness. An intentionally very fast same-location first board tap can also be ignored; this is a documented input tradeoff.

## Normal-flow visual follow-up

Independently inspected seven `capture-elite-live` screenshots: `route-offer`, `route-entered`, `shop-before`, `shop-after-relic`, `shop-after-heal`, `finalfight-entered`, and `victory`; also inspected the 360×640 route and shop OS-window captures. No essential readability, clipping, overlap, or displayed-accounting defect found. The narrow-window images are routing fixtures, not evidence of normal combat progression.

The normal route card clearly states elite HP 44, mitigation 8→4, ordinary/fallback 6, and victory 8 G; the entered fight displays HP 44/44 and 8→4. Shop screenshots show 12 G and HP 24/30 before purchase, 4 G after the 8 G ash purchase, then 0 G and HP 30/30 after the 4 G heal. The heal previews and reports the effective +6, respecting the cap. Both items visibly become sold; all three relic icons carry into the final fight. Victory clearly displays the elite route, spent 12 G, remaining 0 G, 18 clears, three relics, and HP 24/30.

Read `capture-elite-live/trace.json`: `errors=[]`, `no_fixtures=true`, terminal victory, and final values agree with the screenshots; both stock flags and `shop_closed` are true. Its method is automated legal decisions through production press/release and natural processing, not hardware touch. This follow-up did not run tests or inspect continuous video/audio; animation quality, audio synchronization, and real-time mobile performance are not established by these still images.

## Final exported-video spot-check

Decoded and visually inspected `chroma-route-shop.mp4` at 13 seconds (route), 35 seconds (shop), and its final frame. The route numbers, effective heal +6, prices, exit button, and final elite/12 G spent/0 G remaining/three-relic summary are legible with no clipping or overlap. The final frame remains the complete victory screen; there is no gray/blank shutdown frame. Movie trace reports `errors=[]` and terminal victory; route and initial shop displays each hold about 2.3 seconds before their first decision, and victory remains for about 2.1 seconds before the 54.7-second export ends. No export-blocking defect found in these samples.

This was selected-frame verification, not continuous playback or listening. The coordinator's nonzero-audio measurement is separate evidence; this review makes no listening, audio-quality, synchronization, or real-time performance claim. Only this report was updated; no production edits or commits.
