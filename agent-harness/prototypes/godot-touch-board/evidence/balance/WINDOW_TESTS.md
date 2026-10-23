# Final restored boss thresholds and preserved candidate window checks

## Final state: weak2 / ordinary8 restored

The bounded candidates did not change the compared normal-play decisions sufficiently, so the coordinator restored the original numeric thresholds: single-action W2 OR ordinary N8. Boss HP48, slam10->4, plain6 and weakness damage floor(W/2) remain unchanged. The canonical frozen-context/helper implementation remains. Input tests verify this final contract; they do not justify a balance or win-rate claim.

- `input-final-green.log`: **54/54 checks pass**. Weak2 and ordinary8 qualify, ordinary7 alone does not; held context records2/8. Ordinary10 remains qualifying. Snapshot execution, exact damage, cancellation, non-damaging skill, heart/core accounting, direct-four, third-action kill priority, modal/reset isolation and three separate W1 actions not accumulating mitigation remain covered.
- Current root `window-360x640.log`, `window-390x844.log`: **26/26 checks, 11 authenticated XTest stages, exit0 each**, rerun once after final2/8 restoration.
- Current root `window-*.png` are FINAL2/8, directly inspected at both sizes: complete two-line weak2 OR ordinary8 condition, damage decomposition, panel counts, full board and no weakness/HP/reset overlap.
- Generated board, seed and physics remain unchanged. The probe finds a currently legal ordinary group with W>=2; no seed search, favorable board alteration, rescue or forced settling was performed. First-fight input starts from the actual generated board; later encounters are explicitly injected presentation/input fixtures, not naturally earned or completed runs.

## Candidate A preserved: weak3 / ordinary10

`candidate-a-window/` preserves A window logs/PNGs, its original explanation, and input RED/GREEN.

- RED: **51 checks, 3 behavioral failures** before A implementation.
- GREEN: **52/52** after A implementation; includes separate W1 actions not accumulating mitigation.
- Both windows: **26/26 checks, 11 stages, exit0**.
- Root `input-red.log` and `input-green.log` also remain A historical files, not final results.

## Candidate B preserved: weak2 / ordinary10

`candidate-b-window/` preserves B window logs/PNGs, its explanation and `input-b-green.log` before final captures replaced current filenames.

- B input: **54/54**, including W2 restored, ordinary8/9 excluded and ordinary10 included.
- Both B windows: **26/26 checks, 11 stages, exit0**.
- Root `input-b-green.log` is retained as B history, not the final result.

## Limits and reproduction

Candidate comparison/selection belongs to the coordinator's separate normal-play evidence. No ordinary-run success, baseline stall resolution, real-device result, performance target or human-fun judgment follows from these input fixtures. Unrelated CPU work could run concurrently; incidental TIMING entries are not performance evidence. Historical `evidence/elemental/` evidence was preserved.

```
godot --headless --path . --script tests/test_elemental_input.gd
python3 tests/elemental_window_driver.py 360 640
python3 tests/elemental_window_driver.py 390 844
```

The current driver targets `evidence/balance/` and uses existing authenticated DISPLAY/XAUTHORITY, FFmpeg and XTest without installation or security changes. No further tuning was performed by this test worker.
