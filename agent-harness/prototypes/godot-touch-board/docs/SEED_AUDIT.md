# 다중 시드 탐험 감사 — 2026-10-22

기준 runtime: `cd1944f1ddbf4cfbc995786bc66cf81fd9b5c24c`. 관찰용 harness와 보고서만 추가했으며 게임 규칙·밸런스·물리·외형·음향·저장 구현은 바꾸지 않았다. 기존 Windows 후보는 그대로 사용하며 새 ZIP을 만들지 않는다.

## 방법과 판정

고정 시드1/42/314159/20261021 × 리오/노아 × 안전/안전상점/위험 경로24회와 실제 구매 대조4회. Godot4.6.3 headless fixed-fps30, 실제 main scene의 press/release·일반 초기화·자연 낙하·격리된 저장 디렉터리를 사용했다. HP·보드·골드·phase·RNG를 주입하지 않았다. 각 실행은120초 및140소거 제한이었다.

모든 합법 소거와 스킬 후보를 계산하는 탐욕 정책이다. 즉시 처치를 우선하고 경감 조건, 피해, 낮은 HP의 회복을 선호한다. 노아는 핵 설치 후 즉시 점화 계획을, 리오는 연결 확장을 탐색한다. 이는 사람의 판단 속도·정보 탐색·실수를 재현하지 않는다. 의도적 작은 표본의 완주 결과를 통계 승률이나 재미 검증으로 해석하지 않는다.

기존 safe-shop 정책은 상점에 들러도 구매하지 않아, 두 시드×두 캐릭터의 별도 `+shop-buy` 실행으로 구매를 확인했다. 이 차이를 게임의 구매 실패로 오인하지 않았다.

## 실행별 결과

|시드|캐릭터|경로|정책|결과|소거|종료 HP|구매|실패 기준|
|---:|---|---|---|---|---:|---:|---:|---|
|1|rio|safe|intent-aware|victory|17|15|0|없음|
|1|rio|safe-shop|intent-aware|victory|17|15|0|없음|
|1|rio|risk|intent-aware|victory|20|30|1|없음|
|1|noa|safe|intent-aware|victory|15|30|0|없음|
|1|noa|safe-shop|intent-aware|victory|15|30|0|없음|
|1|noa|risk|intent-aware|victory|23|30|1|없음|
|42|rio|safe|intent-aware|victory|20|18|0|없음|
|42|rio|safe-shop|intent-aware|victory|20|18|0|없음|
|42|rio|risk|intent-aware|victory|23|26|1|없음|
|42|noa|safe|intent-aware|victory|13|29|0|없음|
|42|noa|safe-shop|intent-aware|victory|13|29|0|없음|
|42|noa|risk|intent-aware|victory|19|30|0|없음|
|314159|rio|safe|intent-aware|victory|13|26|0|없음|
|314159|rio|safe-shop|intent-aware|victory|13|26|0|없음|
|314159|rio|risk|intent-aware|victory|22|30|1|없음|
|314159|noa|safe|intent-aware|victory|13|30|0|없음|
|314159|noa|safe-shop|intent-aware|victory|13|30|0|없음|
|314159|noa|risk|intent-aware|victory|13|26|0|없음|
|20261021|rio|safe|intent-aware|victory|12|30|0|없음|
|20261021|rio|safe-shop|intent-aware|victory|12|30|0|없음|
|20261021|rio|risk|intent-aware|victory|19|30|1|없음|
|20261021|noa|safe|intent-aware|victory|16|30|0|없음|
|20261021|noa|safe-shop|intent-aware|victory|16|30|0|없음|
|20261021|noa|risk|intent-aware|victory|21|30|1|없음|
|1|rio|safe-shop|intent-aware+shop-buy|victory|17|20|1|없음|
|1|noa|safe-shop|intent-aware+shop-buy|victory|15|30|1|없음|
|42|rio|safe-shop|intent-aware+shop-buy|victory|21|24|1|없음|
|42|noa|safe-shop|intent-aware+shop-buy|victory|12|29|1|없음|

경로: safe=입구→휴식→안전→보스, safe-shop=입구→휴식→안전→상점→보스, risk=입구→이벤트→정예→추가정예→상점→보스. 각 결과 JSON의 history로 실제 경로를 확인할 수 있다. 모든 종료 후 새 캐릭터 선택·출발·첫 전투까지 확인했다.

## 예고·미리보기·진행 검사

- 463회 실제 소거에서 눌렀을 때 계획과 commit 계획, 소거 횟수 증가, 적 HP 감소·유효 회복을 대조했다. 불일치0.
- 186개 예고 시작 보드를 첫 행동 전에 관찰했다. 활성 경감 예고는 모두 해당 보드에 만족 가능한 합법 시작 패널이 있었다.
- 시작 패널 개수는 서로 같은 체인에 속한 패널도 포함하므로 독립 해결법 개수가 아니다. 이후 행동/스킬로 기회가 사라지는 경우를 최초부터 불가능한 예고와 혼동하지 않는다.
- no-legal-clear, stalled refill/해결 제한 초과, 스킬 적용/소거 무료 횟수 계약, 잘못된 경로 전환, 중복 보상, 저장 오류, 종료 후 재출발 실패는 관찰되지 않았다.

|전투|관찰 턴|경감 활성|일반 공격 대체|활성 시 최소 유효 시작 패널|
|---|---:|---:|---:|---:|
|entry|46|0|0|해당 없음|
|safe|41|20|3|5|
|boss|66|34|3|2|
|elite|17|9|1|5|
|extra|16|9|0|4|

## 초반 난이도 해석

구현의 적 HP는 입구24→안전36/정예44→보스48이며, 일반 반격은4→5/6→6이다. 조건부 공격은 안전7→3·정예8→4·보스10→4로 준비된 보드에서 대응 가능할 때만 예고된다. 관찰한 첫 보드에서 불가능한 고위험 예고는 없었다.

다만 경로 전체의 위험이 종료 HP에 단조롭게 나타나지는 않는다. 위험 경로에는 추가 전투가 있지만 이벤트 유물·추가 골드·상점 회복도 있다. 따라서 위험 경로 종료 HP가 더 높다는 사실만으로 버그나 보상 과잉이라고 판단하지 않았다. 이번 표본에서 자동 정책은 모두 완주했지만 인간에게 쉽다는 결론도 내리지 않는다. 밸런스 수치를 바꿀 재현 결함은 발견하지 못했다.

## 범위와 재현

미검증: 인간 플레이/재미, 실제 장치 소리·터치, Windows 실행, 모든 시드와 모든 경로 조합, 모든 스킬/유물 선택 정책, 오랜 반복 플레이의 통계. 정책은 매번 첫 유물 후보를 선택하므로 유물 선택의 모든 순열을 검증하지 않는다. 소거 비교는 commit 시 정산이며 후속 적 반격을 같은 피해로 혼동하지 않는다.

`python tests/run_seed_audit.py`, `python tests/run_seed_audit.py --shop-controls`, `python tests/report_seed_audit.py`로 재현한다. 실제 커맨드·시드·저장 격리 경로는 summary.json에 있다. 초기화는 매번 새 프로세스/새 저장 폴더이다. `analysis.json`, 각 로그와 compact trace.json이 근거다.

기존 전체 게임 회귀는 runtime 무변경이라 반복하지 않았다. 이번28회 실행이 감사 harness 검증이며 GitHub 하네스 CI는 Godot 실행과 별개다. 오디오 경고가 관찰된 경우 analysis.json의 warnings에 남긴다. 기존 즉시 종료 엔진 경고의 해결을 주장하지 않는다.
