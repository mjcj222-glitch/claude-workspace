# 수채화 온실 아트·고전 판타지 HUD 통합

2026-10-20 · 기준 UI head1c5e273 · 자산 커밋fa7cd83 · 동일 feat/resonance-circuit / Draft PR #2.

## 결과와 자산

원본 전투 장면1774×887(2:1)과 초상 시트2172×724(3:1)를 실제 소비 환경에 가져와 픽셀을 확인했다. 나무가면 여우 수호자와 고대 온실을 자르지 않고 전신/원본 비율로 표시한다. 좌/중/우724×724 초상은 프리즘 학자·불꽃 장인·약초사에 각각 연결했다. CSS background-size300%100%, x0/50/100%, y0px의 정확한3분할이며 이미지 자체는 수정하지 않았다.

사용자가 승인한 새 오리지널 이미지이며 Octopath 참고 이미지를 게임에 복제하지 않았다. 배경 blob31fd1ef48a32c1ff495a723a7cc946e3ff1887dc, 초상 blob06d2083714876bd8f4119c8a488f4bf78519a2c8. 부모가 미리 올린 blob을 기존 base tree94a380d86b8b80c47ed624fa56282766c158f0aa에 추가하고 expected head1c5e273을 검사한 non-force ref 갱신 후 로컬 fast-forward했다. 기존 미커밋 UI 변경은 보존했다. `assets/manifest.json`에 크기·크롭·SHA256·출처를 기록했다.

먹색 보드, 양피지 패널, 절제된 황동선/버튼, 작은 모서리로 전투·지도·보상·메뉴를 통일했다. 기존 플라스틱 보석 대신 코드로 직접 그린64×64 SVG 룬4개를 사용한다. 주홍 불꽃/청회 물방울/황토 별/회녹 잎의 색·모양 이중 구분, 기존 잔향/폭탄/차지/덩굴/무지개 표식과 타격·소거 타이밍을 유지했다. 새 PNG2개와 SVG4개 모두 독립HTML에 내장한다. 기존SD자산과 과거 영상은 기록으로 보존하며 현재 아트로 소개하지 않는다.

## 검수

검수 로그는 `storybook-*.log`에 기록한다. 관리형 Chromium은 내부 응답 방식으로 로컬 파일을 실행하며 새 서버/배포를 시작하지 않았다. 모듈판 검수 서버의 SVG MIME 누락으로 첫 화면에서 룬이 보이지 않는 문제가 발생해 image/svg+xml 응답을 추가했다. 이후 이미지 decode 검사를 추가하여 실제 자산 로딩을 검증했다. 초상CSS의 y0이 브라우저에서0px로 정규화되는 것을 테스트가0%로 오해한 실패는 기대값을 실제단위로 수정했다(`storybook-assets-initial.log`). 이미지/제품 코드를 바꿔 테스트에 맞추지 않았다. 독립HTML에서 대형PNG data URL을 CSS사용자변수에 넣었을 때 계산된 배경이none이 되는 문제도 실제decode검사로 발견했다. PNG배경은직접URL선언으로 내장하여수정했고, 모듈/독립HTML의8개활성이미지decode와정확한크롭이 모두통과했다. 실패로그는 storybook-assets-packaging-failure.log, 실패상태의초기영상은 storybook-initial-play.mp4로보존하며 최종영상과구분한다. 수정후독립HTML3조합씩전체플레이와영상을재검수했다.

## 변경 범위와 한계

게임 폴더만 수정했다. 주요 변경은 `fantasy.css`, `assets/art-slots.css`, `assets/storybook-*.png`, `assets/rune-*.svg`, `assets/manifest.json`, `index.html`, `presentation.mjs`의 준비 강조 색, `package_game.py`, 브라우저검수/촬영/문서/산출물이다. engine/campaign/expedition/storage/skills/panels/timeline/audio 규칙·저장·오디오·소거 로직은 변경하지 않았다. 추가 결제·설치·main 병합·수동 배포 없음.

이전 참고 이미지4장은 Library 지원 절차의 다운로드 실패 후 기본소비경로1회재시도도 실제파일부재로 실패했다. 그 참고픽셀은 이 환경에서 확인하지 못했으며 이번새오리지널2장의픽셀확인과 구분한다. 원작 공식이미지는 저장소/ZIP에 포함하지 않았다.

실물 모바일/Safari/Firefox/스크린리더/실제청취와 사람이느끼는재미는 미검증이다. 자동완주는 회귀검수이며 재미증명이 아니다. file:// 직접열기는 이전 관리정책 차단으로 미검증; 독립HTML의 내부응답방식 전체흐름만 확인한다.

실행: ZIP을 풀고 standalone.html을 브라우저에서 열거나 사용자의 로컬게임폴더에서 `python -m http.server 8000 --bind 127.0.0.1` 실행 후 localhost:8000 접속. 새로그/영상과 과거자료를 구분한다. 검토후되돌리려면 UI통합커밋을revert; 아트원본을되돌리려면 별도자산커밋fa7cd83도revert한다.

## 확인한 결과

- harness check 종료0, Python unittest5/5 종료0 (`storybook-harness.log`, `storybook-python.log`).
- Node test108/108 종료0 (`storybook-unit.log`).
- 360×640/800·390×844·1280×900 × 일반/축소8조합 무스크롤,42타일/도크범위,적예고,키보드/메뉴/중복입력/노드선택 통과 (`storybook-layout.log`). 무대 실제치수248×124 /344×172 /374×187 /414×207:모두정확한2:1. 룬타일 최소높이40/48/56/56px 유지.
- 모듈/독립HTML의 무대1·초상3·패널4 실제decode8개씩,원본크기,정확한초상분할,독립HTML dataURL내장 통과 (`storybook-assets.log`).
- HP정산/준비/재시작/숨김 및 감소·회복·0·최대·동작감소전환 각각일반/축소 통과 (`storybook-feedback.log`, `storybook-boundaries.log`).
- 새자산최종영상 `storybook-play.mp4`:390×844,무음,22.750초,1,635,719바이트. 실제CDP580프레임,반복전투중간탭만컷편집,원속도/합성없음. `storybook-video-contact.png`와 `storybook-video-result.png`의실제영상프레임을검수했다. 실패상태의초기영상과과거영상은최종결과가아니다.
- 연습3전투 전체6조합 통과(`storybook-campaign.log`), 탐험6층전체6조합 통과(`storybook-expedition.log`). 탐험은보상·휴식·이벤트·정예·보스·패배리로드·슬롯격리까지검사했다.
- 패키징수정후독립HTML 재검수는 `storybook-standalone-recheck.log`(연습), `storybook-expedition-recheck.log`(탐험)에별도기록했다. 추가360×640 일반독립HTML완주/패배복구는 `storybook-short-recheck.log`.
- 실행환경:Linux6.18.55/Python3.12.14/Node24.19.0/Chromium154.0.8037.57. `storybook-environment.log`.
