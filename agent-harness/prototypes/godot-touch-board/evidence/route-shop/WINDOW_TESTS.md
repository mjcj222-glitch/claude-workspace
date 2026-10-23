# Route/shop input and narrow-window checks

- `route-input-red.log`: behavioral RED against the pre-route main scene: fresh route-card gesture did not start encounter two. No runtime/property/parser error is used as the failing assertion.
- `route-input-green.log`: **55 checks pass**. Both routes, phase/candidate/offer-serial ownership, outside/focus/system cancellation, extra fingers, no board pass-through, reset, stock/funds/full-health guards, purchase effects and shop departure.
- `run-input-green.log`: **95 checks pass**. Previous combat input regression coverage updated for first reward -> explicit route, plus route/shop transition locks and reset/late-process checks.
- `window-360x640.log`, `window-390x844.log`: **44 checks each pass**, **23 authenticated XTest gesture stages each** in actual Godot windows. Actual dimensions are window dimensions, not physical phone displays.
- Captured PNGs directly show the route cards, safe/elite combat, shop purchases, sold state, insufficient funds, full-health disabled healing and final battle. Selected route/shop/sold/full-health images were directly inspected for text/controls and state distinction.
- All route/shop and transition states in this window probe are explicitly injected **input-routing fixtures**. They are not naturally earned progression, victory, balance, touch-latency or real mobile-device evidence. Fixture combat header maxima can differ from natural progression because the test only supplies the fields required for input routing.
- At 390x844 the fixed logical 720x1080 canvas leaves vertical letterboxing. All card/exit controls remain in the content area.
- Existing `evidence/combat/` captures remain historical evidence from the prior between-battle contract and were not replaced.

Reproduce from project root:

```
godot --headless --path . --script tests/test_route_input.gd
godot --headless --path . --script tests/test_run_input.gd
python3 tests/route_window_driver.py 360 640
python3 tests/route_window_driver.py 390 844
```

Window runs require the existing authenticated X display (DISPLAY/XAUTHORITY), FFmpeg and XTest. The driver does not change security settings or install dependencies. No performance target, actual Android/iOS hardware, sound quality or human fun claim follows from these results.

## Legacy combat window probe compatibility

`tests/test_run_window.gd` now follows first reward -> route -> safe-route card while retaining its previous skill, cancellation/stale release, owned-detail and terminal-restart coverage. Its driver now writes to `evidence/route-shop/legacy-window/` instead of overwriting `evidence/combat/`. The updated GDScript passed Godot `--check-only` and the driver passed Python AST parsing. After the departure-point repeated-click guard was implemented, the legacy probe also ran at **360x640: 39/39 checks, 18 OS gesture stages, exit 0**; output is under `legacy-window/`. Both route/shop windows were rerun after that same product change: **360x640 and 390x844 each 44/44 checks, 23 stages, exit 0**. Existing route/shop logs and images reflect these post-fix runs. The repeated-click-specific regression itself is covered by the coordinator-owned `test_transition_reentry.gd`, rather than by a new claim about these window probes.
