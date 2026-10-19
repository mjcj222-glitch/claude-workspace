# 잔향 회로 · 세 정원 탐험

승인된 만화풍 온실 시안으로 구현한 오프라인 퍼즐 전투입니다. 시작 → 실제 보드 잔향 안내 → 3전투 → 전투 사이 2택1 성장 → 최종 결과 → 새 탐험/전투 재도전으로 이어집니다. 로그인·서버·광고·과금·추적·외부 네트워크 요청은 없습니다.

## 실행

`resonance-circuit.zip`을 풀고 `standalone.html`을 브라우저로 엽니다. 이미지·CSS·JS가 모두 내장되어 있습니다. 이 클라우드 환경의 관리 정책은 file://를 차단하므로 직접 파일 실행 성공은 미검증입니다. 모듈판을 사용자가 로컬에서 실행할 경우:

```sh
cd agent-harness/games/resonance-circuit
python -m http.server 8000 --bind 127.0.0.1
# http://127.0.0.1:8000
```

개발 중 호스팅·배포를 시작하지 않았습니다.

## 플레이

같은 색·모양을 누르면 미리보기, 같은 위치에서 떼면 확정합니다. 방향키 이동, Enter/Space 확정, Tab으로 다른 버튼 이동. 드래그·pointercancel은 취소합니다. 3탭 뒤 회복 → 보스 피해 → 생존 보스의 예고 공격을 정산합니다.

공격색 5개 이상은 차지와 이웃 잔향, 10개 이상은 폭탄을 만듭니다. 다음 최초 연결이 잔향에 닿으면 이전 표식 전체가 발동합니다. 스킬은 탭 없이 사용하며 3턴 뒤 준비됩니다. 과충전은 게이지55를 채운 뒤 턴 첫 탭 전에 사용합니다.

전투 승리 후 성장 하나를 선택합니다. 체력45 회복·게이지 유지, 새 보드·준비된 스킬로 다음 전투를 시작합니다. 패배하면 해당 전투의 진입 체력·게이지·성장·시드에서 정확히 재도전합니다. 새 탐험은 진행 덮어쓰기를 확인합니다.

## 고유 스킬과 정원 방어

기존 색 전환·폭탄 생성·회복 생성에 각각 프리즘 추가 피해(+12, 잔향 적중 +24), 실제 폭탄 해소 보너스(폭탄당 +10, 최대 +30), 다음 적 반격 보호막18을 더했습니다. 상단 `스킬 설명`에서 사용 전 효과·현재 대상 수·쿨다운을 확인합니다. 준비 효과는 저장되며 재사용 시 중첩 없이 갱신됩니다.

두 번째 정원은 피해를20% 줄이는 장막을 사용합니다. 잔향 적중으로 현재 턴 장막을 해제하며 다음 턴 복구됩니다. 잔향 없이도 피해를 줄 수 있습니다. 세 번째 정원의 기존 18→26→40 예고 공격은 그대로이며 보호막을 맞춰 쓸 수 있습니다. 정확한 계산·이전 저장 호환·검증 결과는 [SKILLS-REPORT.md](SKILLS-REPORT.md)에 있습니다.

## 단계별 새 패널

1전투는 기존 기본 보드, 2전투에는 덩굴, 3전투에는 덩굴과 무지개가 등장합니다. 덩굴은 직접 지울 수 없고 옆 타일 소거나 폭탄으로 껍질만 벗깁니다. 무지개는 한 색 연결을 이어 주며 직접 누르면 가장 큰 연결색을 고릅니다. 확정색은 미리보기에 표시합니다. 실제 보드의 첫 안내는 건너뛸 수 있고 규칙 보기에서 다시 읽을 수 있습니다.

이전 저장은 현재 전투와 재도전 배치를 보존하고 다음 전투부터 새 패널을 도입합니다. 새 규칙·생성 확률·검증 결과는 [PANELS-REPORT.md](PANELS-REPORT.md)를 참고하세요.

## 저장·음향

보드/RNG/성장/튜토리얼 완료/음향 설정을 버전1 localStorage에 자동 저장합니다. 같은 브라우저·주소에서 이어하기를 선택하세요. 손상되거나 버전이 맞지 않는 저장은 사용하지 않습니다. 저장이 막히면 현재 플레이는 가능하지만 창을 닫은 뒤 복구되지 않습니다. 기기/주소 간 동기화는 없습니다.

음향은 기본 꺼짐입니다. 사용자 토글 후 Web Audio로 짧은 부드러운 합성음을 생성하며 음량을 조절할 수 있습니다. 탭이 숨겨지면 정지하고 다음 사용자 조작 때 재개합니다. 오디오가 없어도 플레이할 수 있습니다. 실제 청취 품질은 미검증입니다.

