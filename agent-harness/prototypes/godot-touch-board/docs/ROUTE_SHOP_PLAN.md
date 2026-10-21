# 경로·작은 상점 구현 계획

> **For agentic workers:** Use TDD task-by-task; independent files may be delegated, then integrate and review the whole change. Checkboxes are the durable progress ledger.

**Goal:** 기존3전투에 안전/정예 경로, 승리 골드, 선택적인 작은 상점을 연결합니다.
**Architecture:** 전투 수치는 Combat, 재화/구매/진행은 RunSession, 입력/화면은 main/UI가 소유합니다. 현재 접촉·낙하·스킬·유물 계획은 유지합니다.
**Tech Stack:** Godot4.6.3/GDScript, 기존Xorg/FFmpeg. 새 의존성·아트·폰트 없음.
**Spec:** 이 문서의 아래 승인 계약(부모 전달2026-10-21), 기준61a8bf18a29c94781ff0abc7fbb4581da378f784.

## 전역 제약

새 프로토타입 폴더만 변경하며 PR3/feat/resonance-godot만 커밋·푸시합니다. main·옛 게임·배포·구매·계정·보안·네트워크 설정은 변경하지 않습니다. UI/폰트 꾸미기·광범위지도·새화폐/유물/퍼즐규칙·다음 콘텐츠는 제외합니다. 모든 수치는 밸런스 가설입니다.

## 승인 계약

시작0G. 전투1 승리4G+첫유물 → 안전/정예 경로 선택. 안전: 기존2전투HP36/경감7→3/일반·기회없음5/승리4G. 정예: HP44/각 실제공격+1(8→4,일반·기회없음6)/승리8G. 경로 카드는 확정 전에 HP·공격·승리G를 표시합니다. 한 번 확정하고 정상 초기화기로 전투2를 시작합니다.

전투2 승리 골드+둘째유물 → 상점. 안전8G/정예12G. 재고는4G로최대8HP회복1회,8G로남은미보유기존유물1개구매1회뿐입니다. 회복은 현재 가능한 유효회복을 미리 표시하며 최대HP에서 비활성/재고보존/과금없음입니다. 저잔액·품절·중복은 무변경. 구매는 차감·효과·재고를 원자적으로 적용하고 스킬·행동·턴을 진행하지 않습니다. 선택적 구매 뒤 명시적 '최종 전투로' → 기존3전투, 상점 재입장 불가. 마지막 승리는 골드를 주지 않습니다.

체력·충전·요구량·유물·잿빛 예약은 전투 사이 유지하며 유물 구매는 기존 비소급 획득입니다. 재시작은 경로·골드·재고·방문·보상·기존상태/시계/입력을 초기화합니다. 종료 화면은 경로·사용/잔액G·유물(구매시3개)·결과를 표시합니다. 실제 결제/현금은 없습니다.

## Review Focus

1. 같은 승리 완료를 반복해도 전투별 골드/유물은 한 번만 지급.
2. route/shop/전투 사이 오래된 해제·추가 손가락·이중 클릭은 잘못된 구매/소거로 통과하지 않음.
3. 최대HP/부족·정확잔액/품절/두구매순서에서 차감·재고·효과 일치.
4. 상점 나가기/리셋 후 오래된 후보·완료 호출이 재화나 새 전투를 변경하지 않음.
5. 세 번째 유물과 기존 충전/예약의 유지·비소급, 작은 창 읽기/제어좌표.

## Task1: 경로 전투 수치 (rules)

Files: scripts/board_combat.gd, tests/test_route_combat.gd.
Interface: Combat.ROUTES[safe|elite]={name,hp,gold,pattern}; route:String; start_fight(index,panels,selected_route='safe'). 기존2인수 호출은 안전 경로.
- [x] RED: 정예HP44,경감8/4,일반·fallback6,기존1/3전투불변·중복공격/처치우선 assertions를 먼저 실행.
- [x] 최소 구현 후 `godot --headless --path . --script tests/test_route_combat.gd`와 기존test_combat 모두0실패.

## Task2: 재화·상점·흐름 (render_env)

Files: scripts/board_run_session.gd, tests/test_route_economy.gd, tests/test_run_session.gd.
Interface: route='',gold=0,gold_spent=0,shop_heal_sold/relic_sold/closed=false; choose_route(id)->bool; buy_shop('heal'|'relic')->bool; leave_shop()->bool; shop_heal_gain()->int; shop_remaining_relic()->String.
첫choose_relic→route,둘째→shop. choose_route/leave_shop→between,기존begin_next_fight가새보드ready. 유효구매는offer_serial증가로오래된후보무효화.
- [x] RED: 중복승리/경로확정/8·12G/정확·부족잔액/회복8·상한·full/두구매순서/품절/미구매출구/3유물carry/최종무지급/리셋.
- [x] GREEN: 새test_route_economy와의도한흐름만갱신한test_run_session 통과. 이전검사범위는삭제하지않음.

