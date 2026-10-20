# 잔향 회로 v2 Implementation Plan

> For agentic workers: REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox syntax for tracking.

**Goal:** 보이는 접촉과 제거 예고가 일치하는 파티 퍼즐 전투를 만들고, 솔로 시작부터 경로·첫 모집·세 번째 관문까지 검증한다.

**Architecture:** 기존 v1 씬·스크립트·저장은 보존하고 같은 Godot 프로젝트에 독립된 v2 씬과 모듈을 추가한다. 정착 스냅샷에서 만든 선택 계획을 전투 규칙이 보강하고, 입력 확정은 화면에 표시한 계획을 그대로 소비한다. 물리 보드, 순수 규칙, 화면, 탐험 진행, 저장을 분리한다.

**Tech Stack:** 저장소의 Godot 4.6.3, GDScript, 기존 로컬 폰트·캐릭터·효과 자산. 추가 엔진·런타임 의존성은 도입하지 않는다.

**Spec:** docs/superpowers/specs/2026-10-20-resonance-party-puzzle-v2-design.md
**Spec baseline:** d5d57e50207699b4b487c26eba211714308668dc.

이 문서는 실행 전 검토용이며, 아래 단계는 모두 앞으로 수행할 일이다.

## Global Constraints

- 보드는 42개의 물리 기물로 구성한다. 일반 색이나 하트 그룹은 최소 3개여야 유효하다.
- 일반 생성은 빨강·노랑·파랑 각각 30%, 하트 10%로 독립 추첨한다. 폭약사로 생성 확률을 바꾸지 않는다.
- 플레이어의 최대 HP는 72이며 HP 72/72로 시작한다. 직접 및 폭발 하트 회복은 기물당 3이다.
- 같은 색은 중앙 문양도 같다. 색·하트 변환은 hull·크기·위치·회전을 바꾸지 않는다.
- 매칭·주인공/정원지기 탐색의 hull 사이 총 간격은 논리 좌표 1.75 이하(`MATCH_CONTACT_EPS`)이며, 물리 지지 접촉은 1.0(`CONTACT_EPS`)을 유지한다. 양쪽 각각1.75의 합3.5가 아니다. 원격 연결·숨은 격자·드래그 경로 선택·추가 확정 버튼을 도입하지 않는다. 2026-10-20 시드121의 추가 빨강1.3663~1.3830/파랑1.6883 표면 접촉 측정에 따른 초기 수치 가설 수정이며, 초기35↔34 간격2.0978과 선택 외곽선의 연장은 연결 근거로 사용하지 않는다.
- 놓을 때 마지막 예고의 대상과 보드/전투 버전이 다르면 취소한다. 밖으로 이동·OS 취소·포커스 상실도 취소하며 무효 입력은 자원을 쓰지 않는다.
- 한 턴은 유효 제거 3회다. 스킬은 제거 횟수를 쓰지 않으며 팀 전체에서 턴당 1회다.
- 공유 기력은 최대 10, 시작 4, 주인공/폭약사/정원지기 비용은 4/6/4다. 별도 쿨다운은 없다.
- 직접 색 그룹 3–4/5–7/8–11/12+의 피해는 2n/2n+6/2n+18/2n+36, 기력은 1/2/4/6이다. 추가 폭발·하트·단독 기폭은 기력을 주지 않는다.
- 12+는 현재 강공격을 일반 공격으로만 약화하고 압박 가산을 유지한다. 압박은 4×max(0, 현재 턴−3)이며 새 전투에서 초기화한다.
- 폭탄 반경은 고정 D의 1.0/1.6/2.2배다. 기존 폭탄 ID당 한 번, 전체 합집합 정산 후 리필 한 번, 새 폭탄은 다음 선택부터 기폭한다.
- 폭약사는 현재 턴의 세 번째 리필까지 적용하고, 생성 0개면 비용 6을 한 번 반환하되 기력 상한과 팀 사용권 제한을 유지한다.
- 첫 적은 72 HP·일반 8, 안전 두 번째 적은 108 HP·12/20, 위험 적은 132 HP·16/26, 보스는 168 HP·16/28이다. 강공격 주기는 설계대로 유지한다.
- 안전 경로 회복은 18, 위험 승리와 모집 포기의 변환 한도 보상은 각각 +1, 최종 한도는 5다.
- 상단에는 적만 상시 표시한다. 주인공 전신은 자신의 변환 스킬에만 0.7초 표시한다. 모든 보드 표현은 보드 경계에서 잘린다.
- v1을 읽어 변환하거나 덮어쓰지 않는다. v2는 user://resonance_godot_v2.json의 새 탐험이다.
- 모든 수치는 초기 플레이테스트 가설이다. 수치 변경 시 설계·단일 설정·예고·검사를 함께 갱신하고 변경 근거를 보고한다.
- 이번 범위에서 외부 push, PR 변경, main 병합, 배포, 네트워크/권한/모델 비용 확대를 하지 않는다.

