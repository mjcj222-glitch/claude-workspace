# 짧은 3전투 탐험 체크포인트

2026-10-21, Godot4.6.3 Linux/Xorg/llvmpipe. 기준 `dbd16e51235be6da640a1afdf00214db0174bb35`에서 퍼즐·중력·아트·소거 카운터·유물 효과는 유지하고 실제 전투 진행을 연결했습니다. UI/폰트 추가 보강은 보류했습니다. [작은 구현 계획](COMBAT_RUN_PREP.md).

## 현재 플레이

기본 실행은 성장 샌드박스가 아닌 3전투 탐험입니다. 플레이어30/30과 준비된 스킬로 시작합니다. 전투1 HP24/공격4, 전투2 HP36/경감과일반5교대, 전투3 HP48/6·8공격교대입니다. 이 수치는 승인된 실험 가설이며 이번 검증에서 조정하지 않았습니다.

유효 소거3회마다 한 번 반격하며 스킬·무효입력·취소는 행동을 소비하지 않습니다. 현재 소거·회복·핵·충전·예약과 자연 보충을 완료한 뒤 적의 처치를 우선합니다. 반격 피해는 정확히 한 번 처리하며 표시0.45초 뒤 다음 턴/패배로 넘어갑니다. 이0.45초는 낙하 준비 시간을 늘리는 물리 대기가 아닙니다.

전투2 경감 턴 시작 보드에 합법적인 직접4개 묶음이 있으면 `4개 이상 연결을 한 번 지우면 공격 7 → 3`을 예고합니다. 직접 그룹의 고유ID를 세며 하트·기존 핵을 포함하고 추가 연쇄는 제외합니다. 시작에 기회가 없으면 그 턴 전체5공격입니다. 스킬로 나중에 기회를 만들어도 조건이 새로 생기지 않습니다. 잿빛 보석은 이 조건과 별개로 직접 일반 공격6개만 인정합니다.

첫 두 승리에서 미보유 유물 하나를 고르고 명시적인 다음 전투 버튼으로 진행합니다. 생명·충전·요구충전량·유물·미사용 잿빛 예약을 유지합니다. 보드는 기존 일반 초기화기로 새로 만들며 이전 핵/변환은 가져가지 않습니다. 실제 탐험에는 시작7개 연결 색보정이 없습니다. 마지막 승리는 보상 없이 요약, 패배는 도달 전투/처치/유물과 재시작을 제공합니다. 모든 단계에서 리셋하면 세션·물리·효과·음성·입력 후보와 반격 시계까지 초기화합니다.

이전3/6/9행동 성장 샌드박스는 `-- --sandbox`로 명확히 분리했습니다. 실제 탐험은 행동 수로 보상을 지급하거나9회에 종료하지 않습니다. 지도·상점·통화·파티·영구저장·추가 보스 시스템은 없습니다.

## 검증 결과

- 신규 순수 전투43검사, RunSession48검사, 실제 장면 입력81검사 통과. 첫/세 번째 행동 처치 우선, 경감 성공/실패/기회없음·하트·핵 직접 그룹과 추가연쇄 제외, 공격 중복 방지,2/3충전·예약·전투 간 유지,3/6/9이전 보상 억제, 패배·재시작·취소·오래된release를 검증했습니다. 입력/세션 RED→GREEN 기록도 보관합니다.
- 기존14회귀 스크립트 모두 종료0/오류0: 규칙44, 유물64, 피드백32, 표현 장면32, 유물 상세36을 포함하고 기존 상호작용·보상·물리 초기화·중간 경로·10회반복 보충·상단 유입 재현을 유지합니다. 기존 장면 계약은 `-- --sandbox`로 실행했습니다. [회귀 결과](../evidence/combat/regression-results.json).
- 원래 세 경로의 중간 위치 trace SHA256은 `e8df397a4f51546fe4e558ea78d73c26fe60bce42758599e6688aca0e3289087`로 이전과 같습니다. 실제 위치/ID·충돌·위쪽 유입을 바꾸지 않았습니다. 상단 유입 재현은0.816667초 물리 시뮬레이션으로 통과했습니다. [이번 재현 결과](../evidence/combat/refill-inlet-regression.json).
- fixture 없는 정상2시드×3유물쌍6회 모두3전투 승리,17~21소거·최종HP15~30·오류0입니다. 보드/체력/충전 주입이나 강제 좋은 보드를 사용하지 않았습니다. 안료5대상20회, 렌즈11개 강화핵2회, 잿빛 예약13/소비10회, 경감6회가 실제 발현했습니다. 렌즈5개 일반핵 경계와 패배는 이6회에서 미관찰이며 별도 결정적 단위 fixture로 확인했습니다. [정상 시뮬레이션 감사739개 불변식](../evidence/combat/combat-normal-audit.json). 이는 GPU·실시간 성능이나 사람의 조작 실험은 아닙니다.
- 360×640·390×844 실제 XTest 마우스 입력 각각39검사 통과. 화면/제어좌표, 전환 잠금, 보상/다음 전투/유물 상세/재시작을 확인했습니다. 전환 edge 상태는 명시적 입력 검사용 fixture이며 자연 완주 증거와 분리했습니다. [세부 방법](../evidence/combat/WINDOW_TESTS.md).
- 독립 코드/시각 검토는 차단 결함이나 잘림·겹침을 발견하지 못했습니다. [독립 보고](../evidence/combat/independent-review.md).

