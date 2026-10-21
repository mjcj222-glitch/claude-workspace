# Bounded boss candidates: input and window checks

## Current candidate B: weak2 / ordinary10

Candidate B restores the approachable single-action weak-pair mitigation path while retaining the ordinary-panel threshold of10. Boss HP48, slam10->4, plain6 and weakness damage floor(W/2) remain unchanged. These checks prove input/presentation consistency; they do not select a winner by win rate.

- `input-b-green.log`: **54/54 checks pass**. A boss weak pair advertises slam and commits weakness damage plus mitigation; ordinary8 and ordinary9 alone do not enable slam; ordinary10 qualifies. Held context records2/10. Preview/commit equality, cancellation, skill, heart/core accounting, direct-four, third-action kill priority and modal/reset isolation remain covered. Three separate W1 actions cannot accumulate into a valid single-action W2 condition.
- Current root `window-360x640.log` and `window-390x844.log`: **26/26 checks, 11 authenticated XTest stages, exit0 each**, rerun once after candidate B production/test updates.
- Current root `window-*.png` show candidate B. Direct pixel inspection confirms the complete two-line **one action weak2 OR ordinary10** condition, unchanged damage decomposition, normal/weak counts, complete board and non-overlapping weakness/HP/reset HUD.
- Generated board and seed remain unchanged. The probe finds a currently legal ordinary group with W>=2; no favorable seed, board rescue, forced settling or physics edits were introduced. Initial first-fight input uses the actual generated board. Safe/elite/boss encounters are explicit presentation/input fixtures on unchanged generated panels, not naturally earned-run or balance evidence.

## Preserved candidate A: weak3 / ordinary10

`candidate-a-window/` preserves all candidate A window logs/PNGs, its original `WINDOW_TESTS.md`, and input RED/GREEN logs before any candidate B capture overwrote the current window filenames.

- Candidate A input RED: **51 checks, 3 behavioral failures** before implementation (weak2 exclusion, ordinary8 exclusion, context3/10).
- Candidate A input GREEN: **52/52**, including three separate W1 actions not accumulating mitigation.
- Candidate A windows: **26/26 checks and 11 stages at each of360x640 and390x844**.
- Root `input-red.log` and `input-green.log` also remain A historical logs; the current B log is explicitly `input-b-green.log`.

## Limits and reproduction

No ordinary-run result, baseline stall, physical-device result, performance target or human-fun judgment is inferred from these fixtures. Unrelated CPU checks can run concurrently; incidental TIMING entries are not performance evidence. Candidate selection and any later restoration remain coordinator decisions.

```
godot --headless --path . --script tests/test_elemental_input.gd
python3 tests/elemental_window_driver.py 360 640
python3 tests/elemental_window_driver.py 390 844
```

The driver targets `evidence/balance/` and uses the existing authenticated DISPLAY/XAUTHORITY, FFmpeg and XTest without installation or security changes. Original `evidence/elemental/` evidence is preserved.
