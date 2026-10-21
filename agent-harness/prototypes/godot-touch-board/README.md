> **현재 한 구역:** 두 캐릭터를 유지한 채8개 지점에서 휴식/이벤트·안전/정예·추가 전투/상점/보스 직행을 고릅니다. [경로·자원·영상·검증과 한계](docs/AREA.md). 이전3전투 비교 모드는 `-- --short-run`, 기본 실행은 구역 탐험입니다.

> **현재 출발 선택:** 리오의 색 변환과 노아의 핵 심기 중 한 명을 출발 때 확정하고, 기존 탐험과 승패 뒤 선택 복귀까지 연결했습니다. [능력·유물 호환·실제 영상·검증 한계](docs/CHARACTERS.md). 노아 초상은 기존 지원 자산을 공유하는 임시 표시이며, 최신 Windows/Web 실행물은 아직 없습니다.

> **현재 타격 피드백:** 실제 소거→전달→명중·타격음·피해/표시 체력 동기화와 [실제 영상·검증·성능 한계](docs/IMPACT.md)를 추가했습니다. [아직 빠진 시스템과 다음 우선순위](docs/SYSTEMS_STATUS.md)도 구분했습니다. 파티 모집 방향이 아닙니다.

> **현재 체크포인트:** 보라/금색 실제 전투 화면과 점등/충전 스킬 버튼은 [화면·영상·검증](docs/PREMIUM.md), 저장된 seed23 보충 멈춤의 좁은 수정은 [재현·회귀·전체 입력 재생의 한계](docs/REFILL_STALL_FIX.md)에 있습니다. 새 보라색 초상화는 전송 실패로 아직 기존 초상화를 임시 사용합니다. 이전 ZIP은 최신 소스가 아닙니다.

> **현재 표현: 연금술 계기판 품질 보강.** 입체 유리 UI·공식 글꼴·하단 스킬 컷인·피해/회복 효과와 [전후 화면·영상·검증/성능 한계](docs/QUALITY.md)를 추가했습니다. 밸런스와 물리는 그대로입니다.

> **보스 밸런스 비교:** 두 후보는 선택 개선 근거가 없어 기존2/8 조건을 유지했습니다. [비교 결과·검증·미완료 사례](docs/BALANCE.md). 난이도 확정이나 새로운 빌드 배포는 아닙니다.

> **현재 실행: 속성 약점·예고 강타.** 최종색의 약점 일반 패널2개당 피해+1, 마지막 적의 현재 보드에 가능한 강타10→4/일반6을 연결했습니다. [현재 검증과 영상](docs/ELEMENTAL.md). 밸런스 가설이며 최신 ZIP은 아직 없습니다.

> **이전 체크포인트: 경로·골드·작은 상점.** 첫 승리 뒤 안전/정예 경로를 고르고, 둘째 승리 뒤 회복/남은 유물을 구매한 후 마지막 전투로 갑니다. [현재 검증과 영상](docs/ROUTE_SHOP.md). 새 ZIP은 아직 만들지 않았습니다.

> **이전 체크포인트: 3전투 짧은 탐험.** 적의 반격 예고 → 승리 유물 → 다음 전투 → 최종 승리/패배를 연결했습니다. [계약과 검증](docs/COMBAT.md). 아래 ZIP은 갱신하지 않은 이전 자료입니다.

> **현재 표현 보강:** 큰 파괴 개수·핵 발동 수·유물 아이콘/보유 설명과 [화면·영상·검증](docs/PRESENTATION.md)을 추가했습니다. 실행은 최신 Godot 소스 기준이며 이전 ZIP은 갱신하지 않았습니다.

> **이전 성장 실험 (`--sandbox` 전용):** 유물3종 중3회·6회에 하나씩 선택하고9회에 구간 요약을 봅니다. [구현·실제 검증](docs/GROWTH.md). 기존 ZIP은 이 소스의 실행 파일이 아닙니다.

> **최신 품질 보강:** 원본 캐릭터·표적, 작은 창 조작 검사와 긴 연쇄 단축 결과는 [품질 보고](docs/POLISH.md)에 있습니다. 기존 ZIP은 업데이트하지 않았습니다.

> **성능 후속 수정:** 동일 경로를 유지한 계산 최적화와 실시간 전후 측정은 [성능 보고](docs/PERFORMANCE.md)를 확인하세요.

