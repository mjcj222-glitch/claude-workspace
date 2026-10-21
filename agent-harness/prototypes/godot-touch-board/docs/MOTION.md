# Motion/input comparison and decision

This is a new prototype, not the old physical settlement implementation.

| Candidate | Visible-contact consistency | Input release policy | Cost / limitation |
| --- | --- | --- | --- |
| Rigid bodies, global sleep | Snapshot is easy only after all sleep | Slowest residual object can lock entire board | No comparative runtime benchmark performed |
| Logical grid + visual tween | Future slot adjacency can disagree with visible bodies | Easy bounded duration | Rejected: changes contact puzzle into grid matching |
| Continuous circle support packing + controlled fall (selected) | Graph derives only from rendered circle centers/radii at READY | Finite 0.44s interpolation; landing squash does not gate input | Stylized settling and lateral rearrangement, not a full rigid-body simulation |

Panel body radius is 37 logical pixels. Art maps measured opaque body bounds to this diameter; halo pixels do not enlarge collision. Contact graph allows 1.5 logical pixels for sampling/rounding consistency; gap and exact-boundary tests pin it. No invisible connection lines are drawn. Press is accepted only after all translations reach their actual displayed endpoints; it freezes the remaining visual landing squash. One frozen graph/plan is kept through release. Pointer movement never reroutes selection; leaving board or losing focus cancels. New presses during clear/refill are discarded, never buffered. All first-finger down events own the touch until release/cancel, including UI and background.

Initial vertical-only support candidate packing overflowed after repeated refills (471 top violations in the 100-refill stress fixture). The corrected solver considers continuous circle-circle support intersections and lateral compaction, retaining nearest x among equivalent depths. 100 partial-refill stress rounds now preserve full circle containment and non-overlap. This can slide surviving tokens sideways, which must still be judged in human play.

No target row/column identity exists in the rules. The geometric solver may naturally form close-packed rows, but contact is computed from current positions, not row/column indices. No general arbitrary-board capacity guarantee is claimed beyond the 48 equal-radius panels and tested board dimensions.

Ordinary animation delay is sequence onset spacing (bounded 0.011..0.032s) plus 0.12s clear and 0.44s fall. The synchronous pack and actual rendered frames add real wall time; report measured timing, never this sum as achieved performance. Movie writer runs fixed time and cannot prove live timing.
