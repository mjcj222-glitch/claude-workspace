# 원판형 색 폭탄 외형 교정

2026-10-22, 기준 `aa9d3b8f95addfde6a6f4ba91e0c9e18d958df4d` (PR #3).
이 대화에 첨부된 참고 이미지 픽셀을 직접 확인한 뒤 구현했다. 참고 이미지 원본은 저장소에 넣지 않았다.

검은 공·도화선·금테 대신 속성색의 평면 디스크, 짧고 넓은 직사각형 돌출부, 같은 계열 밝은 테두리, 반투명 회로선, 흰 방사형 별과 BOMB, 기술 라벨 선을 Godot CanvasItem으로 자체 그린다. 일반/대형은 같은 렌더러를 공유한다. 아래 작은 속성 문양은 색 외의 식별 보조다. 직접 선택은 흰 실선, 추가 연쇄는 금색 점선이다.

물리·히트테스트·표시 envelope는 일반37/대형48, 폭풍은98/164 그대로다. 돌출부 모서리도 원형 히트 영역 안에 있다. 원판 본체는 envelope의91%이고 돌출부는96%까지 이어진다. 이는 돌출부가 보이지 않는 입력 영역 밖으로 튀어나가지 않게 하는 외형 여백이며 충돌 크기 축소가 아니다. 선택 테두리도 원래 envelope 안이다.

게임 코드 변경은 `scripts/board_art.gd`의 폭탄 그리기와 사용하지 않는 구 SVG preload 제거뿐이다. 생성색 상속·렌즈 크기·동색 대상/경유·폭풍 연쇄·피해/약점/핵 생성 카운트·Rio/Noa·핵 변환 제외·낙하 solver는 변경하지 않았다. 이전 SVG 파일은 과거 증거를 위해 남긴다.

## 검증

- Godot4.6.3 Linux/Xorg/llvmpipe. 새 import 성공, 기존 규칙·물리·입력·캐릭터·탐험 회귀51개 스크립트 실패0. 각 로그는 `evidence/disc-bombs/regression/`.
- 하네스 구성 검사와 Python 단위 테스트5개 통과. 이것은 Godot 실행 검증과 별개다.
- 360×640,390×844,720×1080 실제 X11 입력 각각28개 통과: 동색 폭탄 경유, 다른 색 제외, 취소, 스킬 비기폭, 대형 미리보기/확정 일치, 하트 회복, 절제 모드, 리셋.
- 정상 자동 플레이는 보드·체력·충전·재화 주입 없이 기존 정상 초기화와 합법 입력을 사용한다. 아래 상태 비교 JSON에 두 캐릭터의 결과를 기록한다.
- 이전 렌더러를 넣은 `/tmp/chroma-disc/baseline`과 현재 코드를 fixed30fps로 실행했다. 모든 이벤트의 보드 위치/종류/반경/색·상태·계획을 재귀 비교하며 제외 항목은 `wall_ms`, `process_frame`, `scene_seconds`뿐이다. 노아92개·리오84개 이벤트와 최종 상태가 모두 일치했다. 노아21소거 HP30 승리, 리오19소거 HP30 승리 후 선택으로 복귀했다. 결과: `evidence/disc-bombs/state-comparison.json`. 측정 시간/성능 동등 주장이 아니다.

## 자료와 한계

- [전체 색·크기 도안](../evidence/disc-bombs/disc-sheet.png)
- [작은 창 연결 미리보기](../evidence/disc-bombs/windows/states-360x640-03-blue-large-preview.png)
- [노아 전체 녹화](../evidence/disc-bombs/noa-full.mp4), [리오 전체 녹화](../evidence/disc-bombs/rio-full.mp4)
- 정상 플레이/낙하 사진 및 원시 trace: `evidence/disc-bombs/normal/`.
- 원시 녹화는 Godot MovieWriter fixed30fps이며 실시간 지연 측정이 아니다. 클라우드 실시간 오디오는 Dummy이며 녹화에는 게임 합성 PCM을 담는다. 오디오 트랙 확인은 사람의 청취 만족도 평가가 아니다.
- Android/Windows/Web 실기기, 사람의 재미·최종 밸런스는 미검증. 실행 ZIP 재배포와 병합은 하지 않는다.

실패 기록: 첫 shallow fetch는45초 제한으로 종료됐다. 로컬 기존 커밋을 브랜치로 연결한 뒤 일반 fetch와 fast-forward는 성공했다. 첫720×1080 캡처는 가상 화면1364×1024 제한 때문에 ffmpeg exit234로 실패했다. 이후 인증된 같은 Xorg의 framebuffer를1364×1364로 확장했다. 도안 최초 출력의 불필요한 viewport 아래 여백은 캡처 영역을720×400으로 지정해 제거했다. 변경 전 기준 소스는 최신 원격의 부모와 같고 최신 커밋은 보고서만 추가한다.

추가 정상 경로: 리오 무료 이벤트 경로22소거 HP20 승리. 일반37/37·대형48/48 낙하 표본을 확인했다. 이 세 번째 경로는 전후 상태 비교 대상이 아니다. [14.7초 소리 포함 미리보기](../evidence/disc-bombs/disc-bombs-preview.mp4)는 리오 일반→노아 대형→노아 승리의 편집본이며 각 구간에 표기한다. [리오 일반/대형 전체](../evidence/disc-bombs/rio-free-full.mp4).

정상 캡처 중 폭탄 낙하·미리보기·승리만 공개 저장하고 나머지 중복 화면은 로컬에 보관했다. `capture-manifest.json`에 보관 여부를 기록했으며 원시 trace의 screenshot 목록은 전체 캡처 시도 목록이다.