> **2026-10-21 모션 수정:** 아래 최초 체크포인트의 영상·Linux/Web ZIP·성능 수치는 `5819dd8`의 이전 재배치 방식입니다. 최신 수정과 비교 증거는 [모션 수정 보고](docs/MOTION_FIX.md)를 확인하세요. 기존 ZIP은 이번 수정 빌드가 아닙니다.

# CHROMA / Touch Lab

새로 만든 Godot 손맛 검증용 보드입니다. 기존 게임 코드·UI·자산은 재사용하지 않았습니다. 완성 게임이나 재미 검증 완료본이 아닙니다.

## 플레이
- 출발 화면에서 한 명을 선택하고 출발을 확정합니다. 한 판 도중 변경할 수 없고 승패·리셋 후 선택으로 돌아옵니다.
- 노아의 핵 심기는 일반 공격 패널1개를 같은 ID·위치·색의 물감핵으로 바꾸며 즉시 소거나 피해는 없습니다. 다음 입력에서 핵을 눌러 기동합니다. 번짐 안료는 심는 핵만 강화핵으로 만듭니다.
- 같은 색의 붙은 패널을 누르면 흰 윤곽(직접), 금색 점선(추가 연쇄), 피해·유효 회복을 미리 봅니다. 놓으면 그 계획을 실행합니다. 보드 밖 이동/초점 상실은 취소됩니다.
- 일반/하트는 2개부터. 직접 일반 공격 패널6~11개는 일반 물감핵,12개 이상은 강화핵을 만듭니다. 응축 렌즈를 고르면 기준이5/11개로 바뀝니다. 핵은 다음 행동부터 사용합니다.
- 핵은 하나만 눌러도 발동합니다. 속성은 색 테두리와 작은 문양입니다. 일반은 접촉 1단계, 강화는 2단계 변환/연쇄이며 하트는 보호됩니다.
- 리오는 아래 변환 버튼 → 색 선택 → 일반 패널을 눌러 최대 4개 변환 미리보기 → 놓아 적용. 스킬은 자동 소거하지 않고 소거 횟수를 쓰지 않습니다. 번짐 안료를 고르면 최대5개가 됩니다. 기본 수동 소거3회로 재충전되며 잿빛 보석은 직접 일반6개 소거로 다음 스킬 사용 후의2회 충전을 예약합니다.
- 현재 실행은 3전투 탐험입니다. 생명30과 준비된 스킬로 시작하며 유효 소거3회마다 예고된 반격을 받습니다. 일반당 피해1, 하트당 회복2입니다. 처치하면 반격보다 승리가 우선합니다.
- 전투1(HP24, 공격4), 전투2(HP36, 경감/일반5교대), 전투3(HP48, 가능한 강타10→4와 일반6교대)는 실험 수치입니다. 경감 조건은 턴 시작에 기회가 있을 때만 예고하며 직접4개 연결을 한 번 소거하면7→3피해로 줄어듭니다.
- 적의 약점은 첫 적 불꽃, 안전 적 새잎, 정예 적 번개, 마지막 적 물결입니다. 실제 제거된 일반 패널의 변환 후 색으로 약점수를 합산하고2개당 피해+1을 한 행동에 한 번 더합니다. 하트·핵 자체는 보너스 대상이 아니며 일반색 저항/페널티는 없습니다.
- 마지막 강타는 한 번에 약점 일반2개 또는 일반 공격8개를 제거하면10→4로 약해집니다. 해당 턴 시작에 이미 가능한 소거가 없으면 그 턴은 일반6이며 나중에 조건을 추가하지 않습니다. 다음 홀수 턴도 일반6입니다. 미리보기·스킬·취소는 자체적으로 경감을 얻지 않습니다.
- 첫 승리에서4골드와 첫 유물을 얻고 **안전한 길/정예의 길**을 고릅니다. 안전은 기존HP36·공격7→3/5·승리4G, 정예는HP44·공격8→4/6·승리8G입니다. 경감 기회가 없을 때 안전5/정예6입니다.
- 둘째 승리에서 경로 골드와 둘째 유물을 얻은 뒤 작은 상점에 갑니다. 안전8G/정예12G로 회복(최대8HP·4G·한 번)과 남은 유물(8G·한 번)을 선택 구매합니다. 최대HP에서는 회복이 비활성이며 골드/재고를 소비하지 않습니다.
- **최종 전투로**를 누르면 상점을 떠나며 다시 열지 않습니다. 생명·스킬충전·유물·예약·잔액을 유지하고 보드만 새로 만듭니다. 마지막 승리는 골드를 주지 않습니다. 종료 화면은 경로/사용·남은골드/유물/결과를 표시하고 새 탐험으로 모두 초기화합니다.
- 이전3/6/9행동 성장 실험은 `-- --sandbox`로만 실행하며 실제 탐험에는 행동수 보상이나9행동 종료가 없습니다.
- 리셋은 캐릭터 선택으로 돌아가며 보드·체력·유물·보상·예약·충전·구간 기록을 모두 초기화합니다. 보충·반격·전환 중에는 리셋 외 보드 입력을 무시합니다. 소리 버튼으로 음소거하며 효과 버튼은 움직임·섬광을 줄입니다.

