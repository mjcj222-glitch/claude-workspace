# 잔향 회로 · Godot 전투 프로토타입

**v1 보존 기록: 주인공 3포즈·Kenney 효과·입체 기물을 통합하고 검증한 한 전투 프로토타입.** PR #3의 `74a92ac`에 이어 아트와 창 크기별 입력 검증을 보완했다. 웹판과 main은 보존했다. APK나 최종 게임이 아니다.

## 별도 v2 탐험 실행

v2는 솔로 시작 → 경로 선택 → 첫 동료 모집/주인공 강화 → 세 번째 관문의 세 전투 탐험이다. 기본 실행은 계속 v1이다. v2를 실행하려면 씬을 명시한다.

```sh
cd agent-harness/games/resonance-godot
godot res://scenes/v2/expedition.tscn -- --no-save
# 원래 v1
godot res://scenes/battle.tscn -- --no-save
```

v2에서는 같은 문양의 접촉 그룹 3개 이상을 누른 채 제거 예고를 보고 놓아 확정한다. 보드 밖으로 이동했다 돌아오거나 취소·포커스 상실·창 크기 변경이 생기면 취소한다. 한 턴은 유효 제거 3회이며, 팀 스킬은 제거 횟수 없이 턴당 한 번이다. 주인공은 초상 → 목적색 → 기물 순서로 변환하고 0.7초 컷인 뒤 복귀한다. 방향키와 Enter/Space, 스킬 1/2/3, 목적색 R/Y/B도 지원한다.

제거 예고의 `회복 누적+N / 실효+M`은 이번 행동이 쌓을 원래 회복량과 현재 HP·이미 쌓인 회복을 반영한 실효량이다. HP 줄의 `회복 +N`은 이전까지 쌓인 값이다. 폭약사의 파랑0 환불이 실제 정산되면 상한을 적용한 반환량과 지불 비용을 하단에 알리고, 전투가 끝나면 다음 선택·완료·패배 화면으로 알림을 넘긴다. 새 행동 확정·선택·새 탐험·재개 때 지우며 저장된 환불 표식을 새 알림으로 재생하지 않는다.

매칭과 주인공/정원지기 탐색은 hull 사이 **총 간격1.75 논리px 이하**를 사용한다. 물리 지지는1.0을 유지한다. 양쪽을 각각1.75씩 넓힌3.5가 아니며, 선택 테두리의 두께는 연결 판정에 들어가지 않는다. 시드121의 추가 접촉 사례와 초기35↔34 분리 사례를 함께 회귀 검사한다.

v2 저장은 `user://resonance_godot_v2.json`에 새로 기록하며 v1 저장을 읽거나 변환하지 않는다. 검사는 임시 절대 XDG 경로와 `--no-save`를 사용한다. 저장 검사의 명시적 fixture 슬롯도 그 임시 공간 안에만 만든다.

```sh
export XDG_DATA_HOME=/tmp/resonance-v2-check/data
export XDG_CONFIG_HOME=/tmp/resonance-v2-check/config
export XDG_CACHE_HOME=/tmp/resonance-v2-check/cache
godot --headless --fixed-fps 120 --script tests/v2/full_expedition_test.gd -- --no-save
godot --headless --fixed-fps 120 --script tests/v2/window_input_test.gd -- --no-save
godot --headless --fixed-fps 120 --script tests/v2/feedback_test.gd -- --no-save
# 기존 인증된 로컬 X11 DISPLAY/XAUTHORITY가 있는 경우에만 실행
python3 tools/v2/run_os_input_probe.py --output-dir /tmp/resonance-v2-os-evidence
# 실제 그래픽 창의 정상 탐험 + 화면에 표시된 별도 기능 fixture 기록
godot --resolution 720x1280 --script tools/v2/record_expedition.gd -- --no-save
```

리필은 이미 한 번 추첨한 배치를 순서대로 유지하고, 현재 실제 hull 기하에서 보드 폭 전체의 유한 높이 입구를 계산한다. 한 process-frame 묶음에서 성공·막힘을 합쳐 한 번만 입구를 계산하며, 다음 계산은 움직인 몸체를 다시 읽는다. 전체12초 물리 시계·42개 정착·28quiet·경계/지지 검사는 유지한다. 모든 상태의 성공이나 지연 상한을 보장하지 않으며 실패하면 ERROR로 멈춘다.

현재 데스크톱 개발 미리보기에서 연속 유입의 프레임별 집중 비용을 줄였지만 실시간60fps 합격은 아니다. 실제 세 표본의 단일 계산 최대23.200ms, 선택 계산이 없던 입력/렌더 구간 최대70.152ms를 남긴다. 실제 놓기→READY는 약2.66–5.31초였으며, 영화의 고정60fps 명목 길이와 구별한다. 휴대폰 성능·사람의 재미는 별도 검수다.

