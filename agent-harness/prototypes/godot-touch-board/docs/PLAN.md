# Touch Board Implementation Plan

Goal: Fresh Godot touch-contact board for the approved first feel test; no inherited game code or assets.
Architecture: Pure snapshot rules; freely positioned circular collision envelopes with deterministic position-based falling; CanvasItem art and UI. At ready-pointer-down freeze residual movement, compute one immutable plan, execute it on release. No grid coordinates used for matching.
Tech stack: Godot 4.6.3 / GDScript, generated vector art and PCM sound, FFmpeg evidence.
Spec: User execution contract summarized below; no map/shop/save/party/boss/fever.

## File ownership and interfaces
- Rules worker: scripts/board_rules.gd and tests/test_rules.gd only. static contact_graph(panels, tolerance=1.5), plan(panels,start_id,hp,max_hp), skill_plan(panels,start_id,target_color). Panel = {id:int,pos:Vector2,radius:float,color:int,kind:String}; kinds normal/heart/core/strong; color 0..3, heart=4. Plans return valid, direct:Array[int], removed:Array[int], activated:Array[int], converted:Dictionary[id,color], damage, heal_raw, heal_effective, heal_overflow, spawn:Dictionary (empty or {pos,color,kind}), sequence:Array[int]. Skill returns valid, targets:Array[int], converted, connected:Array[int]. Never mutate input.
- Visual worker: scripts/board_art.gd and optional assets only. extends RefCounted, static draw_panel(canvas:CanvasItem,panel:Dictionary,time:float,emphasis:String="",scale_factor:float=1.0), draw_hero(canvas,center,time,active), draw_target(canvas,center,time,hit). World positions passed in panel.pos. Emphasis direct/chain/convert/empty. No scene/controller ownership.
- Coordinator: project.godot, main.tscn, scripts/main.gd, scripts/board_motion.gd, scripts/board_audio.gd, tests/test_motion.gd, tests/test_interaction.gd, capture tooling and docs.

## Contract
4 attack colors + hearts; one conversion hero; target never attacks. Normal/heart minimum 2; 3 valid manual clears/turn. Direct 6..11 normals create core, 12+ strong, only after chain, at original touch center, never triggered this action. Cores can activate alone. Core converts normal graph radius 1/2 then clears connected color; hearts excluded, specials in radius activate irrespective of color. Snapshot graph and order by start graph distance then ID. Count each clear/heal/activation once. Refill once at end, no auto-clears. Skill max4 normals through normal-only graph, nearest then ID; ready initially, reload on 3 manual clears, no action cost. Damage1/normal, heal2/heart, cap/overflow displayed. Cancel outside/focus/cancel; extra fingers ignored; no queued inputs during refill.

## Tasks and gates
- [ ] Rules: write behavioral fixtures for 2/6/12, solo/chain special, protected spawn, conflicts/hearts, skill paths and healing; observe RED then implement and GREEN.
- [ ] Motion/input: compare rigid settling vs controlled free-position circle solver; test contact from current positions, bounded refill and freeze, cancellation/charging/action count, no queued touch; RED then GREEN.
- [ ] Presentation: shaded dimensional panels, 4 distinct glyphs, cores, small hero and hit dummy, previews with direct/chain distinction, generated bounded-voice stepped audio and landing squash; render review at narrow/wide sizes.
- [ ] Evidence: headless suites, real renderer screenshots and sound video, real wall-clock/frame timing separate from movie capture, playable artifact if available. Independent spec/code review, fix material findings, final report. Commit/push only additive prototype/evidence paths on existing PR3 branch.

## Review focus
- Pointer leaves/re-enters, focus loss, second finger cannot accidentally commit.
- Refill cannot accept stale inputs; current geometry cannot select future neighbors.
- Multi-core conflicting colors remain deterministic and no duplicate healing/clear.
- Newly generated cores and new refill panels cannot activate in same action.
- Small screens keep controls usable; recordings cannot prove mobile latency or fun.

## Progress / rulings
- Baseline: PR3 head b9b7772125c0deb2a21790c05779bac08af54b22; worktree /workspace/godot-touch-worktree. Harness check and 5 unittest cases pass.
- Worktree first command failed because fetch populated FETCH_HEAD only, not remote tracking ref; corrected to FETCH_HEAD (not an authorization denial).
- Ruling: keep concise plan and ledger together here, within authorized new project, instead of modifying existing docs or introducing workflow machinery. User requested small plan and immediate implementation.
- Rules complete: test stub RED 27 failures → 44 checks GREEN. Pure rules/input snapshots.
- Motion/input complete: initial motion stub RED4 → GREEN. Review/stress caught vertical pile overflow; support intersection compaction fix → 100 refills GREEN. Review input RED9 → UI-first ownership/busy gating GREEN. Exactly-three recharge test added.
- Presentation complete for first checkpoint: approved original atlas materialized and inspected in this environment; colored core badge, original vector hero/target, generated PCM, clipped fall area, brief squash. User reference download failed twice and stopped; no reference pixels claimed.
- Independent review: three material findings (pile overflow, busy reset, UI-first second finger), all fixed with reproduced failing tests. Headless audio cleanup warning fixed by stopping voices and clearing streams on exit.
- Evidence in progress: 720x1080 rendered screenshots, 10.2s sound movie, live wall-clock+frame measures separated. Web export succeeded but Chromium sandbox abort blocks browser validation; no sandbox changes or retries via weaker security.
