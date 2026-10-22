# Full-body candidate v1 controller/run checks (before second visual revision)

These results apply to the source hashes in pre-climax-revision-source.json. A subsequent visual review requested a stronger finisher; do not treat these logs as validation of later edits.

## Additional full validation

- Existing 52 regression commands plus the full-body renderer suite: 53/53 passed, no diagnostic errors/warnings. Renderer suite contains 60 assertions. Results and commands: regression/results.json. Test-generated tracked motion evidence was preserved separately then restored to its prior content.
- Actual OS input window fixtures: 64/64 each at 360×640 and 720×1080. Commands used quality_window_driver.py WIDTH HEIGHT --prism --impact with CHROMA_WINDOW_OUT=evidence/fullbody-validation/windows, DISPLAY=:81 and the established Xauthority. These are controlled integration fixtures, not normal run outcomes.
- Cross-process runner: CHROMA_PROCESS_OUT=evidence/fullbody-validation/processes CHROMA_PROCESS_SCRIPT=tests/test_petal_process.gd python3 tests/run_checkpoint_processes.py. It created isolated temporary saves and XDG directories. 100 child process executions, two full continuous-versus-resumed comparisons (not 100 independent comparisons). Rio33-clear victory hash 0e9cd658abcb7c3fd0b9a98125133a8f8c395296084df72b40d47a245d41307d and Noa21-clear victory hash 4e34df09e20508ac36994857c48ea730ddd93c634a4183b1d5ea7c40ef5da8d1 each matched. Held/busy/enemy-attack rollback, different fresh seeds and fixed-seed identity passed. No errors/warnings in child logs.

All commands ran Godot 4.6.3 headless in this prototype, with XDG_DATA_HOME=/tmp/chroma-life/data, XDG_CONFIG_HOME=/tmp/chroma-life/config, XDG_CACHE_HOME=/tmp/chroma-life/cache. No new production edits during validation. play_fullbody_validation.gd inherits play_resonance unchanged except evidence_root.

Commands (each redirected to its matching log):
- godot --headless --path . --audio-driver Dummy --script tests/play_fullbody_validation.gd -- --seed=2301 --hero=rio --path-choice=safe --case=rio2301 --no-shots --save-dir=/tmp/chroma-fullbody-validation-rio2301
- Same driver: --seed=841 --hero=noa --path-choice=risk --case=noa841 --no-shots --save-dir=/tmp/chroma-fullbody-validation-noa841
- Same driver: --seed=2301 --hero=rio --path-choice=risk --case=attrition2301 --attrition --event-free --no-shots --save-dir=/tmp/chroma-fullbody-validation-attrition2301
- godot --headless --path . --script tests/test_hit_scene.gd -- --seed=841 --save-dir=/tmp/chroma-fullbody-hit-area
- Same test with --short-run --seed=841 --save-dir=/tmp/chroma-fullbody-hit-short
- godot --headless --path . --script tests/test_bank_interruption.gd -- --seed=841 --save-dir=/tmp/chroma-fullbody-bank-interruption
- After adding one windup repeated-input/cancel assertion, same test with --save-dir=/tmp/chroma-fullbody-bank-interruption-repeat

Rio2301 safe: victory,15 clears,HP29. Noa841 risk: victory,21 clears,HP30. Rio2301 risk attrition/event-free: defeat,21 clears,HP0. All normal traces have driver errors=[] and verify terminal return/fresh legal battle. No board/HP/charge injection. These are automated legal strategies, not human enjoyment or win-rate evidence.

IMPORTANT: runs were NOT free of engine errors. Shrinking FX shard polygons at board_quality_fx.gd:319 produced Invalid polygon data, triangulation failed: Rio19, Noa2, attrition1. These are candidate render regressions despite gameplay checks passing. Initial logs retained; parent informed and correction pending. No warnings or audio teardown leaks in these three runs (remaining=0).

Controller fixtures: hit_scene21/0 in both Area and short-run; bank_interruption18/0 initially and19/0 after adding windup repeated press/release/cancel inertness. Other checks cover three-clear bank, impact once, impact hold before reward/retaliation, board inertness during hold, checkpoint rejection/replay and duplicate callbacks. Controller fixtures are distinct from normal-play evidence. Exact .28/.24 boundary checks also exist in earlier test_climax_candidate; these controller checks advance actual integration by fixed steps.