`inlet_history_test.gd`는 별도 역사적1.0 매칭 fixture 프로젝트에서 원래 실패 이력과 몸체를 보존한 채 대상 Board만 현재 소스로 교체한다. 현재1.75 규칙의 정상 완주와 구별한다. 별도 현재 Board 물리 검사는 원래7개 제거와 대형 합집합 투입을 검사한다. 저장 검사는 `XDG_DATA_HOME`에 `/xdg/task8-`가, 복구 검사는 `/xdg/task9-`가 포함된 전용 절대 fixture 경로를 요구한다.

```sh
# 고정 fps나 Movie Maker 없이 실제 그래픽 창에서 보통3–8개 제거 다섯 건의 시간·엔진 동기 경과시간 표본(프로세스 CPU 아님)
# 이 실행은 전체 탐험 승리 검사가 아니다.
godot --resolution 720x1280 --script tools/v2/record_expedition.gd -- --no-save --timing-only --capture-dir=/tmp/resonance-v2-timing-fresh
```

`full_expedition_test.gd`의 정상 완주 정책은 현재 정착 보드의 접촉 그래프와 합법적 변환만 읽어 비교한다. 실제 컨트롤러의 누름/놓기, 물리 리필과 Run 선택을 사용하며 미래 리필·자원 보정·적 HP 보정·종료 상태 주입을 하지 않는다. 별도 상태 전이 및 영상 기능 fixture는 정상 승리 근거로 세지 않는다. 합성 터치는 엔진 이벤트 주입이며 OS 마우스 검사는 인증된 XTest 입력이다.

[최신 실제 플레이/기능 미리보기](evidence/v2-local/final-expedition/README.md)와 최종 수치·실패 기록·완주 시드·물리와 영상 시간의 구분은 [VALIDATION.md](VALIDATION.md)의 v2 기록을 따른다. 자동 완주는 휴대폰 조작감, 실시간 성능, 사람의 재미를 입증하지 않는다.

## v1 전투 보존 기록

Godot 4.6.3에서 `project.godot`을 열고 F6/F5로 실행하거나 다음 명령을 사용한다.

```sh
godot --path agent-harness/games/resonance-godot
```

기물을 누르면 실제 제거 예정 범위와 피해/회복을 보여 주고, 같은 위치에서 떼면 확정한다. 드래그·취소·다중 입력은 정산하지 않는다. 방향키로 선택하고 Enter/Space로 확정할 수 있다. 세 스킬은 탭을 쓰지 않으며 첫 턴부터 사용 가능하다. 3번 선택 후 회복·공격·적 반격을 정산한다. 8개 직접 연결은 대형 폭탄을 남긴다. 과충전은 게이지55 이상이고 턴 첫 선택 전에 사용할 수 있다. 기본 무음이며 움직임 줄이기를 지원한다.

저장은 Godot `user://resonance_godot_v1.json`에 별도로 기록한다. 웹 저장 호환을 제공하지 않으며 `-- --no-save`로 저장 없이 실행할 수 있다.

- [현재 검증 및 남은 한계](VALIDATION.md)
- [로컬 통합 결과와 남은 제한](LOCAL-INTEGRATION.md)
- [새 실제 네이티브 첫 턴 영상](evidence/local-integration/local-play.mp4)
- [이전 전송 차단 진단](TRANSFER-DIAGNOSIS.md)

- [최소 전투 설계](DESIGN.md)
- [캐릭터/효과 제작 사양](ART-CONTRACT.md)
- [실제 환경 검사](ENVIRONMENT.md)

자동 검사는 다음과 같다.

```sh
cd agent-harness/games/resonance-godot
godot --headless --script tools/environment_probe.gd
godot --headless --fixed-fps 120 --script tests/rules_test.gd -- --no-save
godot --headless --fixed-fps 120 --script tests/battle_test.gd -- --no-save
godot --headless --fixed-fps 120 --script tests/full_battle.gd -- --no-save
godot --headless --fixed-fps 120 --script tests/presentation_test.gd -- --no-save
```

쓰기가 제한된 환경에서는 Godot의 프로세스별 XDG 데이터/캐시 경로를 쓰기 가능한 임시 폴더로 지정했다. 계정·보안·네트워크 설정은 변경하지 않았다. 추가 결제·main 병합·배포는 하지 않는다.

`tools/native_input.gd`는 검사 도구의 논리 좌표를 실제 창 좌표로 변환한다.
`tests/window_input_test.gd`는 네 창 크기의 합성 터치를 검증했고,
`tools/run_os_input_probe.py`는 인증된 로컬 X11 화면에서 XTest 마우스로
스킬·예고·제거·리필·재시작과 실행 중 창 크기 변경을 검증했다.
이 자동 OS 입력은 사람의 플레이 검수나 휴대폰 터치 검증을 대신하지 않는다.
