# Full-body B — actual game opening candidate

CHROMA-fullbody-B-normal-opening.mp4 contains the actual default main game, Rio then Noa, seed 841. Each character starts normally, enters the first encounter, performs three legal press/release clears with natural refill, banks one attack and reaches the first reward (HP 30, no driver errors). No HP, board, charge, phase or RNG injection. These are automated opening excerpts, not complete runs or human playtests. On-screen labels identify each character, seed and opening scope.

The new capture_fullbody_opening.gd inherits the existing capture_resonance_opening / play_resonance driver and only overrides the evidence directory. Cases and temporary save directories are distinct; earlier evidence and ordinary saves were not overwritten.

Both launches requested a 360×640 OS window. Godot MovieWriter records the 720×1080 internal viewport at fixed 60 fps, so the delivered video is **720×1080**, not an OS-framebuffer 360×640 recording. OS geometry was not independently measured during this capture. The pixel agent's separate small-window screenshots are independent evidence. Fixed-frame render capture is not a frame-rate/performance benchmark. llvmpipe reported unsupported V-sync; neither run logged script or teardown errors.

Original videos: rio-original.mp4 and noa-original.mp4. Labeled copies were joined without changing gameplay speed, cuts or audio level. Combined duration 25.038 seconds, H.264 with AAC 48 kHz. Decoded combined AAC sample peak -10.2119 dBFS, zero clipped/nonfinite samples among 2,408,448 channel samples. Sound is actual Godot MovieWriter output through Dummy audio, not dubbed effects. No physical-device listening performed.

Raw engine logs, trace.json, screenshots, media.json and audio.json are retained here. The separate earlier climax fixture is not included in this actual-play video. This uncommitted candidate has no package/CI/Windows-runtime claim and was not pushed or deployed by this capture task.
