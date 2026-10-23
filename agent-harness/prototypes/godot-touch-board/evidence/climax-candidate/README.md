# Climax visual candidate — uncommitted

Low (9 collected) and high (60 collected) 6.72-second 60 fps sound-bearing videos are synthetic presentation fixtures, explicitly labeled on screen. They use production FX/audio but a simplified enemy circle; these are not legal-input gameplay runs or proof of encounter fairness. Enemy-only recoil is tested but the fixture circle does not apply stage_offset.

Solid charge grows/compresses inside existing 0.28-second windup, with broad discharge and elliptical shockwave, directional shards and stronger bounded enemy recoil. Existing 0.24-second impact hold, event API, mechanics and chimes unchanged. No full-screen flash or global camera shake added. Cached impact includes descending bass and bright transient at unchanged playback gain.

Checks: banked FX 16, candidate timing/RNG/reduced/cache 23, quality FX 34, chain/boss FX 23, impact strength 19 passed. Old draw probes first failed because they lacked CanvasItem.draw_polyline; preserved initial logs, added probe support and explicit 3 ellipse / 2 big-bomb arc count assertion. Initial launch without XDG directories aborted before game load; retained log, subsequent launches used established temp XDG dirs.

Decoded high AAC: -10.2805 dBFS sample peak, zero clipped samples among 645120 channel samples. No subjective listening or physical-device output test. Godot MovieWriter Dummy audio actually produced encoded audio. Renderer reports unsupported V-sync under llvmpipe. This synthetic fixture alone does not validate normal play, small-window or save behavior; subsequent fullbody-candidate and hero-b evidence covers those limited checks. No commit, push or package. The combined candidate was separately delivered to Library.
