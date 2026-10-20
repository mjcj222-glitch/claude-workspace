# 잔향 회로

귀여운 펜선·수채화 동료와 빛 회로 보드를 사용하는 독자적인 퍼즐 전투입니다. 새 게임에서는 42개 기물이 아래로 떨어지고 서로 밀리며 빈 공간을 채웁니다. 맞닿은 같은 색 연쇄·잔향·3개 스킬·과충전으로 온실의 적을 상대합니다. 기본 무음이며 로그인·광고·과금·추적·외부 에셋 요청이 없습니다.

현재판은 6개 방 탐험과 3전투 연습을 제공합니다. 탐험에는 잡몹·정예·상인·휴식·필수 중간보스·최종보스가 각각 다른 그림으로 등장합니다. 전투 무대에는 독자적인 전신 캐릭터, 그 아래에는 큰 얼굴 파티 도크와 시안 체력바를 배치했습니다. 최신 결과는 [EVOLUTION-REPORT.md](EVOLUTION-REPORT.md)와 실제 플레이 녹화 `evolution-play.mp4`입니다.

## 실행

`resonance-circuit.zip`을 풀고 `standalone.html`을 브라우저로 여세요. 이미지·CSS·JS가 모두 들어 있습니다. 개발 환경에서는 관리 정책이 file:// 직접 열기를 차단하여, 브라우저 내부 응답 방식으로 이 파일을 검증했습니다. 사용자의 로컬에서 모듈판을 실행하려면 다음 명령을 사용할 수 있습니다.

```sh
cd agent-harness/games/resonance-circuit
python -m http.server 8000 --bind 127.0.0.1
# http://127.0.0.1:8000
```

