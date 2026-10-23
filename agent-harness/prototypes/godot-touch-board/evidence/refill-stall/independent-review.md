# Independent exact refill-stall review

Read-only production/test review of board_motion.gd, test_balance_refill.gd, original saved-state evidence, probe-before.json and exact red/green results. No Godot or duplicate simulation was run by this reviewer. Only this separate report was written; prior premium reviews and original archive were not changed.

## Cause

The original reproduction matches the archived final panel state. ID255 was admitted at the right wall at0.5s because its instantaneous first-hit height was332.872, above the327 minimum center position. That first-hit body was ID248, unanchored and already rising (vertical velocity approximately−0.776). It subsequently moved right by about10px and upward by3.3px. Wall-bound255 was pushed upward along its contact: center329.47 at0.7s,327.02 at0.9s and326.19 by1s. The full board had already been inside at0.7333s, so this is re-extrusion by moving support, not merely initial spawn-point obstruction. Final255 top289.21 is outside the290 boundary and correctly prevents readiness.

## Narrow correction

The production diff changes only spawn admission. It remembers whether the actual minimum first-hit surface is currently rising, excludes that inlet if so, and continues evaluating the remaining current inlets. It does not move survivors, precompute destination placement, change RNG, gravity, collision ordering, contact tolerances, readiness or the four-second failure limit. For this case255 instead enters atx378.3125 at the same0.5s. Stationary and descending supports remain eligible, without a global settling/anchoring requirement.

No blocking conflict with the approved local-gravity model found. Deferring entry over an already upward-moving surface is a conservative admission decision supported by this reproduction. It is not a proof that every future inlet is safe: horizontal support motion and later collision-driven reversals can also change clearance, and equal-height supports currently retain existing array-order tie behavior. Do not claim a universal jam-prevention guarantee or expand this patch speculatively on that basis.

## Tests and observed result

The new synthetic assertions distinguish all-rising defer from stationary/descending admission. The exact regression restores original survivors and int64 pre-motion RNG, checks generated RNG state against the archive, and records each fixed substep. Its corrected lateral assertion subtracts existing horizontal inertia and recognizes current collisions/walls; it no longer rejects legitimate post-collision momentum.

The inspected exact-green.json reports ready=true/stalled=false at0.991667s, pending0, no outside bodies and failures0. Maximum overlap0.102px, swept overlap0.113px and per-step travel9.181px are unchanged from the red path maxima, and uncaused lateral displacement is0. The test separately checks48 bodies and above-top admission. This supports an actual resolution of the saved checkpoint rather than timeout extension, tolerance widening or marking an unresolved board ready.

The saved-checkpoint result does not alone prove that replay from initial seed reaches identical pre-action state after earlier admission decisions change. Coordinator's archived full-input sequence and broader normal-route/regression runs remain pending at this review. Preserve old red/archive evidence, report any earlier divergence honestly, and require those results before calling the overall follow-through complete. No optional physics redesign requested.

## Final broader evidence and disposition

Read final regression/results.json:35 scripts, all exit0 with empty error lists. Read normal-summary.json: all seven fresh policy runs finish victory with no execution/audit errors (seed21 both routes/all three pairs; seed23 elite pair0 avoid-intent). The latter is17 actions/HP12. It is a fresh legal-policy result on changed refill geometry, not continuation of the old action20 path.

Strict archive replay remains INCONCLUSIVE: five clears complete, then action6/start110 removes[110,115,113] rather than the archived[110,115,113,129]. The harness stops without forcing the old plan. Thus the exact saved-checkpoint fix is proven by its own regression, while end-to-end replay of the historical action sequence is not proven. This distinction is material and correctly preserved.

Read path-comparison.json and path-audit.json. Center/left-column trajectories remain identical. The two-panel case first changes only newborn49 at tick5/0.041667s, inletx360→378.3125; subsequent paths legitimately differ and duration rises0.3667→0.4167s. All three current cases finish with48 floor-connected supported bodies, no uncaused lateral movement, zero stable-floor drift and bounded swept overlap. The aggregate historical hash therefore changes; it must not be presented as byte-identical. The failed old-hash check and unchanged historical trace are retained as provenance, with new trace/audit evidence kept separately. Coordinator also added floor-contact-path assertions to the exact regression, which is included in the passing35-script results.

Final disposition: no blocking defect identified in this bounded admission fix and inspected evidence. Accept resolution of the exact stored refill case with broader passing regression and fresh-policy coverage. Remaining limits are the explicitly inconclusive strict historical replay, changed future board/contact outcomes, a small refill-duration increase in one fixture, and no universal proof against all possible jams. These are disclosed consequences/coverage limits, not grounds to restore the known failing admission or silently weaken readiness. No additional production changes or optional tests requested.
