# Candidate A: boss three-weak / ten-normal input checks

The bounded balance change raises only boss slam mitigation thresholds from W2/N8 to W3/N10. Boss HP48, slam10->4, plain6, first/second fights and weakness bonus floor(W/2) remain unchanged. These tests verify implementation and presentation, not a win-rate target.

- `input-red.log`: updated scene assertions ran before the production threshold change. **51 checks, 3 behavioral failures**: a weak pair still enabled slam; eight ordinary panels still enabled slam; held context lacked canonical 3/10 requirements. No parser/property errors.
- `input-green.log`: **52/52 checks pass** after the production change. Preserved preview/commit equality, exact damage, cancellation, skill, heart/core, direct-four, kill-before-retaliation and reset/modal isolation. Added W2/N8 exclusions, N10 eligibility and held-context 3/10 fields. The non-accumulation fixture now commits **three separate W1 actions** so crossing total W3 still cannot satisfy a single-action W3 requirement; this adds the 52nd assertion.
- `window-360x640.log`, `window-390x844.log`: **26/26 checks, 11 authenticated XTest stages, exit0 each**. The actual unchanged initial generated board supplies the first clear. For safe/elite/boss presentation fixtures only encounter selection is injected; panels, seed and physics are unchanged. The probe searches the existing board for an ordinary legal group with W>=3 and verifies the advertised slam and exact held-plan execution.
- Current PNGs directly inspected at both sizes show the complete two-line **one action W3 OR ordinary N10** condition, unchanged damage decomposition and separate normal/weak counts, full board and non-overlapping weakness/HP/reset HUD. No visual/input failure was found.
- These are explicitly labelled input/presentation fixtures, not evidence of naturally reaching/winning the boss. No seed search, favorable board modification, rescue, forced settling or physics change was made. Existing `evidence/elemental/` baseline captures were preserved.
- Unrelated CPU checks could run concurrently. Incidental TIMING log entries are not performance evidence. Actual Android/iOS hardware, sound quality, human readability preference and fun remain outside this test.

Reproduce from project root:

```
godot --headless --path . --script tests/test_elemental_input.gd
python3 tests/elemental_window_driver.py 360 640
python3 tests/elemental_window_driver.py 390 844
```

The driver now targets `evidence/balance/`. Window testing uses the existing authenticated DISPLAY/XAUTHORITY, FFmpeg and XTest without installing dependencies or changing security settings.
