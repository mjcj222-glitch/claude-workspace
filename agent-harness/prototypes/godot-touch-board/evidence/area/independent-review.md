# Independent one-area implementation review

Read AREA_PLAN and the current board_area_session, board_area_ui, main area routing and board_ui changes; inspected test_area_session source. No production edits or test/render execution by this reviewer.

## Source assessment

No blocking correctness issue identified in this pass. Node IDs own visited/history and paid_nodes, independently of the reused combat pattern index. This avoids suppressing additional-elite rewards when both elites use encounter1. Nonboss victory pays once, then offers an unowned relic or adds the4G replacement once before a confirmation-only spoils screen. Boss victory skips payout. Existing combat.resolve retains kill-before-retaliation ordering.

Adjacent unvisited nodes alone can become candidates; candidate changes invalidate earlier offer serials, and separate entry commits the visit atomically. The controller checks pointer, phase and serial before dispatch. Rest and event complete their node on success, so repeated release cannot repeat the transaction; full HP/insufficient gold/empty relic offers reject before mutation. Shop uses existing one-purchase stock guards; leaving it returns to map, and the legacy auto-advance function is blocked by phase.

Only fight entry invokes fresh-board generation after the first pre-generated board. Nonfight entry preserves panels and does not consume board RNG. HP, gold, character, relics, charge progress/requirement and Ash reservation are not reset by node entry. The same combat object preserves aggregate defeat count while start_fight resets the selected enemy pattern. Area summary uses actual enemies defeated and node history instead of a fixed three-enemy claim. Legacy behavior remains explicitly selected by --short-run.

The inspected session tests exercise node adjacency, candidate/entry, duplicate payout, event exclusivity, rest boundaries, extra8+replacement4, no fourth-relic sale, shop cap/stock, boss no reward and resource carry. Several use explicit lethal fixtures, correctly separate from earned normal-run evidence. No independent test-pass claim is made from reading source alone.

## Current actual pixel samples

Viewed Noa risk map-extra and victory, plus Rio safe-shop rest-offer. Victory clearly reports4 enemies,24 clears,HP30/30,three relics,spent3/remain21 and the chosen event/elite/extra/shop path. Full-HP rest shows a disabled zero-gain paid option and enabled free passage. No blocking crop or overlap in these native samples.

The supplied map-extra image predates the latest reachable_nodes/arrow correction: it still labels abandoned rest/safe branches as future paths and has no direction arrows. Current source distinguishes reachable future nodes from closed branches and draws arrows. Final pixel acceptance of that correction remains pending a refreshed image; the historical image must not be cited as visual proof of the correction. Parent notified.

Remaining acceptance evidence: latest map pixels, OS small-window checks, final regression records, remaining actual normal/defeat paths and exported clip. No balance/fun, physical-device or performance claim follows from this source and still-image review.

## Final artifact checkpoint

Directly viewed the refreshed noa-risk-intent-aware-movie/map-extra.png, video-contact-sheet.png and video-last.png. The earlier map evidence gap is closed: abandoned rest/safe branches now explicitly say closed path, arrowheads establish direction, and extra/shop/boss remain correctly distinguished as current candidate or available options. Resource labels and confirmation remain readable. The sampled movie sequence reaches four-enemy victory and the final decoded frame returns to an unselected character screen without gray exit. This is a frame spot-check, not full realtime playback or audio listening.

Residual visual limitation: a small golem crown fragment remains visible between the top bar and the opaque noncombat modal (approximately y58–88), including map and returned departure. It does not cover text, route controls or resource information in the inspected frames. Record as unfinished visual cleanup; it is not a blocking functional/readability issue for this bounded checkpoint and does not warrant another design loop.

Read summary.json, final-regression/results.json, video-probe.json and docs/AREA.md. Final regression contains44 entries, all exit0 and empty errors; legacy41 and default-area3 are explicitly separated. Summary/documentation report76 new checks and isolated OS24 per size. Four normal native paths record Rio13/25 and Noa16/24-clear victories; both separate attrition paths record20-clear/HP0 defeats, all returning to selection. Paid/free event, capped paid rest, purchased/skipped shop and exhausted-relic replacement are distinguished from boundary fixtures. No inconsistency identified in the reported totals.

The zero-clear Rio startup-canceled trace is retained and excluded from completed runs. Its exact external cancellation cause is uninstrumented; the later isolated25-clear success does not establish the initial cause. No new dedicated area timing comparison exists, and old short-run timing or fixed30fps video must not be claimed as area realtime performance. Video probe confirms25.3s,720x1080 H264/30fps with48kHz AAC; metadata does not establish subjective mix quality or physical-device behavior.

No remaining blocking finding from this bounded source, supplied-results and pixel review. Acceptance is not a claim of human fun/balance, commercial quality, current Windows/Web delivery, save/resume or physical-device validation. Only this report was appended; no tests, production edits or CPU-heavy jobs were run by this reviewer.

## Final owned-relic row follow-up

Read the final board_area_ui addition and viewed refreshed noa-risk-intent-aware-movie/map-extra.png. The map now lists the three actually owned relics with their existing icons and names between resources and the first node. All three labels are readable without overlap with the resource line, node or controls. The code reads session.relics, handles an empty inventory explicitly, and introduces drawing only; hit rectangles, state transitions and gameplay rules are unchanged. No blocking issue found. The previously recorded crown-fragment limitation remains unchanged. Movie regeneration and the coordinator's repeated small-window OS checks are pending at this specific follow-up; no additional executions by this reviewer.

## Regenerated final delivery confirmation

Viewed the regenerated video-contact-sheet.png and video-last.png: the owned-relic name/icon row is now present in the exported map samples (empty, one-relic and three-relic states), and the final frame still returns cleanly to character selection. No new blocking overlap identified. Read final OS logs:24 checks/0 failures at each size; final default-area session/input/transaction logs report33/23/20 checks respectively, all0 failures. This closes the preceding follow-up's pending regeneration/recheck items. Final probe remains25.3s,720x1080 H264/30fps and48kHz AAC. Earlier stated visual, realtime-performance and physical-audio limitations remain; no additional code or execution requested.
