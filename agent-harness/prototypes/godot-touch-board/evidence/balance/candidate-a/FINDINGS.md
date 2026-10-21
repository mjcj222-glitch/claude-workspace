# Single candidate A: W3 OR N10

All 18 core normal runs completed: 18 victory, 2,094 audit checks, zero errors. Source SHA256 before/after unchanged. The six within-candidate matched groups have identical first-two-fight events; comparison against baseline also confirms unchanged early choices, carried resources, and boss-entry game RNG. No additional candidate was tested.

| Policy | Outcome | Slam turns / latches | Fallback turns | Actual boss attacks |
|---|---|---|---|---|
| immediate-damage | 6 victory | 4 / 4 incidental | 8 | 2×4, 10×6 |
| intent-aware | 6 victory | 4 / 4 | 8 | 2×4, 10×6 |
| avoid-intent (diagnostic) | 6 victory | 3 / 0 | 9 | 2×10, 10×6 |

Baseline immediate-damage and intent-aware each had 12 slam turns, 12 latches and no fallback; each received 6×4 plus 6×6 actual attacks. Candidate A reduces immediate-policy slams from12 to4, but incidental mitigation remains4/4 when a slam exists. Thus this sample does not support A as a fix for the intended decision distinction. The frozen-turn fallback converts many newly ineligible starting boards into plain6 turns, removing the very intent whose deliberate handling was supposed to matter. Raising thresholds alone did not produce natural missed slam mitigation under the plausible immediate-damage policy.

There is no immediate-damage natural10-damage failure and no ordinary same-run failure-plus-mitigation recording candidate among these six runs. Do not force one. Candidate seed20261021/elite and seed20261023/safe show actual4 then6, but not a failed slam. Only the explicitly adversarial avoid-intent policy records10 damage; that is not evidence of human skill differences.

Recommendation: do not claim candidate A improves choice or difficulty from these results; do not continue a threshold sweep or inflate HP/damage to manufacture failure. Parent can decide whether to retain baseline or separately revisit the intended condition/fallback interaction. This analysis changes no production code.

Baseline's seed23/elite/avoid action20 refill stall remains an incomplete baseline result (HP2), not a defeat. Candidate's corresponding victory is a different natural trajectory, not a successful rerun or fix of that physics case. Both full traces remain preserved. Later choices/RNG/boards diverge, so the results are not a causal identical-board skill comparison. No GPU, realtime or hardware conclusions apply.