## 검증

```sh
node --test agent-harness/games/resonance-circuit/*.test.mjs
node agent-harness/games/resonance-circuit/balance.mjs
# 기존 설치된 Playwright 및 /usr/bin/chromium이 있는 환경:
python agent-harness/games/resonance-circuit/campaign_browser.py
python agent-harness/games/resonance-circuit/resilience_browser.py
python agent-harness/games/resonance-circuit/layout_check.py
python agent-harness/games/resonance-circuit/art_check.py
python agent-harness/games/resonance-circuit/skills_browser.py
python agent-harness/games/resonance-circuit/panels_browser.py
python agent-harness/games/resonance-circuit/panels_terminal_browser.py
```

서버를 열지 않고 브라우저 내부 route로 검증합니다. 전체 결과/시드 실험/미검증 사항은 [CAMPAIGN-REPORT.md](CAMPAIGN-REPORT.md)에 있습니다. 자동 검사를 재미나 상용 품질의 증명으로 보지 않습니다.

## 구조·에셋

`engine.mjs`: 기존 hex/연쇄 규칙, `campaign.mjs`: 전투·성장·재도전, `storage.mjs`: 저장 검증, `audio.mjs`: 제스처 기반 음향, `effects.mjs`: 시각 효과, `app.mjs`: 입력·화면 연결. `config.mjs`/`campaign.mjs`에 밸런스 수치가 있습니다.

승인 원본은 `assets/approved-concept.png`로 보존했습니다. 임시 캐릭터와 개별 보석은 CSS sprite이며, 교체 슬롯은 `assets/characters.css`와 `assets/manifest.json`에 있습니다. 캐릭터 재디자인은 하지 않았습니다. `package_game.py`는 원본에서 이미지 내장 HTML/ZIP을 생성합니다.

## 전투 그림 표시

적의 꽃왕관·얼굴·몸통·발끝을 함께 보여 주도록 전투 일러스트를 원본 비율로 표시합니다. 안내 중에도 그림 높이는 유지합니다. 보드/스킬 크기를 줄이지 않아 하단에는 세로 스크롤이 필요합니다. 캡처와 검증은 [BACKGROUND-REPORT.md](BACKGROUND-REPORT.md)를 참고하세요.

## 연출과 소리 확인

메인 화면의 `연출·소리`에서 효과 줄이기(이번 실행만)와17개 미리듣기를 제공합니다. 소리는 기본 꺼짐이며 먼저 켜야 합니다. ZIP의 `sound-check.html`은 별도 설치 없이 같은 합성음을 재생하고, `samples/`에는 실제 OfflineAudioContext로 렌더링한 WAV가 있습니다. `feedback-play.mp4`는 실제 브라우저 조작 녹화이며 무음입니다. 실제 차이·수치·검증 한계는 [FEEDBACK-REPORT.md](FEEDBACK-REPORT.md)를 참고하세요.

## 순차 소거

타일이 탭 지점의 hex 연결 순서를 따라 차르르 사라진 뒤 빈자리와 낙하가 이어집니다. 기본 모션에서6칸 약458ms,10칸570ms,42칸738ms의 해소·낙하 후보 타임라인입니다. reduced-motion은 순차 이동 없이 즉시 정산합니다. 실제 프레임·취소 규칙·검증은 [CASCADE-REPORT.md](CASCADE-REPORT.md), 새 영상은 `cascade-play.mp4`, 소리 샘플은 `samples/cascade-{6,10,42}.wav`입니다.

최신 소거 설정 회귀 수정/부드러운 팝·200ms 낙하: [SOFT-CASCADE-REPORT.md](SOFT-CASCADE-REPORT.md). 새 실제 영상: `soft-cascade-play.mp4`.

탐험 v1: 시작에서 연습/탐험 선택. 6개 방 분기·유물8종·HP유지·별도 저장, 패배 후 전투 재도전 없음. [설계](EXPEDITION-DESIGN.md) / [검증 보고](EXPEDITION-REPORT.md). 기존 연습 저장은 유지됩니다.

최신 화면은 아이보리·차콜 UI입니다. [시각 설계/검수](NEUTRAL-UI-REPORT.md), `neutral-after-*.png` 참고. 포함된 기존 영상은 이전 디자인 기록입니다.

최신 모바일 프레임: 스크롤 없는 전투와 메뉴 오버레이, 노드→상세→진입 지도. [보고서](MOBILE-FRAME-REPORT.md), `mobile-combat-*.png`, `mobile-play.mp4` 참고.