## 실제 화면과 영상

[소리 포함 정상3전투 영상](../evidence/combat/chroma-three-fights.mp4), 720×1080/30fps/52.93초. 실제 main장면의 press/release·스킬/색선택·자연 낙하·반격·보상·다음 전투를 사용한 자동 합법 플레이입니다. 수동 사람 플레이로 표시하지 않습니다. 고정 MovieWriter 녹화이므로 벽시계 성능 근거가 아닙니다. 보상·전환·최종화면은 읽을 수 있게 유지하며 회색 종료 화면 전에 끝납니다. 기존 합성음이 포함됐고 새 효과음은 만들지 않았습니다. 이 환경의 live오디오 장치는 없어 실제 스피커/모바일 청감은 미검증입니다.

- [시작](../evidence/combat/capture-live/initial.png)
- [승리 보상](../evidence/combat/capture-live/reward-1.png)
- [경감 예고·전투2](../evidence/combat/capture-live/nextfight-2.png)
- [경감 성공](../evidence/combat/capture-live/mitigation-05.png)
- [최종 승리](../evidence/combat/capture-live/victory.png)

별도 실시간 렌더 정상 진행도19소거·반격5회·유물2개·3처치·HP30/30·오류0으로 완료했습니다. [실시간 trace](../evidence/combat/capture-live/trace.json), [고정 녹화 trace](../evidence/combat/capture-movie/trace.json). 실제 화면의 수치와 로그를 독립 검토했습니다.

## 현재 시간 측정과 한계

실시간 llvmpipe 정상 흐름의 누름→다음그림26건은14.90~88.82ms(중앙17.48ms), 기존 핵이 없는 소거16건의 확정→보충완료는756.96~1552.88ms(중앙1148.57ms), 핵 포함3건은1068.57~1827.70ms(중앙1348.83ms)였습니다. 스크린샷 I/O·자동 결정 CPU가 섞인 관찰이며 전용 성능 벤치마크가 아닙니다. 일반0.6~1.0초 목표는 모든 경우 달성하지 않았습니다. 이후 반격 표시0.45초와 사용자 보상 선택 대기는 별도입니다. [관찰 요약/프레임](../evidence/combat/live-summary.json).

실물 Android/iOS, Windows/Web실행, 모바일 터치/오디오 지연과 주관적 재미·장기 밸런스는 미검증입니다. 이번 공개 전달은 Godot 소스와 검증 영상이며 이전 Linux/Web ZIP은 최신 탐험 빌드가 아닙니다. Windows 공식 템플릿403경로를 재시도하거나 우회하지 않았습니다.

## 재현

```sh
godot --path .
godot --headless --path . --script tests/test_combat.gd
godot --headless --path . --script tests/test_run_session.gd
godot --headless --path . --script tests/test_run_input.gd
godot --headless --path . --script tests/play_combat.gd
# 기존 sandbox 장면 계약만 검사할 때
godot --headless --path . --script tests/test_reward_input.gd -- --sandbox
# 인증된 X 디스플레이가 이미 있을 때
godot --path . --audio-driver Dummy --script tests/capture_combat.gd
# 고정 프레임 시청각 기록: 실시간 성능 근거로 사용하지 않음
godot --path . --audio-driver Dummy --script tests/capture_combat.gd --write-movie /tmp/chroma-combat.avi --fixed-fps 30 -- --capture
```

모든 작업은 새 프로토타입 폴더에 한정합니다. 이전 게임/main/배포/계정/보안/유료서비스는 변경하지 않았습니다. 되돌릴 때는 PR의 이번 커밋을 revert하여 기본 실행을 이전 샌드박스로 복구할 수 있습니다.
