# 모바일 전환·전투 피드백 마무리

2026-10-19 · 기준 head 308aaac · 기존 Draft PR #2의 게임 폴더 한정 변경.

## 결과

적 무대의 중앙 배치/최대높이 제한을 없애 상단 진행과 적 HP 사이 공간을 줄였다. 적 HP·공격 예고와 플레이어 HP·보드를 가까이 묶었다. 360×640은40px,360×800은48px,390×844와1280×900은56px 타일을 사용한다. 100dvh와 safe-area, 모든42칸·스킬3개·과충전의 화면 내 배치를 유지한다.

HP의 접근성 progress/수치는 즉시 실제값으로 갱신된다. 별도 aria-hidden 시각 바는 본체160ms, 잔상110ms 대기 뒤320ms로 피해를 따라간다. 회복은 두 바가 함께160ms 추종한다. 새 전투는 잔상을 초기화한다. 피해/회복 숫자와 체력 변화, 준비 배지, 남은탭 점, 과충전 준비/발동 문구를 강화했다. 번쩍이는 광원 효과를 추가하지 않았다.

지도·전투·보상/결과 진입은150ms 투명도 전환이다. 선택은 즉시 한 번 처리·저장하고 확인 배지를 잠깐 표시한다. 전환은 게임 상태 변경을 지연시키지 않는다. reduced-motion은 전환 움직임/대기 없이 최종 표시하며, 숨김·재시작·모드 변경·설정 변경은 진행 중 표시를 취소하고 실제값으로 맞춘다. 늦게 끝나는 표시 타이머가 새 선택/체력 알림을 지우지 않도록 분리했다.

## 실제 검증과 발견

- `python agent-harness/harness.py check`: 정상, 종료0. `presentation-harness.log`.
- `python -m unittest discover -s agent-harness/tests -v`:5/5 통과, 종료0. `presentation-unittest.log`.
- `node --test`:108/108 통과, 종료0. `presentation-unit.log`. 기존 규칙/저장/결정론 테스트 유지.
- `presentation_browser.py`:일반/축소모션에서 실제 저장 fixture의 턴 정산·준비상태·재시작·숨김·무스크롤 통과. `presentation-final.log`.
- `presentation_boundaries.py`:브라우저 안의 표시 컨트롤러에서 피해·회복·0·최대·준비·과충전·hidden·새 상태·동작 감소 변경 검증. 일반/축소2조합. 게임 규칙의 별도 증명으로 해석하지 않는다.
- `mobile_frame_browser.py`:360×640/800,390×844,1280×900 × 일반/축소8조합. 무스크롤/터치영역/그림비율/메뉴 중 배경입력 차단/키보드 포커스/중복탭1회/지도 상세 취소·진입 통과. 스크린샷은150ms 전환이 끝난 뒤 촬영.

초기 HP바 부재를 검사한 RED 로그와 구현 중 실패 로그를 보존했다. Chromium에서 부모 컨테이너 WAAPI 투명도 애니메이션 종료 후 화면은 보이지만 클릭 hit-test가 어긋나는 현상을 재현했다. 부모 진입 효과를 CSS keyframe으로 바꾸고 종료 클래스를 정리해 해결했다. 현재 안내/메뉴/지도 입력 검수가 통과한다. HP 바의 WAAPI는 pointer 대상과 분리되어 있다.

## 범위·한계

새 파일 `presentation.mjs`, `presentation.css`, 브라우저 검수2개, 설계/보고서/로그/영상. 연결 수정은 `app.mjs`, `expedition-ui.mjs`, `index.html`, 패키징·촬영·기존 화면 검수 스크립트다. 기존 engine/campaign/expedition/storage/panels/skills/timeline/audio 및 승인 PNG는 변경하지 않았다. 외부 패키지·에셋 다운로드, 삭제, 수동 배포, main 병합 없음.

관리형 Chromium에서 내부 응답 방식으로 모듈판과 독립 HTML을 실행했다. file:// 직접 열기, 실물 모바일·Safari/Firefox·스크린리더·실제 청취는 이번 환경에서 확인하지 않았다. 자동 완주는 동작/회귀 검수이며 재미나 인간 플레이 밸런스를 증명하지 않는다.

실행: ZIP을 풀어 standalone.html을 브라우저에서 열거나, 사용자의 로컬 게임 폴더에서 `python -m http.server 8000 --bind 127.0.0.1` 후 localhost:8000 접속. 개발 환경에서는 서버/배포를 시작하지 않았다. 되돌리기는 이 커밋을 revert하여 기준 head의 화면으로 복구한다.

## 전체 흐름과 전달 산출물

연습 3전투 일반 모듈판/축소 독립 HTML 완주2조합 통과(`presentation-campaign.log`). 탐험 전체 경로·보상·휴식·이벤트·정예·보스·패배 리로드·슬롯 격리:3해상도×2모션6조합 통과(`presentation-expedition.log`, 종료0). 추가360×640 일반 독립 HTML 완주/패배 복구 통과(`presentation-short-run.log`, 종료0).

실제 Chromium390×844 무음 영상 `presentation-play.mp4`:21.667초,1,957,205바이트. CDP 실제 화면602프레임을 기록하고 반복 전투의 중간 탭만 컷 편집했다. 원속도·실제 게임 화면이며 합성 장면 없음. 접촉시트 `presentation-video-contact.png`로 실제 영상 내용을 확인했다. 파일 직접 열기 성공으로 오해하지 않도록 브라우저 내부 응답 방식임을 명시한다.

이전 head308aaac의 Actions run39284070064는 이번 변경 전 조회 시 queued였다. 새 head CI는 push 이후 별도로 조회하며 이전 결과를 새 head의 통과로 대체하지 않는다. Draft PR 유지, 자동 병합/수동 배포 없음.
