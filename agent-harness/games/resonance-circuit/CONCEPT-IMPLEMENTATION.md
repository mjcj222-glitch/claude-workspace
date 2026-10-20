# 승인 시안 실제 UI 적용

## 에셋과 범위

승인된 그림을 실제로 열어 확인한 뒤 구현했다. 원본은 `assets/approved-concept.png`에 보존했다. 940×1672 PNG, 2,387,691바이트이며 Git blob은 `733bb5464df6488a6fcafeb9d9424e3fa7c2e692`다.

Library 읽기/물질화 준비는 성공했으나 전송 도우미는 download failed(exit 1)였다. 이후 부모가 승인하여 생성한 GitHub blob을 기존 tree 기반 새 에셋 커밋으로 연결하고, expected_sha를 지정한 비강제 ref 갱신 후 가져왔다. 첫 fetch 뒤 origin/feat/resonance-circuit 원격 추적 ref가 없어 merge가 exit 1이었고, 실제 fetch 결과인 FETCH_HEAD를 확인하여 fast-forward로 적용했다. 기존 파일은 손상하지 않았다.

캐릭터 재디자인은 하지 않았다. `assets/characters.css`의 네 표시 슬롯과 `assets/manifest.json`으로 교체 경로를 분리했다. 보스는 원본 y=76부터 400px 높이 영역을 사용하고, 세 초상은 하단 캐릭터 얼굴 영역만 CSS background-position으로 표시한다. 원본의 HUD, 보드, 텍스트를 전체 화면에 붙이거나 그 위에 입력을 얹지 않는다. 향후 각 슬롯의 background-image/size/position만 개별 캐릭터 파일로 교체할 수 있다.

## 시안과 실제 화면 비교

- 승인 시안의 밝고 차분한 청록색, 만화풍 임시 캐릭터, 어두운 트레이, 빨강/파랑/노랑/초록 보석, 하단 초상과 과충전 버튼을 적용했다.
- 기존 좌우 카드 배치를 없애고 데스크톱도 최대420px 중앙 세로 화면으로 구성했다.
- 실제 게임은 6×7 홀수 열 hex 보드다. 그림의 행 배치와 다르며 실제 HP·3탭·다음 공격·스킬 쿨다운·과충전 게이지를 별도로 렌더링한다.
- 360px/390px 캡처에서 보스 영역과 초상에 원본 HUD·보석이 섞이지 않는 것을 시각 검수했다. 큰 보스 전신 대신 상체를 잘라 게임 정보 공간을 확보했다. 시안의 원형 보석은 작동하는 hex 버튼으로 표현하고 기존 색 외 형태 구분을 유지했다.
- 360×800 첫 검사에서는 과충전 버튼이 821px까지 내려가 실패했다. 타일을 더 줄이지 않고 보스 창을 줄였다. 최종 하단 위치: 360×800에서 796px, 390×844에서 827px, 1280×900에서 847px. 재시작/규칙 보조 버튼은 모바일에서 약간 스크롤할 수 있다.
- 타일 실제 크기: 360px 약51.7×38px, 390px 약56.7×40px. 글자와 터치 크기의 실제 사용성은 사람 검수가 필요하다. 일부 보조 라벨은 9–10px로 작아 시안보다 정보 밀도가 높다.

## 검증과 파일

- `concept-unit.log`: 기존 규칙·키보드 테스트 25개.
- `concept-harness.log`, `concept-python.log`: harness check, Python 5개 테스트.
- `concept-layout.log`: 360×800/390×844/1280×900, 42타일·가로 넘침 없음·과충전 버튼 화면 내 배치.
- `concept-browser.log`, `concept-standalone.log`: 모듈판/독립판 전투, 키보드, 터치, 승패, 재시작 및 잔류 효과 검사.
- `concept-mobile.log`: 390×844 기본 모션에서 터치 포인터로 전체 승패 흐름 추가 검사.
- `concept-art.log`: 실제 연쇄/잔향/폭탄, 입자 상한, 효과 정리 검사.
- `concept-ui-360.png`, `concept-ui-390.png`, `concept-ui-1280.png`: 실제 화면 캡처.
- ZIP은 원본 PNG·manifest·캐릭터 CSS·모듈 원본·독립 HTML을 포함한다. standalone HTML 안에는 PNG 데이터와 CSS/JS를 직접 넣어 네트워크 리소스 의존성을 제거했다. ZIP 11개 항목의 CRC와 현재 원본 바이트 일치를 검사했다.

## 한계

file:// 직접 열기는 이전 환경 관리 정책 차단 때문에 재시도하지 않았다. 네트워크 요청 없이 독립 HTML을 제공하는 브라우저 검증과 직접 파일 실행은 구분한다. Safari/Firefox, 실물 기기·스크린리더, 실제 터치 스크롤/pointercancel, 재미·난이도는 미검수다. 캐릭터는 승인 시안의 임시 표시이며 최종 캐릭터 에셋이 아니다.

게임 규칙 엔진·효과 코드·입력 로직은 변경하지 않았다. 수동 배포·main 병합·Vercel 설정 변경·유료 서비스·API 키·패키지 설치는 하지 않았다. Draft PR #2에서 검토한다.

최종 결과: 위 모든 검사 종료 코드 0. 로직 25/25 및 Python 5/5 통과. ZIP SHA256: 8ed133cf14e9b109f52bb964a1d7dd58e721947587f66d31d21760268344ffbe.