이번 작업에서 서버 호스팅·수동 배포·main 병합을 하지 않았습니다. [Draft PR #2](https://github.com/mjcj222-glitch/claude-workspace/pull/2)에서 검토할 수 있습니다.

## 조작과 규칙

같은 색·문양을 누르면 미리보기, 같은 위치에서 떼면 확정합니다. 드래그·pointercancel은 취소합니다. 방향키로 타일을 이동하고 Enter/Space로 확정하며 Tab으로 다른 버튼에 접근합니다. 3탭 뒤 회복 → 적 피해 → 살아남은 적의 예고 반격을 정산합니다.

새 보드는 정착한 실제 좌표로 연결과 터치를 판정합니다. 낙하 중에는 입력을 잠그며, 새로 맞닿은 기물은 다음 탭에서 선택할 수 있습니다. 접촉만으로 자동 소거하지 않습니다. 화면 크기나 효과 설정을 바꾸어도 같은 시드·입력의 정산과 최종 위치는 같습니다.

새 게임에서는 공격색 5~7개 직접 연결로 차지와 잔향, 8개 이상으로 같은 속성 대형 폭탄 1개와 잔향을 만듭니다. 불꽃은 주변 두 겹, 별빛은 가로 띠, 물방울은 세로 띠를 폭발시킵니다. 무지개는 직접 연결 수에 포함하고, 폭발·잔향으로 추가 제거한 수는 포함하지 않습니다. 새 대형 폭탄은 다음 탭부터 사용할 수 있으며 회복색은 특수를 만들지 않습니다. 연쇄 점화 스킬의 소형 폭탄은 기존 한 겹 범위입니다. 이전 저장은 기존 5개 차지·10개 소형 폭탄 규칙을 유지합니다. 다음 최초 연결이 기존 잔향에 닿으면 이전 표식 전체가 발동합니다. 폭발만 표식에 닿는 경우에는 다른 표식을 연쇄 발동하지 않습니다. 새 잔향은 만든 탭에서 발동하지 않습니다. 과충전은 게이지 55를 채운 뒤 턴 첫 탭 전에 사용합니다.

스킬은 탭을 쓰지 않으며 3턴 뒤 다시 준비됩니다. 프리즘 링크는 색 전환과 다음 공격색 탭 추가 피해, 연쇄 점화는 폭탄 전환과 실제 폭탄 해소 보너스, 생명의 온실은 회복 타일 전환과 다음 반격 보호막 18을 제공합니다. 메뉴의 스킬 설명에서 대상 수와 쿨다운을 확인하세요. 덩굴은 이웃 소거·폭탄으로 껍질을 벗기고, 무지개는 한 색의 연결을 이어 줍니다. 첫 등장 시 실제 보드 안내를 제공합니다.

## 두 가지 진행

탐험은 6개 방을 지나며 체력과 유물을 유지합니다. 새 탐험의 4층은 필수 중간보스, 6층은 최종보스입니다. 1층 대형 폭탄 → 2층 덩굴 → 3층 빌드 선택 → 4층 무지개와 중간보스 → 5층 최종 준비 → 6층 종합 전투로 이어집니다. 첫 보드에는 실제 접촉 그래프로 검증한 연결 기회가 있고 이후에는 난수 리필을 사용합니다. 전투 승리 시 유물을 한 번 선택하고 휴식·이벤트에서 회복 또는 보상을 고릅니다. 새 규칙의 일반전은 유물 2개, 정예·중간보스는 3개 중 하나를 고릅니다. 탐험 패배 후에는 새 탐험을 시작합니다.

연습은 3전투와 두 번의 성장 선택으로 이어집니다. 패배하면 해당 전투의 진입 체력·게이지·성장·시드에서 재도전할 수 있습니다. 탐험과 연습 저장은 서로 분리됩니다. 새 게임은 기존 진행을 덮어쓰기 전에 확인합니다.

## 저장·소리·화면

같은 브라우저·주소의 localStorage로 이어합니다. 이전 연습 v1과 탐험 v1/v2 저장의 지도·수치·RNG·보상은 그대로 복구합니다. 이전 hex 저장은 42칸 hex를, 이전 좌표 저장은 좌표 보드를 유지합니다. 새 게임은 좌표 보드를 사용합니다. 보드 버전·탐험 지도 버전·기믹 rulesVersion은 별개입니다. 기존 진행에 새 기믹이나 새 적 수치를 강제로 적용하지 않습니다. 손상된 저장은 사용하지 않습니다. 저장이 막혀도 현재 플레이는 가능하지만 창을 닫은 뒤 복구되지 않습니다. 기기·주소 간 동기화는 없습니다.

음향은 기본 꺼짐이며 직접 켜고 음량을 조절합니다. Web Audio 합성음만 사용하고 탭이 숨겨지면 정지합니다. `sound-check.html`과 `samples/`의 WAV도 포함합니다. 시스템 reduced-motion과 실행 중 효과 줄이기를 지원합니다. 낙하는 최종 논리 좌표를 바꾸지 않는 보간 재생이며 선택 장면은 기존 원화 위의 빛·작은 입자만 움직입니다. 움직임을 줄이면 정적 장면에서 즉시 선택할 수 있습니다. 색 이외 문양·정적 수치로 상태를 전달합니다.

검수한 360×640 이상 화면에서 전투는 스크롤 없이 들어가며 메뉴는 오버레이로 엽니다. 가장 짧은 화면의 기물 버튼 지름은 최소 40.3px이므로 모든 조작 영역이 44px인 것은 아닙니다. 실제 모바일 기기·Safari/Firefox·스크린리더·OS 큰 글자·청취·재미 평가는 남아 있습니다.

## 개발 검증과 구성

```sh
python agent-harness/harness.py check
python -m unittest discover -s agent-harness/tests -v
node --test agent-harness/games/resonance-circuit/*.test.mjs
# 이미 설치된 Playwright 및 /usr/bin/chromium이 있는 개발 환경:
python agent-harness/games/resonance-circuit/evolution_browser.py
python agent-harness/games/resonance-circuit/flow_boundaries_browser.py
python agent-harness/games/resonance-circuit/flow_legacy_browser.py
python agent-harness/games/resonance-circuit/evolution_choices_browser.py
python agent-harness/games/resonance-circuit/evolution_expedition_browser.py
python agent-harness/games/resonance-circuit/evolution_campaign_browser.py
```

`mechanics.mjs`는 새 속성 폭탄과 초기 학습 보드, `flow-motion.mjs`는 렌더 보간, `choice-motion.mjs`는 선택 장면 장식, `flow.mjs`는 고정 간격 물리 계산, `flow-ui.mjs`는 좌표 표시·낙하 재생, `engine.mjs`는 연쇄 규칙과 이전 hex 호환을 담당합니다. `campaign.mjs`는 연습, `expedition.mjs`는 탐험, `encounters.mjs`와 `encounter-ui.mjs`는 장면 분류·표시를 담당합니다. `package_game.py`는 독립 HTML/ZIP을 만듭니다. ZIP에는 현재 실행 구성·표시용 자산·최신 보고서·최신 영상만 담습니다. 원본 PNG와 이전 보고서·영상·로그는 Git 저장소에 보존합니다. 자동 완주를 재미나 상용 품질의 증명으로 보지 않습니다.