## Task3: 실제 입력·UI 연결 (root/reference)

Files: scripts/main.gd, scripts/board_ui.gd; tests/test_route_input.gd, tests/test_run_input.gd; tests/test_route_window.gd,tests/route_window_driver.py.
Interface: UI.route_rect(i),UI.shop_rect(i)=Rect(64,350+156*i,592,140); shop출구=SUMMARY_CONTINUE. route/shop은모달이며board/skill/owned차단·리셋예외. 경로/출구의새누름해제만정상보드생성을호출. 재화계산은Session에만둠.
- [x] RED: 실제 장면 route카드 제스처가 한 번 전투2로 이동해야 하며 아직 미연결임을 확인.
- [x] GREEN: 신선한후보/serial/취소/추가손가락/이중입력/리셋/관통방지 검사. 현재 UI에필요한숫자와설명만추가.
- [x] 360×640,390×844 XTest마우스입력과실제픽셀검토. edgefixture는정상완주와명확히분리.

## Task4: 정상 진행·회귀·영상 (visuals/root)

Files: tests/play_route_shop.gd,tests/capture_route_shop.gd,evidence/route-shop/*,docs/ROUTE_SHOP.md,README.md.
- [x] 안전/정예×기존3유물쌍 최소6정상진행. 자연초기화·보충/실제begin-release,forcedG/HP/charge·중간fixture없음. 모든결과/선택정책기록,solver승리를밸런스증명으로쓰지않음.
- [x] 기존규칙·유물·연결·피드백·입력·중간경로·반복보충·상단유입 회귀유지. 기존증거를덮으면이번폴더에보존한뒤원본복원.
- [x] 실제정상route→shop→최종전투 소리영상·화면. 읽을수있는정지구간/회색종료없음. 실시간측정과고정30fpsMovieWriter를분리.

## Task5: 독립 검토·저장 (review/root)

- [x] 독립코드·시각검토후중요결함수정및필요회귀. 새디자인/선택적폴리시확대없음.
- [x] 완료·미검증·실제수치·증거보고와새프로토타입저장범위검증. 커밋/기존PR3푸시·로컬/원격해시와작업트리는최종도구결과및최종보고로확인.

## 진행 기록

- 준비: 저장소지침/스킬,로컬·원격기준,파일책임/API를확인했습니다. 확인된Godot4.6.3/FFmpeg7.1.5. Godot버전단독조회는fontconfig캐시경고를냈으며 렌더검사는기존/tmp/chroma-tools/env.sh의쓰기가능XDG경로를사용합니다.
- 판단: 경로카드의새누름·해제가최종확정이며즉시정상전투2로진입합니다. 상점출구도새누름·해제후기존전투3로진입합니다. 불필요한추가확인모달은만들지않습니다.
- 판단: 게임의재화와구매는RunSession한곳이검증하고UI는표시/의도전달만담당합니다. 기존순수Combat/물리/계획계산을재사용합니다.

- 검토 수정: 경로/상점 출구의 실제 마우스 이중 클릭과 터치 재탭을 새 fixture에서4건실패로 재현했습니다. 출구 위치44논리px 내500ms 재탭과 해당위치의OS이중클릭만 무시하고 다른위치는즉시입력됩니다. 의도적인아주빠른동일위치첫보드탭도무시될수있는비용이있으며 전체보드준비/물리/연출대기는추가하지않습니다. 리셋시이기록도초기화합니다.

- Task1 완료: 경로 전투32/0·기존43/0. Task2 완료: 경제58/0·기존세션51/0. Task3 완료: 경로입력55/0·전투입력95/0·재입력22/0,수정후OS360/390각44/0·legacy36039/0. Task4 정상12/12승리·1198감사통과/전체21회귀스크립트종료0,물리경로SHA원본동일. 실제녹화/마지막저장은진행중.

- Task4 완료: 별도실시간/고정30fps정상흐름모두18소거·HP24·사용12G/잔액0·3유물승리. 영상54.7초/AAC비무음·회색종료없음. Task5 검토완료,커밋/푸시/원격대조진행예정. 목표미달표본(243ms반응,일반최대2.091초)을최종보고에유지합니다.

- 최종검토: 영상13초경로/35초상점/마지막프레임독립확인,읽기가능한정지구간과회색종료없음을확인했습니다. 추가중요결함없음. 공개저장범위와실제커밋/원격확인은마지막실행결과를기준으로합니다.
