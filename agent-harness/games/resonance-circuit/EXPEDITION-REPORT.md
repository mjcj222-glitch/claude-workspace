# 탐험 v1 구현·검증 보고

2026-10-19 · 같은 Draft PR #2 · 변경 범위 `agent-harness/games/resonance-circuit/`.

## 완성된 루프

시작 메뉴에서 연습/탐험 선택 → 6층 지도 → 일반/정예 전투 → 미소유 유물 선택 → 휴식/선택 이벤트 → 최종 보스 → 경로·유물·턴·잔향·피해·회복 결과. 각 층 하나만 선택하며 이전 방/다른 가지로 돌아갈 수 없다. 미선택 경로/선택 경로/앞으로 열릴 경로를 텍스트·선·색으로 구분한다. 지도는 독립 dialog 화면이며 전투 보드/큰 적 배경 너비를 줄이지 않는다.

방의 HP/반격/장막/승리 회복/유물 보상과 이벤트 지불·회복 결과를 선택 전에 표시한다. HP/게이지/유물은 방 사이 유지, 보드/스킬/보호막은 새 전투에서 초기화한다. 일반/정예 이름과 예고로 구분하고 새 아트는 추가하지 않았다. 깊이별 덩굴/무지개 안내를 재사용한다.

연습의 기존 `resonance-circuit-v1` 키와 탐험 `resonance-expedition-v1` 키를 분리한다. 양쪽 version1. 시작·전투·지도·보상·휴식·이벤트·사망·완주를 저장/이어간다. 탐험에는 전투 재도전이 없고 새 탐험은 확인 후 해당 슬롯만 덮어쓴다. 정상 새로고침으로 사망 상태를 되돌릴 수 없다. 사용자가 개발자 도구/외부 백업을 직접 수정하는 행위까지 막는 보안 기능은 아니다.

## 규칙과 구현

정확한8종 유물 수치/발동순서/상한/방 구성은 구현 전 기록한 `EXPEDITION-DESIGN.md`와 `expedition.mjs` 참고. 원본 탭 preview 한 번으로 유물효과를 계산하고 엔진 tap 한 번에 적립한다. 유물 결과를 다시 트리거 입력으로 사용하지 않는다. 고정피해는 과충전 배율 제외, 기존 장막 최종합계 경감은 유지한다. 유물보호 최대12+스킬18=30, 다음 실제 반격에 합산 흡수 후 소진(피해를 전부 막아도 소진), 전투 종료 만료. 회복은 턴정산 반격 전에 적용한다.

지도/방 시드/유물 후보 순서는 보드RNG와 분리하여 시작 시 생성한다. 보상은 전투 종료 때 저장된 순서에서 미소유2개를 확정·저장한다. 조회/preview/리로드는 난수를 쓰지 않는다. 후보가1개면1개,0개면고정HP18. 보상/이벤트/방완료는 동기적으로 적용한 뒤 하나의 localStorage 값으로 저장한다. 입력을 반복해도 phase가 바뀌므로 중복 보상되지 않는다.

기존 engine/campaign/storage/skills/panels/audio/타임라인/원본 PNG는 수정하지 않았다. `app.mjs`의 모드 분기와 새 `expedition.mjs`, `expedition-ui.mjs`가 탐험을 연결한다. 기존 연습 승리HP45·checkpoint retry는 탐험에서 호출하지 않는다.

## 실제 검증

