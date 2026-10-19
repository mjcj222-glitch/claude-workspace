# 아이보리·차콜 UI 개선

2026-10-19. 기준 head69c6a236. 변경은 게임 폴더의 시각 표현과 패키징/검수 산출물이다.

## 디자인

청록 화면/겹친 외곽선/금색 과충전 버튼을 아이보리 배경·밝은 카드·차콜 본문으로 교체했다. 주요 행동/선택/키보드 포커스만 라벤더로 강조한다. 배경 장식선과 초록 글로우를 정리하고 카드 그림자와 경계를 약하게 했다. 전투 HUD, 스킬, 설정, 시작/도움말/결과 모달, 지도/유물보상/선택이벤트, 독립 사운드 체크 페이지에 동일한 팔레트를 적용했다.

보석의 색/모양, 회복·위험·스킬 의미색은 유지한다. 퍼즐판은 짙은 차콜로 두어 보석과 옅은 입자/광륜 대비를 확보한다. 캐릭터 원본은 수정하지 않았고 기존 일러스트 마스크 밑의 작은 영역만 그림에 맞춰 배경색을 조정했다. 초록은 원본 일러스트와 회복/덩굴 등 의미 요소에만 남는다.

글씨를 주요 보조문장11–12px, 모달 본문12–13px, 제목22px로 정리했다. 일반 보조 버튼36px, 주요 버튼42px 높이, 지도/보상 카드는 내용에 맞게 더 크다. 모바일에서는 세로 스크롤을 허용해 글씨와 캐릭터/보석을 축소하지 않았다. 긴 지도/보상 모달은 내부 스크롤을 사용한다. 경로는 체크/대시/선택선과 색을 함께 사용한다.

## 변경 파일

- `neutral.css`: 중립색 디자인 토큰과 전체 화면 스타일. 기존 모션/스프라이트 CSS에 마지막으로 적용한다.
- `index.html`: 새 스타일 링크.
- `package_game.py`: standalone에 스타일 내장, ZIP에 포함, 독립 사운드 체크 팔레트 변경.
- `standalone.html`, `sound-check.html`, `resonance-circuit.zip`: 재생성.
- `neutral_ui_browser.py`, `neutral_effects_browser.py`: 실제 화면/대비/포커스/넘침/효과 검수.
- 설계/보고, 이전·이후 화면과 실행 로그.

게임 규칙, app/engine/campaign/expedition 모듈, 저장 스키마/슬롯, 원본 PNG, 음향/모션 타이밍은 변경하지 않았다.

## 실제 확인

- `node --test`:108/108 통과 (`neutral-unit.log`).
- harness check 및 Python unittest5/5 통과 (`neutral-harness.log`, `neutral-python.log`).
- 360×800 /390×844 /1280×900 × 일반/축소: 시작·전투·설정·스킬설명·지도·보상·이벤트·결과8화면, 총48개 실제 스크린샷. 가로 넘침/JS 오류 없음 (`neutral-visual-verified.log`). 보상/결과 화면은 명시적 결정론 fixture, 아래 완주는 실제 UI 플레이로 구분했다.
- 대표 텍스트 대비: 본문12.69:1, 결과모달14.10:1, 주요 라벤더버튼6.64:1, 차콜버튼11.20:1, 보조버튼8.67:1. 이는 해당 색쌍 검사이며 전체 접근성 인증은 아니다.
- 실제 키보드 Tab→포커스에서 가시적 outline 확인. 첫 검사에서는 마우스 뒤 programmatic focus에 focus-visible을 기대해 실패했고, 실제 키보드 입력 조건으로 수정했다(`neutral-visual-initial.log`). 제품 포커스 구현 오류는 아니었다.
- 탐험 전체 시작→지도→일반전→보상→휴식→정예→이벤트→보스→결과, 이어서 패배/리로드와 연습 슬롯 보존: 3해상도×2모션6/6 통과 (`neutral-expedition-{0..5}.log`).
- 기존 연습 일반 ES modules / 축소 standalone 전체3전투 각1회 통과 (`neutral-practice-{normal,reduced}.log`).
- 실제6/42칸 소거를3해상도에서 캡처해 보석 원색·광륜·부분소거를 확인, 소거 후 타일/ID 정리 통과 (`neutral-effects.log`, `neutral-effects-*.png`).
- 이전/이후 전투·지도·시작·설정·보상·데스크톱 화면을 직접 비교했다. 밝은 모달에서 장문을 읽기 쉬워졌으며, 차콜 보드에서 소거 효과가 묻히지 않았다. 이미지 마스크의 밝은 사각 끝이 도드라지는 점을 발견해 이미지 영역 배경만 조정했고 최종48화면을 다시 검수했다.

## 대표 비교 파일

- `neutral-before-battle-390-no-preference.png` → `neutral-after-battle-390-no-preference.png`
- `neutral-before-map-390-no-preference.png` → `neutral-after-map-390-no-preference.png`
- `neutral-before-start-390-no-preference.png` → `neutral-after-start-390-no-preference.png`
- `neutral-after-reward-390-no-preference.png`, `neutral-after-settings-390-no-preference.png`
- `neutral-after-battle-1280-no-preference.png`, `neutral-effects-42-390-1.png`

## 실행과 한계

ZIP을 풀고 standalone.html을 연다. 기존 연습/탐험 저장키는 그대로이며 같은 브라우저/주소를 사용할 때 이어진다. 관리형 Chromium은 file URL 직접 열기를 제한하므로 검수는 로컬 바이트 Playwright route로 진행했다. 기존 영상들은 이전 디자인의 기록이며 최신 화면은 위 스크린샷을 기준으로 한다.

실물 터치 기기/Safari/Firefox/스크린리더·사람 사용성 평가는 미검증이다. 모바일의 하단 스킬/설정과 긴 지도는 스크롤이 필요하다. 별도 이미지 생성/외부 에셋·패키지 다운로드/추가 결제/API/배포/보안 설정 변경/main 병합 없음.
