# Independent bounded boss balance review

**Final conclusion: no numeric adjustment justified; final production values restored to W2/N8.** The candidate-A sections below record the earlier review, not the adopted configuration.

Reviewed candidate A against c0840a5: BALANCE_PLAN, Rules/Combat/UI diff, test_balance.gd, and shared balance_policy.gd with play_balance policy declarations. No production/test edits or test processes were made by this reviewer.

## Design diagnosis

The rationale supports trying one small threshold-only candidate, not claiming a desired win rate or demonstrated human difficulty. Earlier maximum-connection skill plus highest immediate-damage selection naturally aligns with N8 mitigation. The documented core baseline separates eighteen pair0 runs from supplementary partial runs, reports the original four-second motion stall as incomplete rather than loss, and identifies three W2/N2 and one W0/N9 incidental latches. W3/N10 directly addresses those easy thresholds while retaining boss HP48, ten-to-four damage, plain6, three-clear turns and all earlier-fight/economy values. No evidence presently justifies damage inflation or a second candidate.

The shared policies are honestly distinct: immediate-damage maximizes damage with deterministic normal-count/ID tie-break; intent-aware prioritizes lethal, then one currently needed mitigation; avoid-intent deliberately prefers a nonmitigating clear even over lethal. The last is an adversarial diagnostic, not a human skill model. Early fights share the same selector, and common skill/shop handling is retained. Same seeds do not produce identical later boards after policy divergence.

## Source and boundary review

No blocking implementation issue found. Rules.slam_mitigated is shared by preview and committed mitigation. The combat context includes both thresholds, Rules deep-copies that context into the held plan, Combat reads the held threshold values, and UI reads context rather than an unrelated live threshold. The current-board canonical opportunity scan still uses Rules.plan, so it automatically follows the new threshold and never assumes hypothetical skill output. Frozen whole-turn fallback, nonaccumulation across actions, mitigation latch and kill-before-retaliation remain intact. The diff does not alter weakness damage/counting, direct-four second-fight mitigation, HP, attack values, economy or physics.

The new boundary test explicitly checks W1/2/3/4 with core exclusion, N8/9/10/11, unchanged weakness damage, copied threshold context, fallback at W2/N9, eligibility at W3/N10, nonaccumulated weak pairs, third-action mitigation, lethal priority, and context-driven UI. It is a deterministic fixture suite and should remain labeled as such. Source review confirms the production path uses the frozen helper; the test only mutates the originating context, rather than independently testing a commit under different live threshold values. This is a coverage limitation, not a reachable normal-flow bug with fixed constants.

## Interpretation limits and next evidence

Raising thresholds can increase fallback-to-plain6 and reduce slam exposure; this can partly offset the intended distinction. Compare scheduled slam opportunities, actual failed/successful attacks, incidental mitigation, fallback frequency, actions and HP alongside completed outcomes. A short fight can skip later retaliation through legitimate lethal priority. Preserve incomplete stalls and compare first-two-fight parity. Candidate normal runs and current window/movie captures were still in progress at this review; no outcome or visual pass is claimed here.

## Final source and comparison review

Inspected the final diff and BALANCE_PLAN decision record after both bounded candidates. Final constants are W2/N8, HP48 and attacks10→4/plain6 remain unchanged. The remaining production diff factors the same original predicate through Rules.slam_mitigated, publishes copied threshold fields in combat_context, and renders the context thresholds in UI. Under normal production contexts the original numeric behavior is preserved; preview, current-board eligibility and committed mitigation use consistent values. No blocking source regression found. The existing controller invariant against advancing intent during a held selection still applies.

The decision to reject numeric tuning is supported by the comparison artifacts. A chiefly removed slam opportunities (eight fallback turns per immediate/intent policy). `comparison-candidate-b.json` reports no candidate-versus-baseline changed choices across the eighteen matched runs. This means each policy retained its own baseline action sequence; it does not mean immediate-damage and intent-aware are always identical to each other. B removed one mitigation per immediate/intent policy on a final lethal action, leaving actual retaliation unchanged. No new practical decision benefit was demonstrated, so reverting instead of further HP/damage/threshold search is appropriate. Neither these automated policies nor this limited sample establish human difficulty or fun.

The known seed20261023/elite/pair0/avoid-intent run remains incomplete in baseline and B: action20, HP2, pending0, simulated refill4.008 seconds at the existing four-second motion limit. It must remain an incomplete motion stall, not a defeat, victory or repaired run. Physics was not changed in this bounded balance pass. Thus B has seventeen completed victories and one incomplete run, not eighteen validated completions.

Fresh final-value OS captures and actual normal intent/avoid presentations remain pending separate visual review. No production/test edits, new test processes, or commits were made by this reviewer; only this report was updated.

## Final-value still/window verification

Viewed fresh normal live boss-turn-0, preview-09, attack-02, attack-03 and victory frames in `capture-20261021-elite-pair0-intent-aware-live`, plus final 360x640 boss telegraph and 390x844 boss-preview-confirm OS captures. The restored W2/N8 two-line telegraph is legible; preview shows four attack/weakness normals and damage6=4+2. Actual retaliation frames show4 with HP26, then6 with HP20. Full playable panels remain visible above the footer, and weakness/HP/Reset do not collide. Victory shows15 clears, HP20, three relics and12G spent. The final trace independently reports errors=[] and matching state. No blocking visual defect found in these samples.

No new long video is required or claimed: gameplay values were restored. The optional avoid movie was intentionally interrupted by the coordinator (SIGINT130); its partial output is aborted evidence, not an observed game death or completed playback. This review inspected stills, not full playback/audio or live performance. No additional quality loops or production changes were made.
