# Elemental weakness and boss intent input verification

- `input-red.log`: actual scene preview initially lacked base+weakness damage and combat context; one behavioral failure without parser/property errors.
- `input-green.log`: 45/45 scene integration checks pass. Snapshot preview/commit equality, exact enemy HP and total damage, cancel/focus/system input, non-damaging skill, converted normal/core/heart counting, no cross-action mitigation accumulation, direct-four preservation, third-action kill priority, modal/reset isolation and full board projection.
- `window-360x640.log` and `window-390x844.log`: 26/26 checks each, 11 authenticated XTest stages each, exit 0. Initial weak-color clear uses the actual unmodified generated first board. Safe/elite/boss encounters are explicitly injected presentation/input fixtures on unchanged generated boards; they are not naturally earned progression or balance evidence.
- Actual captures show weakness HUD, first and boss preview damage decomposition, two-line boss condition, cancellation and committed mitigation. The logical board is projected to (30,268)..(690,798), preserving its full 660x530 field beneath the two status lines.
- Initial inspection found the weakness label at logical (529,100), size22, overlapping the reset button. After the coordinator moved the weakness baseline to (529,127), its glyph to (509,120), and consolidated the HP text at (527,158), both existing OS window tests were rerun: **26/26 checks, 11 stages, exit0 at each size**. Current captures/logs are from these post-fix runs. Direct pixel inspection at both sizes confirms weakness and HP remain legible below the reset button without overlap. The preview footer separately reports ordinary attack-panel count, weakness count, and healing. No production fix was made by the test worker.
- Test runs overlapped unrelated CPU tests. Any incidental TIMING records are **not performance evidence**. Window dimensions are not real phone devices; no Android/iOS touch/audio/readability or human-fun claim follows.

Reproduce from project root:

```
godot --headless --path . --script tests/test_elemental_input.gd
python3 tests/elemental_window_driver.py 360 640
python3 tests/elemental_window_driver.py 390 844
```

Window driver requires the existing authenticated DISPLAY/XAUTHORITY, FFmpeg and XTest. It changes no security settings and installs nothing.