- Node `node --test`: **108/108**. 기존86 + 탐험22. 초기6개 미구현 실패→구현 후 성공(`expedition-red.log`, `expedition-green-initial.log`). 추가 경계 검사에서 초과 사망피해를 회복으로 집계한 오류와 stage/통계 저장 검증 누락을 먼저 재현하고 수정(`expedition-edge-red.log`, `expedition-validation-red.log`). 최종 `expedition-unit-final.log`.
- harness check 성공, Python unittest5/5 성공. 각각 `expedition-harness-check.log`, `expedition-harness-tests.log`. 실제 명령은 게임 폴더에서 `python ../../harness.py check`, `python -m unittest discover -s ../../tests -v`.
- 360×800 / 390×844 / 1280×900 × 일반/축소모션 **6조합** 실제 브라우저 시작→지도→일반전→보상→휴식→정예전→이벤트→보스→완주. 이어서 강제 저체력의 명시적 실패 fixture로 패배→리로드 종결 유지, 재도전 버튼 부재 확인. `expedition-browser-final-{0..5}.log`. 마지막 저장 검증 강화 후390px standalone 전체루프 추가 성공(`expedition-browser-save-final.log`).
- 지도/전투/보상/이벤트 재접속 시 데이터 동일, 보상/이벤트 더블클릭 중복 없음. 연습 저장 바이트 그대로 유지. 브라우저 JS 오류/가로 넘침 없음. 사용 입력은 실제 Playwright 클릭/탭과 중복 재현용 DOM click을 구분해 사용했다.
- 탐험 진행 중 새게임 취소/숨김/모션 전환 **3경로**: 각각 미정산 보존 또는1회 정산, 잠금해제, 재접속 동일상태, 첫턴스킬 유물 중복 발동 없음. `expedition-interrupt-final.log`.
- 키보드 Enter 방 진입, 유물8종 설명, 새게임 확인 취소/확정, 슬롯격리,360px 지도dialog viewport 안에 수용 확인. `expedition-navigation.log`, `expedition-map-viewport-360.png`.
- 기존 연습 일반 ES module/축소 standalone 전체3전투 각1회 성공. `expedition-practice-{normal,reduced}.log`. 소리/안내 소거보존6개, 새게임/숨김/모션 취소3개 기존 회귀 성공(`expedition-settings-regression.log`, `expedition-cancel-regression.log`).

브라우저는 설치된 Chromium+Playwright로 로컬 파일 바이트를 route 공급했다. 네트워크/보안 설정 변경·서버 배포·패키지 설치는 하지 않았다. file URL 직접 열기는 관리 정책 제한 때문에 검수하지 않았다.

## 결정론 실험 (자동 재미 평가가 아님)

`node expedition_sim.mjs` → `expedition-experiment.json`. 8seed×3전략24회, 매 행동 뒤 저장 검증 성공.

|전략|경로/선택|완주|턴 범위|종료 HP|
|---|---|---|---|---|
|safe|일반전+휴식, 방어/회복 우선|8/8|12–16|164–180|
|bold|정예+HP지불 이벤트, 공격/게이지 우선|8/8|13–16|150–180|
|weak 대조|일반전+휴식, 최소 연결·스킬 미사용|0/8|패배27–91|0|

8회 합계 유물 적립(실제 회복/흡수와 구별): safe는 고정피해424·회복315·게이지0·보호552, bold는 피해1480·회복107·게이지225·보호456. seed1은 safe16턴/유물3개, bold14턴/유물5개. 다른 공략과 상호작용이 계산상 작동하는 근거지만 재미/장기균형 증명은 아니다. 현재는 강한 자동전략에 관대한 짧은 입문 탐험이며 인간 플레이에 맞춘 난이도 조정은 남아 있다.

## 전달·실패 기록·한계

`standalone.html` 또는 ES modules로 실행. ZIP을 풀고 standalone.html을 연다. 재패키징 `python package_game.py`. 실제 화면 `expedition-{map,battle,reward,room,boss,result,defeat}-*.png`; viewport 캡처도 확인했다. 게임 규칙 확장 외 영구성장/상점/온라인/계정/서버/현금 요소는 없다.

초기 UI 미구현 실패 로그(`expedition-ui-red.log`)를 보존한다. 영상 기록 첫 시도는 테스트 스크립트가 휴식 방에 이벤트 버튼을 찾는 오류로 실패했으며 게임 상태 오류가 아니었다(`expedition-video.log`). 기록 스크립트를 방 종류로 분기해 수정했고 최종 종료0이다(`expedition-video-final.log`). `expedition-play.mp4`는 실제 Chromium 390×844 화면20초/2,061,395B, 무음. 지도→전투→보상→휴식→정예→이벤트→보스→결과 장면을 원속도로 남기고 중간 반복 탭만 컷 편집했다. 합성 게임 화면/속도 변경은 없다. contact sheet 프레임을 직접 검수했다. 읽으려던 TDD 보조문서 writing-good-tests.md는 제공자에서 읽기 실패했으며 주요 SKILL.md는 읽고 적용했다.

실물 모바일/Safari/Firefox/스크린리더·실제 청취·사람 플레이테스트는 미검증. 저장 실패 시 UI에 표시하고 현재 세션 플레이는 계속되나, 그 환경의 재접속 보존은 보장하지 않는다. 로컬 저장은 주소/브라우저별이며 계정 동기화하지 않는다. main 병합/수동 배포 없음.
