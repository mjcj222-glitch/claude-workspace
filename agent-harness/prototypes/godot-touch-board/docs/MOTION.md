# Motion/input decision — corrected after visual review

The previous support packing + 0.44s interpolation was rejected: it moved supported survivors toward globally lower spaces and could cross other bodies during interpolation. Its passing final-position tests did not validate paths. `initial_board()` retains the initial seed/layout only to compare the exact checkpoint; it is never called during refill.

| Approach | Contact and movement | Input policy / limitation |
| --- | --- | --- |
| Global rigid-body sleep | Actual physics | Waiting for the last jittering body can lock indefinitely; no comparative engine benchmark performed |
| Grid or packed destination tween | Endpoint connections only; intermediate paths may cross | Rejected: hidden destination does not describe visible contact |
| Current-position circle simulation (selected) | Gravity at 120 substeps/s, local collision projection, support anchors recomputed from current contacts | Ready after all bodies enter and speed stays below 80 px/s for 50 ms; freezes that residual motion. Bounded 4s failure state with reset, never teleport |

Survivors begin at their actual previous centers and retain IDs. Floor-supported circles and stable bracketing supports anchor; removing a support recomputes the anchor graph. Only collision response produces sideways motion. The solver allows up to 128 iterations per substep, stopping early below 0.04px penetration. These are prototype numerical parameters, not rigid-body realism claims. New panels choose a clear inlet above the current deepest surface and fall from above the top; the inlet does not define a destination and never moves survivors. There is one refill after the action.

Body radius remains 37 logical pixels and contact tolerance 1.5px. Rendering uses current simulated centers, not interpolation to future positions. Input is discarded during refill. READY freezes small residual motion; pressing keeps one visible contact snapshot and exact preview/result through release. Landing squash is cosmetic, never a hidden graph position. Outside movement, focus loss, cancellation and extra touches retain prior behavior.

No claim covers all random board arrangements. A full count that cannot safely enter within 4 seconds shows a reset state rather than moving bodies to make room. Benchmarks and fixed-step trajectories are separate in [MOTION_FIX.md](MOTION_FIX.md). No physics libraries, security settings, game rules, or new content were added.