## 실행
Godot 4.6.3에서 이 폴더의 `project.godot`를 열고 실행하거나:

```sh
godot --path agent-harness/prototypes/godot-touch-board
```

아래 두 ZIP은 최초 체크포인트 `5819dd8`의 보관 자료입니다. **현재 성장 실험이나 최신 낙하·화면을 포함하지 않습니다.** 최신 소스는 위 Godot 명령으로 실행합니다.

`deliverables/chroma-linux-x86_64.zip`은 이전 Linux x86_64 독립 실행 파일입니다. 압축을 풀고 `chmod +x chroma.x86_64` 후 실행합니다. 이 클라우드의 Xorg/llvmpipe에서 실제 실행했습니다.

`deliverables/chroma-web.zip`은 내보낸 Web 파일 묶음입니다. 압축 해제 후 해당 폴더에서 `python3 -m http.server 8000`을 실행하고 `http://localhost:8000`을 엽니다. 외부 배포하지 않았습니다. Chromium 보안 샌드박스 오류로 이 환경의 Web 실행 검증은 중단했으며, Web 빌드는 **미검증**입니다. 브라우저의 첫 터치/클릭이 소리 재생을 허용해야 합니다.

## 검증
```sh
godot --headless --path . --script tests/test_rules.gd
godot --headless --path . --script tests/test_relic_rules.gd
godot --headless --path . --script tests/test_growth_session.gd
godot --headless --path . --script tests/test_combat.gd
godot --headless --path . --script tests/test_run_session.gd
godot --headless --path . --script tests/test_run_input.gd
godot --headless --path . --script tests/test_route_combat.gd
godot --headless --path . --script tests/test_route_economy.gd
godot --headless --path . --script tests/test_route_input.gd
godot --headless --path . --script tests/test_transition_reentry.gd
godot --headless --path . --script tests/test_elemental_rules.gd
godot --headless --path . --script tests/test_boss_combat.gd
godot --headless --path . --script tests/test_elemental_session.gd
godot --headless --path . --script tests/test_elemental_input.gd
godot --headless --path . --script tests/test_elemental_ui.gd
godot --headless --path . --script tests/test_reward_input.gd -- --sandbox
godot --headless --path . --script tests/test_refill_inlet.gd
godot --headless --path . --script tests/test_motion_paths.gd
godot --headless --path . --script tests/test_motion_cycles.gd
godot --headless --path . --script tests/test_interaction.gd
godot --headless --path . --script tests/test_scene.gd -- --sandbox
```
실제 렌더러에서 `tests/capture_board.gd`는 캡처, `tests/live_benchmark.gd`는 실시간 벽시계/프레임 기록을 만듭니다. 후자는 테스트 전용 자동 입력입니다. `-- --sandbox --demo --capture`는 고정 영상 제작용이며 `--write-movie`와 함께 사용합니다. 테스트·증거 파일은 배포 빌드에서 제외합니다.

화면·영상·측정은 `evidence/`, 실행 계약과 판단은 `docs/`에 있습니다. 영상은 고정 프레임 녹화로 입력 성능 근거가 아닙니다. Android 실물, 모바일 음향·지연, 사용자 재미는 미검증입니다. 넓은 지도·영구 저장·파티·추가 적/보스 콘텐츠·피버는 없습니다. 골드는 게임 안에서만 쓰며 실제 결제는 없습니다.

## 자산
패널: 이번 승인된 새 원본 PNG atlas. `assets/ART.md` 참조. 캐릭터/표적: 승인된 원본 RGBA PNG 초상/젤리 골렘. 이번 성장 단계는 새 그림·효과음·VFX를 추가하지 않았습니다. 효과음: 새 합성 PCM(6 voices 제한). 글꼴: 시스템 Noto Sans CJK의 한국어 부분집합, SIL OFL(`assets/FONT-LICENSE.txt`). 사용자 참조 원본 이미지는 포함하지 않습니다.
