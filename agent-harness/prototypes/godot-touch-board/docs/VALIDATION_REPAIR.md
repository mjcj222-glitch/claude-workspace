# 기존 창 검사 다섯 실패의 분리 진단과 복구

2026-10-22. 기준 `d7f0813059006908df155d405f4d4cb6b9b9d76f`. 게임/아트/오디오 구현은 바꾸지 않았다. 원판 폭탄과 최신 타격 타이밍·물리·밸런스를 그대로 두고 기존 전체 검사의 잘못된 전제와 검사 종료 순서만 고쳤다. Library 전달은 부모가 완료했으며 중복 업로드하지 않았다.

## 항목별 판정

| 기존 실패 | 실제 원인과 컨트롤러 확인 | 수정한 검사/회귀 |
| --- | --- | --- |
| canonical core chain fixture | `reset-fx` OS 클릭이 실제로 `departure`로 돌아간 직후, 캐릭터를 고르지 않은 상태에24패널 fixture를 주입하고 보드를 클릭했다. 원래 실패 화면 `impact-focus/windows/states-360x640-06-chain-preview.png`도 캐릭터 선택 화면이다. 입력 차단은 정상이다. | OS 클릭으로 캐릭터→출발→입구 선택→입장 후 ready 전제를 확인한다. 동일 fixture의 planner가 핵2개를 활성화하는지, OS preview가 그 계획과 정확히 같은지, release가 한 번만 commit하는지 검사한다. |
| reward release opens route | 기본 한 구역 세션의 `choose_relic`은 `_complete_node`를 통해 `map`으로 돌아간다. 옛 `route` 기대값은 짧은3전투 모드의 계약이다. 실제 정상 승리에서 얻은 보상도 유물1회 지급 후 map으로 돌아갔다. | 기본은 map, `--short-run`은 route를 기대하며 유물목록·지급횟수·골드도 검사한다. 새 클릭으로 실제 다음 경로에 진입하는 것까지 확인한다. |
| stale modal release | 종전 검사는 stale release 뒤 map으로 그대로 남은 정상 상태를 `route`가 아니라는 이유로 실패 처리했다. | 보상 좌표와 다음 경로 좌표에 press 없는 release를 보내 phase·offer serial·소거수·골드·보상횟수·미선택 상태가 모두 그대로인지 검사한다. 이후 새 press/release로 선택하고 명시적으로 입장한다. |
| terminal restart victory | UI 문구/컨트롤러는 승리 후 `reset_board()`로 캐릭터 선택에 돌아간다. 검사는 곧장 ready를 기대했다. | departure·미선택 캐릭터·HP30·행동0·골드0·빈 유물을 확인한다. stale release가 캐릭터를 고르지 않는지, 실제 새 클릭으로 첫 전투를 시작하는지 검사한다. 정상 승리에서도 같은 전체 흐름을 실행했다. |
| terminal restart defeat | 위와 동일한 reset 계약이다. 패배를 시험하지 않은 채 승리 결과로 추정하지 않았다. | 패배 modal fixture를 별도로 검사하고, 별도의 자원 주입 없는 attrition 정책으로 HP0 패배→재선택→새 첫 전투를 실제 수행했다. |

이번 재현 범위에서는 사용자 기능 결함을 발견하지 않았다. baseline에서도 실패했다는 사실만으로 판정하지 않고 분기 코드·실제 OS 입력·정상 진행의 결과로 각각 확인했다. 게임 규칙이나 보호용 입력 가드를 바꿔 검사를 통과시키지 않았다.

## 기존 범위 보존과 확장

기존 `tests/capture_quality_states.gd`를 직접 수정했다. 좁은 폭탄 검사로 대신하지 않았다. 충전/잿빛, 스킬 색 선택·취소·실제 발동·cut-in 리셋, 코어 chain/피해, 하트 회복/초과, 보상 press/release, stale modal, 상점 구매·비활성 구매, 유물 설명 열기/닫기, 승리·패배 재시작, 효과·mute 모두 남아 있다.

