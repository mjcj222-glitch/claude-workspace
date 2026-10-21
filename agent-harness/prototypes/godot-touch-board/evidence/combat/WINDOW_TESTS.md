# Actual-run input routing and narrow-window checks

- `run-input-red.log`: first behavioral failure on the old scene's missing explicit sandbox/actual-run property. The test's initial type-inference parse error was corrected before this RED capture.
- `run-input-green.log`: 81 checks pass against the actual-run scene. Covers fresh modal gestures, offer serial invalidation, cancellation, additional fingers, between-battle progression/carry, transition locks, terminal restart, and reset during all transition phases with late processing.
- `window-360x640.log`, `window-390x844.log`: 39 checks each pass using real authenticated XTest pointer input in Godot windows; 18 requested OS gesture stages each.
- PNGs are actual window captures at the stated window dimensions. `ready`, `palette` and skill conversion begin with the real default board. `enemy-attack`, `reward`, `between`, `fight-two`, `owned-detail`, `victory`, and `defeat` use explicit state fixtures to isolate OS input routing. They are **not evidence of naturally winning the run**. In terminal fixture screenshots, the unchanged top encounter data may intentionally differ from the injected terminal phase.
- Screenshots were directly inspected for telegraph/action-state text, next/restart controls and narrow-window containment. 390x844 has more vertical letterboxing than 360x640 because the fixed logical 720x1080 canvas preserves its aspect ratio.
- These tests do not establish Android/iOS hardware touch behavior, human readability preference, gameplay balance, audio feel, or performance targets.

Reproduce headless: `godot --headless --path . --script tests/test_run_input.gd`.

With an available authenticated X display, run `python3 tests/run_window_driver.py 360 640` and then `python3 tests/run_window_driver.py 390 844`. The driver requires DISPLAY/XAUTHORITY and existing FFmpeg/XTest tools; it does not modify security configuration.
