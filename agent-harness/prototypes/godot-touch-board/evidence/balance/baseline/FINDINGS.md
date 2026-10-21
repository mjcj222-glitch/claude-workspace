# Bounded baseline diagnosis

Core: 3 initial seeds × 2 routes × original pair0 × 3 policies = 18 runs. Completed supplemental pair1/2 runs: 12, retained separately. All six matched core groups have identical events through the first two fights and boss entry. Production and runner SHA256 before/after match. No resources, panels, charge, resets or favorable boards were injected.

| Policy | Core outcome | Boss slam turns / latches | Actual boss attacks |
|---|---|---|---|
| immediate-damage | 6 victory | 12 / 12 incidental | 6×4, 6×6 |
| intent-aware | 6 victory | 12 / 12 | 6×4, 6×6 |
| avoid-intent (adversarial diagnostic) | 5 victory, 1 incomplete stall | 11 / 0 | 8×10, 5×6 |

Every observed active slam turn had a nonmitigating legal alternative. Nonetheless immediate damage selection incidentally satisfied all 12 slam intents before resolution. The shared maximum-connection skill and damage-first choices often produce large normal clears; weakness pairs already qualify at W2. This supports the narrow diagnosis that the baseline criterion often rewards ordinary damage selection without an additional decision. It does not establish player skill, difficulty or win-rate balance.

The immediate-damage latches comprise W2/N2 (3), W3/N3 (1), W4/N4 (1), W5/N5 (1), W0/N9 (1), W0/N10 (2), W0/N11 (3). One bounded candidate is W3 OR N10, retaining HP48 and attacks10→4/plain6. This excludes four observed low-threshold latch examples, but is not a prediction of outcomes: future boards, alternative choices, and eligibility fallback can change. No parameter sweep or damage/HP escalation recommended before evaluating that one candidate.

The original stalled run is `seed20261023-elite-pair0-avoid-intent.json`: action20, HP2, existing refill 4-second safety bound. It is NOT a defeat. Its original console audit failed because an unfinished refill has no `after` state; original JSON and `core-seed23.log` remain untouched. `analysis.json` records the missing-after event, 17 available completed audits (1,944 checks), and this incomplete result separately. No physics timeout extension or replay rescue was attempted.

The initial broad batch ended with SIGINT (130) after seed21's 18 result files completed, following the parent's narrower scope. Missing pair0 seeds then ran via separate logs; seed22 exited0, seed23 exited1 for the recorded stall. No existing elemental evidence was overwritten.

All results are pure fixed-step simulations, not GPU, real-time, touch, or fun evidence. Policies share initial seeds and exact early events; later boss choices change RNG consumption/boards, so this is not an identical-board causal comparison.