## Review Focus

1. 누른 채 창 크기가 바뀌거나 보드 밖으로 나갔다 돌아와도 새 위치의 기물을 확정하지 않는다. 작업 2·6·10에서 검사한다.
2. 스킬·복구·재개로 버전이 바뀐 예고는 폐기하며 취소로 난수나 비용도 소비하지 않는다. 작업 2·5·6·8에서 검사한다.
3. HP/기력 상한과 기력 0에서도 유효 조작이 가능하고 예고의 적립량·유효 회복량이 정산과 일치한다. 작업 4·6에서 검사한다.
4. 마지막 제거의 리필, 파랑 0개, 전투 종료와 재개가 겹쳐도 비용 반환·적 행동이 중복되지 않는다. 작업 4·5·8에서 검사한다.
5. 경로·모집 화면 재개나 중복 승리 신호가 강화·기력 보충을 반복 지급하지 않는다. 작업 7·8·10에서 검사한다.

## 파일 배치와 공통 계약

이하 파일 경로와 검사 명령은 모두 agent-harness/games/resonance-godot/ 기준이다. 계획과 설계 문서는 저장소의 docs/superpowers/ 아래에 둔다.

기존 scenes/battle.tscn, scripts/*.gd, tests/*.gd와 project.godot의 기본 v1 진입은 유지한다. v2는 scenes/v2/expedition.tscn으로 명시적으로 실행한다. 기존 geometry의 polygon·transformed·distance·area 같은 순수 계산과 로컬 자산은 읽기 전용으로 재사용하되, 색에 결합된 기존 graph·recolor·전투 상태를 v2 경로에서 호출하지 않는다. 문서 마지막에 v1/v2 실행 방법을 각각 안내한다.

공통 자료는 다음 이름과 필드를 사용한다. 입력 스냅샷과 예고 함수는 원본 자료를 변경하지 않는다.

| 자료 | 계약 |
|---|---|
| PieceSnapshot | id, hull_id(0–3), match_type(red/yellow/blue/heart), size, x, y, angle, bomb_tier(0–3). 폭탄은 blue만 허용한다. |
| BoardSnapshot | version, pieces. 정착된 기물 배열은 ID 순서이며 42개다. 순수 규칙의 경계 fixture만 더 작은 배열을 허용한다. 새 보드·제거·변환·복구·재개 때 버전은 단조 증가한다. |
| SelectionPlan | board_version, combat_version, seed_id, mode(color/heart/solo_bomb), direct_ids, extra_ids, removed_ids, direct_color_count, fired_bomb_ids, blast_circles. ID 배열은 중복 없이 정렬한다. |
| ActionPlan | SelectionPlan에 direct_damage, blast_damage, healing_raw, healing_effective, energy_raw, energy_effective, weaken_intent, refill_tier를 추가한다. |
| CombatState | revision, enemy_id, hp, enemy_hp, turn, actions_left, pending_damage, pending_heal, energy, party, hero_limit, team_skill_used, bomb_buff, intent, refill_pending, status. |
| RunState | revision, seed, stage, route, party, hero_limit, hp, energy, battle_seeds(3개), applied_choices, completed_battles. 첫 생성 때 세 전투 시드를 정하고 저장한다. |
| BattleContext | enemy_id, seed, hp, energy, party, hero_limit, reduced. RunState에서 현재 전투의 시드와 적을 선택한다. |
| ApplyResult | ok, state, events. 순수 상태 변경 함수는 새 state를 반환한다. 거부되면 입력 상태와 동일한 값을 반환하고 자원을 바꾸지 않는다. |

bomb_buff는 active, paid_cost, generated_count, refunded를 가진다. intent는 kind, base_damage, pressure, total_damage, weakened를 가진다. 단독 기폭은 direct_ids에 누른 폭탄 하나를 넣지만 direct_color_count는 0이다. 직접 피해와 폭발 피해는 턴 적립량이며, 최종 적 HP 감소와 혼동하지 않는다.

scripts/v2/config.gd만 수치의 원본으로 삼는다. 적 자료 키는 hall1, hall2_safe, hall2_risk, gate이고 캐릭터 키는 hero, bomber, gardener다. 별도 v2 class_name 또는 preload 별칭으로 v1 전역 이름과 충돌하지 않게 한다.

새 검사 파일은 기존 SceneTree/check 형식을 따르고 실패 시 종료 코드 1, 통과 시 failures=0과 종료 코드 0을 반환한다. 검사는 임시 XDG 데이터·설정·캐시 경로와 --no-save를 사용한다. 저장 검사는 그 임시 공간 안의 명시적 fixture 슬롯만 사용한다. 엔진·의존성을 설치하거나 사용자 실제 저장을 초기화하지 않는다.

각 작업의 마지막 로컬 커밋은 해당 작업에 적은 파일만 스테이징하고 git diff --cached --check로 확인한 뒤 만든다. 아래 커밋 제목은 제안이며 외부 전송을 포함하지 않는다.

---

## 작업 1. hull·타입을 분리한 v2 물리 보드

**의존성:** 없음.
**새 파일:** scripts/v2/ 아래 config.gd, geometry.gd, piece.gd, board.gd; tests/v2/ 아래 fixtures.gd, geometry_board_test.gd.

**계약:** GeometryV2.polygon(hull_id: int, size: float) -> PackedVector2Array, graph(snapshot: Dictionary) -> Dictionary, diameter_unit() -> float. PieceV2.configure(id: int, hull_id: int, match_type: String, size: float, bomb_tier: int = 0) -> void, apply_type(match_type: String) -> void, snapshot() -> Dictionary. BoardV2.new_board(seed: int) -> void, capture() -> Dictionary, make_refill(count: int) -> Array, apply_clear(ids: Array, batch: Array) -> void, apply_types(changes: Dictionary) -> Dictionary, checkpoint() -> Dictionary, restore(checkpoint: Dictionary) -> void, supported(snapshot: Dictionary) -> bool.

- [ ] 1. 실패할 검사부터 작성한다. 네 hull·세 색·하트 조합의 표시/충돌 일치, 변환 전후 hull·ID·위치·회전 불변, 접촉 간격 0.5는 연결·2.0은 분리, 기울어진 별과 모서리 빈 공간을 검사한다.
~~~gdscript
var before = piece.snapshot()
piece.apply_type("heart")
assert(piece.snapshot().hull_id == before.hull_id)
assert(piece.position == before_position and piece.rotation == before_rotation)
assert(piece.polygon == piece.collider.polygon)
~~~
- [ ] 2. godot --headless --fixed-fps 120 --script tests/v2/geometry_board_test.gd -- --no-save로 누락된 v2 모듈/동작 때문에 실패하는지 확인한다.
- [ ] 3. 고정 hull 계산과 타입·문양 렌더링을 분리한다. 보드의 논리 영역은 600×600, 물리 부모 배율은 1이다. 30/30/30/10 정수 가중 추첨을 사용한다. D는 네 기본 hull의 최대 점간거리 평균이다. 정착은 기존 속도·각속도·지지 검사와 28개 조용한 물리 틱, 12초 오류 한계를 재사용하며 시간 초과를 정상 정착으로 처리하지 않는다.
- [ ] 4. 같은 검사를 통과시킨다. 시드 41·73·991·20261020에서 42개, 고유 ID, 경계·지지·깊은 겹침 방지를 확인한다. apply_types는 새 버전의 스냅샷을 반환하되 리필 완료 신호를 내지 않는다. make_refill은 확정 뒤에만 호출한다.
- [ ] 5. 로컬 커밋: feat: add v2 hull and physical board foundation.

Fixtures.tile(id, type, hull_id, center, bomb_tier=0), snapshot(tiles, version=1), chain(n, type="red", bomb_tiers={}), combat(enemy_id="hall1", turn=1, hp=72, energy=4)를 검사 보조 파일에 정의한다. chain은 원형 hull을 0.5 간격으로 배치하고 combat은 공통 CombatState 필드를 제공한다.

## 작업 2. 접촉 그룹·폭발 합집합과 예고 소비 계약

**의존성:** 작업 1.
**새 파일:** scripts/v2/ 아래 selection_rules.gd, preview_session.gd; tests/v2/selection_test.gd.

**계약:** SelectionV2.preview(snapshot: Dictionary, seed_id: int, combat_version: int) -> Dictionary. PreviewSessionV2.begin(plan: Dictionary, pointer_id: int) -> bool, move(pointer_id: int, inside: bool) -> void, release(pointer_id: int, inside: bool, board_version: int, combat_version: int) -> Dictionary, cancel() -> void.

- [ ] 1. 같은 색의 전체 접촉 성분, 멀리 떨어진 같은 색 제외, 하트 독립 연결, 2개 무효, 폭탄 단독 예외와 3개 이상 파랑 그룹을 검사한다. 폭탄 원의 안·경계·밖과 겹친 연쇄를 포함한다.
~~~gdscript
assert(SelectionV2.preview(Fixtures.chain(2), 1, 1).is_empty())
assert(SelectionV2.preview(Fixtures.chain(3), 1, 1).direct_color_count == 3)
assert(plan.removed_ids.size() == unique_removed_count)
assert(plan.fired_bomb_ids.size() == unique_fired_count)
~~~
- [ ] 2. godot --headless --fixed-fps 120 --script tests/v2/selection_test.gd -- --no-save로 실패를 확인한다.
- [ ] 3. hull 경계 그래프의 같은 타입 탐색과 기존 폭탄 큐를 구현한다. 반경은 기물 중심 거리 이하 비교이며 색 그룹과 추가 폭발 집합을 분리한다. 예고 세션은 전달된 계획을 보관하고 놓을 때 그 값만 반환한다. 보드 안 이동은 그룹을 바꾸지 않고, 밖으로 나간 세션은 재진입해도 취소 상태다.
- [ ] 4. 같은 검사를 통과시킨다. 버전 불일치·포커스 취소·두 번째 포인터·두 번 놓기·누른 채 창 변경 시 취소를 포함한다. 원본 스냅샷 불변과 무효 입력 때 난수·ID 할당이 없는지도 확인한다.
- [ ] 5. 로컬 커밋: feat: make v2 selection preview authoritative.

이 단계는 제거 대상 계약을 완성한다. 작업 4에서 같은 계획에 피해·기력을 보강한다.

## 작업 3. 새 화면과 첫 시각 체크포인트 A

**의존성:** 작업 2.
**새 파일:** scenes/v2/battle_view.tscn; scripts/v2/ 아래 battle_view.gd, board_viewport.gd, board_effects.gd, skill_cutin.gd; tests/v2/presentation_test.gd; tools/v2/preview_probe.gd.

**계약:** BattleViewV2.bind_board(board: Node) -> void, show_state(state: Dictionary, party: Array) -> void, show_selection(snapshot: Dictionary, plan: Dictionary) -> void, show_plan(snapshot: Dictionary, plan: Dictionary) -> void. BoardViewportV2.logical_to_board(point: Vector2) -> Vector2, board_to_logical(point: Vector2) -> Vector2, contains_logical(point: Vector2) -> bool. SkillCutinV2.play(reduced: bool) -> void. 씬의 직계 노드는 EnemyStage, Party, Bars, PreviewLine, BoardViewport, CutinLayer이며 전신은 CutinLayer/Hero에 둔다.

- [ ] 1. 주인공 초상 하나, 상시 전신 없음, 적 무대와 정사각형 보드 분리, 좌표 왕복, 직접/추가 표식 분리, 컷인 종료를 검사한다.
~~~gdscript
assert(view.get_node("Party").get_child_count() == 1)
assert(not view.get_node("CutinLayer/Hero").visible)
assert(viewport.board_to_logical(viewport.logical_to_board(p)).distance_to(p) < 0.1)
~~~
- [ ] 2. godot --headless --script tests/v2/presentation_test.gd -- --no-save로 실패를 확인한다.
- [ ] 3. 600×600 SubViewport 안에 물리 기물과 모든 보드 효과를 함께 넣고 정사각형으로 표시한다. 물리 부모를 확대하지 않는다. 상단 적, 작은 초상 줄, 얇은 HP·기력, 한 줄 예고를 구성한다. 기존 로컬 자산만 사용한다. 변환·하트·폭탄 단계는 큰 문양으로, 선택은 그룹 외곽으로 읽힌다.
- [ ] 4. 같은 검사 통과 후 godot --script tools/v2/preview_probe.gd -- --no-save --fixture base를 실행한다. fixture 값 base, bombs, clip, cutin을 각각 그래픽 실행해 실제 시드 보드와 시험용 폭탄 장면을 촬영한다. 초기 도구는 대상 개수만 표시하며 미구현 피해 숫자를 꾸며 넣지 않는다.
- [ ] 5. **체크포인트 A:** 참고 이미지와 실제 픽셀을 대조해 광택·베벨·검정/중성 회색·손가락 밖 그룹 외곽·낙하/폭발 클리핑·0.7초 컷인 복귀를 독립 검수한다. 첫 장면을 사용자에게 중간 결과로 보여 준다. 불합격 장면을 수정한 뒤 통과한 화면으로 진행한다. 로컬 커밋: feat: add v2 battle presentation and clipped board.

시작 낙하나 보충 때 토큰이 캐릭터·정보·도크를 가리면 통과하지 않는다.

## 작업 4. 피해·회복·기력·적 예고의 순수 규칙

**의존성:** 작업 2. 작업 3과 파일 충돌 없이 병렬 수행할 수 있다.
**새 파일:** scripts/v2/combat_rules.gd; tests/v2/combat_rules_test.gd.

**계약:** CombatV2.fresh(context: Dictionary) -> Dictionary, preview(snapshot: Dictionary, state: Dictionary, seed_id: int) -> Dictionary, apply_action(state: Dictionary, plan: Dictionary) -> Dictionary, finish_refill(state: Dictionary, generated_bombs: int) -> Dictionary, intent(enemy_id: String, turn: int, weakened: bool = false) -> Dictionary.

- [ ] 1. 임계값별 직접 피해/기력, 하트 회복, 추가 피해 분리와 압박을 검사한다.
~~~gdscript
assert(damage_at_thresholds == [6, 8, 16, 20, 34, 40, 60]) # n=3,4,5,7,8,11,12
assert(energy_at_thresholds == [1, 1, 2, 2, 4, 4, 6])
assert(three_hearts.healing_raw == 9 and three_hearts.energy_raw == 0)
assert(CombatV2.intent("gate", 4).total_damage == 32)
assert(CombatV2.intent("gate", 4, true).total_damage == 20)
~~~
- [ ] 2. godot --headless --script tests/v2/combat_rules_test.gd -- --no-save로 실패를 확인한다.
- [ ] 3. SelectionPlan을 단일 ActionPlan으로 보강한다. 예고 회복은 현재 HP·누적 회복을 반영하고 기력은 최대 10에서 실제 증가량도 계산한다. apply_action은 적립·기력·제거 횟수·현재 강공격 약화를 반영하고 refill_pending을 설정한다. finish_refill은 실제 생성 수를 반영하며 한 번만 소비한다. 세 번째 리필 정착 뒤 반환 처리, 회복, 공격, 생존 적 행동, 다음 턴 준비 순으로 진행한다.
- [ ] 4. 같은 검사를 통과시킨다. 유효 3회 전 적 행동 없음, 무효 입력 무소모, 기력 0에서도 제거 가능, HP 72/기력 10 상한, 12+ 중복 약화/다음 턴 이월 금지, 적 사망 시 반격 없음, 압박 0/4/8/12, 이미 끝낸 리필 재처리 거부를 확인한다.
- [ ] 5. 로컬 커밋: feat: implement v2 combat rewards and enemy pressure.

폭발로 12개를 지워도 직접 그룹이 3개면 3개 보상만 받는 사례와 단독 폭탄의 직접 피해·기력 0을 포함한다.

## 작업 5. 세 스킬과 이번 턴 리필 폭탄

**의존성:** 작업 4.
**새 파일:** scripts/v2/skill_rules.gd; tests/v2/skill_rules_test.gd.

**계약:** SkillsV2.preview(snapshot: Dictionary, state: Dictionary, actor_id: String, seed_id: int = -1, destination: String = "") -> Dictionary, apply(state: Dictionary, skill_plan: Dictionary) -> Dictionary, decorate_refill(batch: Array, state: Dictionary, trigger_plan: Dictionary) -> Dictionary. 마지막 함수는 batch와 generated_bombs를 반환하며 원본 배치를 바꾸지 않는다.

- [ ] 1. 주인공의 같은 색 너비 우선·거리 동률 ID 순서, 정원지기의 일반 기물 접촉 3개, 하트/폭탄 제외, 팀 사용권과 비용을 검사한다.
~~~gdscript
assert(hero_plan.changes.size() <= state.hero_limit)
assert(after.energy == before.energy - 4 and after.team_skill_used)
assert(after.actions_left == before.actions_left)
assert(refill_result.batch.map(func(t): return t.match_type) == original_types)
~~~
- [ ] 2. godot --headless --script tests/v2/skill_rules_test.gd -- --no-save로 실패를 확인한다.
- [ ] 3. 스킬 계획에도 보드/전투 버전을 넣고 확정 시에만 비용·사용권을 쓴다. 미모집 캐릭터는 사용할 수 없다. 폭약사는 새 리필의 blue에만 단계 1/2/3을 부여한다. 직접 수 3–4/5–7/8+와 하트·단독 기폭의 소형 예외를 사용한다. 생성 배치의 타입·ID·hull·난수 결과를 재추첨하지 않는다.
- [ ] 4. 같은 검사를 통과시킨다. 취소·같은 목적색·대상 없음 무소모, 첫 변환, 한도 3/4/5, 두 번째 스킬 거부, 마지막 리필·기존 파랑 불변·폭탄 존속, 파랑 0개 반환 한 번·상한 10·사용권 미반환을 확인한다. 정원지기는 즉시 회복하지 않고 생성한 하트 3개를 제거할 때 회복 9를 얻는다. 새 폭탄은 현재 연쇄에 들어가지 않는다.
- [ ] 5. 로컬 커밋: feat: add v2 character skills and refill bombs.

## 작업 6. 실제 입력·정산 통합과 시각 체크포인트 B

**의존성:** 작업 3·4·5 완료.
**새 파일:** scripts/v2/battle.gd; scenes/v2/battle.tscn; tests/v2/battle_integration_test.gd.
**수정:** scripts/v2/ 아래 battle_view.gd, board_effects.gd. 화면 담당과의 동시 편집을 끝낸다.

**계약:** BattleV2.start_battle(context: Dictionary) -> void, commit_preview(plan: Dictionary) -> bool, export_checkpoint() -> Dictionary, restore_checkpoint(record: Dictionary) -> void. 종료는 finished(outcome: Dictionary) 신호를 한 번만 보낸다.

- [ ] 1. 실제 누름/놓기와 스킬 대상 조작을 연결한 실패 검사를 작성한다. 버전 불일치·두 번 확정·다중 포인터·창 변경·보드 밖 재진입을 포함한다.
~~~gdscript
assert(absent_original_ids == shown_plan.removed_ids)
assert(refill_batch_count == 1)
assert(invalid_after_rng_state == invalid_before_rng_state)
assert(battle.action_count == 1) # 같은 계획을 두 번 놓아도 한 번
~~~
- [ ] 2. godot --headless --fixed-fps 120 --script tests/v2/battle_integration_test.gd -- --no-save로 실패를 확인한다.
- [ ] 3. 정착/대기/예고/스킬 대상 선택/정산/컷인/종료/오류 상태를 연결한다. 누를 때 CombatV2.preview를 한 번 호출하고 놓을 때 PreviewSession의 같은 계획을 소비한다. 버전 검사와 입력 잠금을 먼저 끝낸 뒤 상태 적용, 실제 제거, 한 배치 생성·폭약사 장식, 리필·정착, finish_refill 순으로 진행한다. 변환은 apply_types의 반환 스냅샷을 사용하며 리필 완료로 오인하지 않는다.
- [ ] 4. 같은 검사를 통과시킨다. 실제 없어진 ID와 표시 ID 일치, 하트 중복 회복 없음, 새 폭탄 즉시 폭발 없음, 낙하/컷인 입력 무소모, 변환 비용·행동·팀 사용권, 힐→공격→반격 순서, 압박을 포함한 적 예고를 확인한다. export_checkpoint는 완료된 대기/종료 상태에서만 값을 반환한다.
- [ ] 5. **체크포인트 B:** 실제 규칙으로 “직접 8 + 추가 4, 피해 34+3, 하트 3, 기력 4” 장면과 단독 폭탄·변환·강공격 약화 장면을 촬영한다. 외곽/결과 줄과 실제 정산을 대조하고 압축→파열→낙하가 읽히는지 독립 검수한다. 로컬 커밋: feat: integrate v2 battle actions and exact previews.

탐험·모집을 붙이기 전에 실제 예고·정산이 맞아야 한다. 구형 기대값으로 v2를 통과시키지 않는다.

## 작업 7. 솔로 시작·경로·첫 모집·관문

**의존성:** 작업 6.
**새 파일:** scripts/v2/ 아래 run_rules.gd, expedition.gd; scenes/v2/expedition.tscn; tests/v2/run_rules_test.gd.

**계약:** RunV2.fresh(seed: int) -> Dictionary, battle_context(run: Dictionary) -> Dictionary, sync_battle(run: Dictionary, battle: Dictionary) -> Dictionary, complete_battle(run: Dictionary, battle: Dictionary) -> Dictionary, choose_route(run: Dictionary, choice: String) -> Dictionary, choose_recruit(run: Dictionary, choice: String) -> Dictionary. 변경 함수는 ApplyResult를 반환한다.

- [ ] 1. 첫 전투→경로→두 번째 전투→모집→보스→완료 전이와 중복 요청 거부를 검사한다.
~~~gdscript
assert(RunV2.fresh(41).party == ["hero"])
assert(safe_result.state.hp == min(72, before.hp + 18))
assert(risk_context.enemy_id == "hall2_risk")
assert(skip_result.state.party == ["hero"])
assert(skip_result.state.hero_limit <= 5)
~~~
- [ ] 2. godot --headless --script tests/v2/run_rules_test.gd -- --no-save로 실패를 확인한다.
- [ ] 3. 단계는 battle1/route_choice/battle2/recruit_choice/battle3/completed/lost로 제한한다. 경로·모집의 적용 ID와 완료한 전투 ID를 기록한다. 안전 회복 18, 위험 적 132·16/26 및 승리 강화 +1, 모집/포기 강화와 기력 최소 보충을 반영한다. 전투 시작은 새 보드·1턴·3회·새 사용권이며 HP·기력·파티·강화만 이어진다.
- [ ] 4. 같은 검사를 통과시킨다. 여섯 경로/모집 조합, 안전+포기 한도 4·위험+포기 한도 5, 폭약사 모집 때 기력 2→6·8→8, 정원지기/포기 때 최소 4를 확인한다. 보충 중복 금지, 새 전투 압박 초기화·폭탄/버프 미이월, 세 전투 종료·패배/재시작도 포함한다. sync_battle은 HP·기력만 동기화하고 진행 보상을 지급하지 않는다.
- [ ] 5. 로컬 커밋: feat: add first three v2 expedition battles.

초상은 실제 파티에 맞춰 1개 또는 2개이며 추가 동료를 구현하지 않는다.

## 작업 8. v2 저장과 중간 재개

**의존성:** 작업 7.
**새 파일:** scripts/v2/save_store.gd; tests/v2/save_store_test.gd.
**수정:** scripts/v2/ 아래 expedition.gd, battle.gd.

**계약:** SaveV2.decode(raw: String) -> Dictionary, write_checkpoint(path: String, record: Dictionary) -> Error. 저장 레코드는 version=2, ruleset="party-puzzle-v2-initial", run, battle, board, reduced를 가진다. board에는 스냅샷·다음 ID·난수 상태를 포함한다.

- [ ] 1. 임시 v1 파일의 바이트 보존과 v2 왕복, 중간 턴·모집 선택·환불 재개를 검사한다.
~~~gdscript
assert(v1_bytes_after == v1_bytes_before)
assert(restored.battle.actions_left == 1)
assert(restored.battle.team_skill_used)
assert(second_refund_result.state.energy == first_refund_result.state.energy)
~~~
- [ ] 2. godot --headless --script tests/v2/save_store_test.gd -- --no-save로 실패를 확인한다.
- [ ] 3. 완료 지점의 탐험·전투·42개 보드를 함께 임시 파일에 쓰고 원자적으로 교체한다. 예고·진행 중 정산은 저장하지 않는다. 경로/모집은 마지막 완료 전투와 함께 저장한다. 버전·ruleset·단계·파티·수치·ID·hull·타입·폭탄·난수·유한 좌표·지지·겹침을 검사하고 D·압박은 설정/턴으로 재검증한다. 재개 시 예고를 비우고 보드/전투 버전을 각각 max(현재, 저장값)+1로 갱신해 옛 계획을 무효화한다.
- [ ] 4. 같은 검사를 통과시킨다. 남은 행동 2/1과 적립량, 파랑 생성 0/1, 반환 직전/직후, 경로·모집 보상 적용 직전/직후, 절반만 쓴 임시 파일, 중복 ID·잘못된 hull·비정상 위치·손상 JSON·알 수 없는 버전을 포함한다. --no-save는 v1/v2 모두 읽거나 쓰지 않는다. 저장 실패 시 마지막 정상 슬롯을 보존하고 실패를 표시한다.
- [ ] 5. 로컬 커밋: feat: isolate v2 saves and resume transactions.

## 작업 9. 막힌 판 복구와 물리 회귀

**의존성:** 작업 6·8.
**수정:** scripts/v2/ 아래 board.gd, battle.gd.
**새 파일:** tests/v2/recovery_test.gd.

**계약:** BoardV2.recover_if_blocked() -> Dictionary. 결과는 status(unchanged/recovered/error), snapshot을 반환한다. 유효 선택 판정은 SelectionV2.preview를 재사용한다.

- [ ] 1. 유효 그룹·폭탄이 없는 판, 단독 폭탄이 있는 판, 접촉 3개를 만들 수 없는 배치와 정착 실패를 검사한다.
~~~gdscript
assert(after_type_counts == before_type_counts)
assert(after_ids == before_ids and after_hulls == before_hulls)
assert(after_resources == before_resources)
assert(refill_count_during_recovery == 0)
~~~
- [ ] 2. godot --headless --fixed-fps 120 --script tests/v2/recovery_test.gd -- --no-save로 실패를 확인한다.
- [ ] 3. 다음 입력을 기다릴 때만 막힘을 판정한다. ID·타입 수·hull을 보존하는 결정적 타입 교환을 최대 8회 시도하고, 실패하면 같은 기물을 한 번 재낙하한다. 타입 교환은 접촉 3개에 충분한 일반 색이 모이게 시도하며 주 생성 난수열을 소비하지 않는다. 실패는 오류로 끝내고 마지막 정상 체크포인트 재개를 제공한다.
- [ ] 4. 같은 검사를 통과시킨다. 초기 교환 단계의 위치 불변, 보드 버전 갱신과 옛 예고 취소, 재낙하 상한, 오류/복구 중 저장 금지, 기력·적립·행동·폭약사 생성 수 불변을 확인한다. 작업 1의 네 시드 물리 검사도 다시 실행한다.
- [ ] 5. 로컬 커밋: fix: recover blocked v2 boards without resource rewards.

승패가 끝난 보드는 복구하지 않는다.

## 작업 10. 전체 회귀·실제 창 입력·픽셀과 영상

**의존성:** 작업 7·8·9.
**새 파일:** tests/v2/ 아래 full_expedition_test.gd, window_input_test.gd; tools/v2/ 아래 os_input_probe.gd, run_os_input_probe.py, record_expedition.gd.
**수정:** tests/v2/presentation_test.gd, README.md, VALIDATION.md. 검수 증거는 기존 evidence/local-integration을 덮어쓰지 않고 로컬 evidence/v2-local/에 둔다.

- [ ] 1. 두 경로×세 모집 선택의 실제 3전투 완료, 패배/재시작, 실제 입력과 표시 위치 일치에 대한 실패 검사를 작성한다. 승리 검사는 중간에 HP·기력·적 HP를 보정하지 않는다. 별도 상태 전이 fixture와 정상 플레이 기록을 구별한다.
~~~gdscript
assert(trace.battles_won == 3 and trace.stage == "completed")
assert(trace.resource_overrides.is_empty())
assert(actual_removed_ids == displayed_plan.removed_ids)
~~~
- [ ] 2. godot --headless --fixed-fps 120 --script tests/v2/full_expedition_test.gd -- --no-save와 tests/v2/window_input_test.gd를 각각 실행해 아직 빠진 검사 도구/흐름을 확인한다.
- [ ] 3. v2 창 검사·기록 도구를 연결한다. 기존 NativeInput의 좌표 변환과 OS 마우스 검사의 구조만 재사용하고, 옛 스킬·폭탄 기대값과 기존 증거 파일은 사용하지 않는다. 실제 v2 실행은 godot res://scenes/v2/expedition.tscn이며, 기존 v1은 원래 진입 또는 res://scenes/battle.tscn이다.
- [ ] 4. 새 v2 검사 전부와 기존 rules_test.gd, battle_test.gd, full_battle.gd, presentation_test.gd, window_input_test.gd를 각각 실행한다. v1의 옛 기대값은 v1 보존 확인에만 쓴다. 360×640, 390×844, 720×1280, 1280×900에서 합성 터치와 인증된 로컬 창의 OS 마우스로 누름/이동/놓기/취소·실행 중 크기 변경을 확인한다. OS 경로는 python3 tools/v2/run_os_input_probe.py로 실행한다. 필요한 그래픽 환경이 없으면 그 검증만 미완료로 보고하며 권한/네트워크 우회나 의존성 설치로 범위를 넓히지 않는다.
- [ ] 5. godot --resolution 720x1280 --script tools/v2/record_expedition.gd -- --no-save로 게임 화면을 기록한다. 시작/리필 클리핑, 변환 후 다른 hull의 같은 타입, 하트, 폭탄 세 반경, 연쇄, 마지막 리필, 컷인 복귀, 강공격 약화·압박, 모집 후 초상을 실제 프레임으로 검수한다. 두 경로·세 선택의 성공/실패 기록과 시드를 함께 남기고, 실패를 숨기거나 자동 검사를 재미의 증거로 제시하지 않는다. 문서와 결과를 확인한 뒤 로컬 커밋: test: verify v2 expedition inputs and presentation.

**수용 기준:** 전체 회귀와 체크포인트 A/B의 실제 시각 결함이 해결되고, 각 경로/선택의 세 전투 완료 근거가 있다. 실제 폰 조작감·실시간 성능·사람의 재미는 별도 검증으로 남긴다. 이 계획의 완료는 main 병합이나 배포를 뜻하지 않는다.

## 실행 순서와 파일 책임

1 → 2 → [3 / 4 → 5] → 6 → 7 → 8 → 9 → 10 순서로 진행한다. 대괄호만 독립 병렬 후보이며, 작은 순차 작업으로 실행해도 결과와 수용 기준은 같다.

| 책임 | 전담 파일 | 동시 편집 제한 |
|---|---|---|
| 물리·계약 | config/geometry/piece/board, selection_rules, preview_session, fixtures 및 해당 검사 | config와 공통 자료 계약은 작업 2 뒤 고정한다. 작업 9는 다른 통합 편집을 마친 뒤 수행한다. |
| 화면 | battle_view/board_viewport/board_effects/skill_cutin, battle_view 씬, 초기 presentation 검사·preview_probe | 순수 규칙 파일을 수정하지 않는다. 작업 6 전에 화면 변경을 마무리한다. |
| 규칙 | combat_rules/skill_rules 및 각각의 검사 | 화면·board·config를 수정하지 않는다. 계약 변경이 필요하면 병렬을 멈추고 먼저 공통 계약을 갱신한다. |
| 통합 | battle/run_rules/expedition/save_store, 진행 씬과 전체 검사·문서 | 작업 6 이후 공유 파일 변경은 순차로 수행한다. |

작업별 검토는 명시한 수용 기준·실패를 확인한 검사·실제 변경 파일을 대조한다. 화면 검토는 구현자와 분리해 실제 픽셀을 확인한다. 마지막에는 변경 전체와 v1 보존을 한 번 더 검토한다. 검토 지적을 해결한 뒤 필요한 검사만 다시 실행하며, 같은 성공 검사를 근거 없이 반복 확대하지 않는다.

## 계획 검토와 실행 방식 선택

이 계획을 검토한 뒤 다음 중 하나를 선택한다. 선택 전에는 제품 코드나 테스트 코드를 작성하지 않는다.

- **작업별 분담과 독립 검토 — 권장:** 작업마다 구현과 검토를 나누고, 공통 계약이 고정된 뒤 화면과 순수 규칙만 파일 책임에 따라 병렬 수행한다. 입력·폭발·저장 경계의 실수를 일찍 발견하기 좋다.
- **순차 직접 실행:** 한 구현자가 이 순서대로 작업하고 마지막에 독립 전체 검토를 받는다. 공통 파일 조율은 적지만 중간의 독립 검토는 줄어든다.

어느 방식이든 기존 모델·환경·권한 범위 안에서 수행하며, 새로운 모델 비용이나 외부 전송 권한을 추가하지 않는다.
