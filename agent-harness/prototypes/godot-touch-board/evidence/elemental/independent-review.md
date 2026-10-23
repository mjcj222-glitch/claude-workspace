# Independent elemental/boss review

Reviewed `docs/ELEMENTAL_PLAN.md`, changes to Rules, Combat, RunSession, the virtual skill hook, controller/UI, and elemental rule/session/boss assertions against base f2d7cd1. No tests launched, production edits made, or commits created during this review.

No blocking normal-flow defect found. Weakness counts only unique actually removed normal IDs using the final claimed color; the whole-action bonus is floored once. Hearts, existing/generated cores and converted survivors are excluded. Existing conversion claim/order logic is unchanged. Boss eligibility uses the canonical planner on the current board, includes qualifying chains, excludes hypothetical skill conversions, and freezes fallback for the turn. Success is per action and then latched; skill/cancel/preview does not commit mitigation. Second-fight direct-four behavior remains intact. Killing clears still resolve victory before retaliation. Route/shop/relic and transition-input protections were not changed by this pass.

The press plan deep-copies combat context and retains the computed damage through release. Combat currently recomputes mitigation from that plan's counts against its live intent rather than validating `intent_serial`. Normal controller phases cannot advance intent while a selection is active, so no reachable gameplay mismatch was found. This relies on that state-machine invariant; the new session tests mutate live weakness but do not mutate the live intent during a held selection.

## Post-fix visual and normal-flow review

The earlier weakness-label/Reset proximity is resolved in the current captures: weakness sits below Reset, with HP on its own line. Existing evidence records `ui-overlap-red.log` (4 failures) followed by `ui-green.log` (21 checks, 0 failures), and both post-fix OS window logs report 26 checks, 0 failures. These logs were inspected, not rerun by this reviewer.

Independently viewed the normal-live `initial`, `boss-turn-0`, `boss-turn-1`, `mitigation-09`, `attack-02`, `attack-03`, and `victory` PNGs under `capture-20261021-elite-pair0-intent-aware-live`, plus both 360x640 and 390x844 `boss-preview-confirm` captures. No essential clipping, HUD collision, or footer coverage of playable panels found. The two-line slam explains 10→4 and the single-clear alternatives (2 weakness panels or 8 attack panels); the next ordinary turn clearly states attack 6. Narrow-window preview shows attack/weakness counts 3/3 and damage 4 = base 3 + weakness 1, with mitigation indication. Text remains small at 360px but readable at the supplied native image size.

Trace and normal stills agree: first boss clear (action 9) removes four normals, W=4, base=4, bonus=2, damage=6, enemy HP48→42, and incoming10→4. First boss retaliation is actually 4 (player30→26); next plain turn retaliates for6 (26→20). The clear-time animated counter is still progressing in `mitigation-09`, whereas the full action math already reads6=4+2; this is consistent with the staged presentation. Final trace reports errors=[], victory after15 clears, HP20, elite route, 12G spent/0G remaining, all three relics; the victory still matches.

No blocking issue found in this bounded visual review. The ordinary-turn image is the normal odd turn, not a no-opportunity fallback fixture; fallback visual coverage is not claimed here. Exported-video spot-check is recorded below. No production edits or commits were made.

## Exported-video spot-check

`ffprobe` confirms `chroma-elemental-boss.mp4` is 59.5 seconds, 720x1080 H.264 with an AAC stream. Independently decoded the 35.3-second frame from the MP4: the first boss intent hold retains readable two-line 10→4 text and both qualifying alternatives, without HUD/board clipping. Also viewed `boss-preview-frame.png`: four selected weakness normals, damage6=base4+bonus2 and mitigation are legible. `video-last-frame.png` retains the complete victory panel (15 clears, HP20, three relics, elite route, 12G spent/0 remaining); there is no gray exit in that final frame.

No blocking export issue found in these samples. This is a bounded decoded-frame spot-check, not full real-time playback, listening, or a live performance measurement. AAC stream presence does not establish audible quality. Production source was untouched.