- 이전 full window: 57개 중5개 실패. 원본은 기존 `evidence/impact-focus/windows/` 및 `legacy-window-before.log` 그대로 보존했다.
- 수정 full window: 360×640,390×844,720×1080 각각90개, 실패0. 실제 인증된 X11 pointer 입력이며 일부 상태·보드는 명시된 fixture다.
- 짧은 탐험 모드: 360×640에서79개, 실패0. 원래 route→다음 전투 경로도 살아 있는 계약으로 별도 확인했다.
- 실제 default main의 정상 자동입력: 승리22소거 HP20·획득 보상3회, 패배20소거 HP0·획득 보상1회. 각 보상 뒤 map/stale release 무시, 두 결과 모두 departure 후 새 ready 전투(HP30/actions0) 확인. 보드·HP·재화·충전 주입이 없는 기존 정책을 썼다. 이번 실행은 headless fixed30fps/`--no-shots`이며 실물·렌더 품질 검증으로 주장하지 않는다. trace 경로의 `movie`는 상속된 driver의 `--capture` 분류명이고 이번에 MovieWriter 영상을 만들지 않았다.

창 로그/이미지는 `evidence/validation-repair/windows/`, 정상 진행은 `normal/`, 요약은 [normal-summary.json](../evidence/validation-repair/normal-summary.json)이다. 기존 실패 이미지와 로그를 덮어쓰지 않도록 driver에 `--validation-repair` 출력 경로와 `--short-run` 전달을 추가했다.

## 추가 회귀와 CI 경계

기존 Godot 회귀 스크립트52개 모두 통과했다(`evidence/validation-repair/regression-run.log`, 상세 `regression/`, 생성 trace `new-motion-regressions/`). 로컬 harness config 검사와 unittest5개도 통과했다. GitHub의 `agent-harness-check`는 harness 구성/단위 검사이며 Godot 실행 검증이 아니다. 위 Godot·OS 창·정상 플레이 결과는 이 클라우드 실행 환경에서 별도로 수행했다.

## ObjectDB 경고

원본 `test_impact_strength.gd --verbose`는 assertion17개가 통과해도 종료 때5개의 `AudioStreamPlaybackWAV`와 관련 WAV 자원 잔존을 보고했다. 이 검사는 첫 프레임에서5개 재생 요청을 곧바로 mute/stop한 뒤 해제했다. 별도 probe에서 같은 assertion·겹침 조건을 유지하고 첫 오디오 처리 시간을50ms 준 다음 mute하자 경고가 없어졌다.

검사에 그50ms 대기와 이유만 추가했다. mute는 호출 즉시 모든 voice를 정지한다는 assertion, mute 뒤 신규 음 재생 억제 assertion도 그대로다. 수정한 verbose 검사3회 모두17개 통과·ObjectDB 경고0이다. 게임 Audio 코드를 수정하거나 경고 출력을 숨기지 않았다. 이 결과를 모든 엔진 오디오 종료 경로의 무누수 보장으로 확대하지 않는다. 원본/diagnostic/반복 로그를 모두 보존했다.

## 추가 실패 기록

첫 복구 검사에서 strict planner 비교가1개 실패했다. planner 원본에는 없는 controller routing metadata `mode="clear"`를 기대값에 반영하지 않은 검사 오류였다. 실제 OS preview는24개 소거와핵2개를 표시하고 commit도 같았다. 기대값에 같은 metadata만 넣어 전체 dictionary 비교를 유지했다. 최초 로그 `first-repair-missing-mode.log`를 보존했다.

## 재실행

```sh
python3 tests/quality_window_driver.py 360 640 --impact --validation-repair
python3 tests/quality_window_driver.py 390 844 --impact --validation-repair
python3 tests/quality_window_driver.py 720 1080 --impact --validation-repair
python3 tests/quality_window_driver.py 360 640 --impact --validation-repair --short-run
godot --headless --verbose --path . --script tests/test_impact_strength.gd
godot --headless --path . --fixed-fps 30 --script tests/play_validation_repair.gd -- --hero=rio --event-free --capture --no-shots
godot --headless --path . --fixed-fps 30 --script tests/play_validation_repair.gd -- --hero=rio --attrition --capture --no-shots
```

OS 입력 검사는 인증된 DISPLAY와720×1080을 담을 framebuffer가 필요하다. 테스트·보고서·public evidence만 변경했다. 실물 기기·주관적 청취·모든 희귀 상태는 별도 미검증이다. 기존 임시 fixture의 한계는 정상 진행 증거와 구분한다. 병합·배포는 하지 않는다.
