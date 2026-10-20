# 체크포인트 A: 화면·물리 모듈 검증

현재 영상과 이미지는 실제 Godot View·Board·Selection 모듈의 캡처다. 전투 컨트롤러·보상 정산·원정 진행의 완료 증거는 후속 체크포인트에서 별도로 제공한다.

- [실제 낙하 → 접촉 예고 → 제거 → 주변 굴림 → 리필 영상](checkpoint-a.mp4): 시드41, 720×1280, H.264, 30fps, 6.1초.
- [일반·움직임 줄이기 컷인 영상](cutin-modes.mp4): 각 컷인0.7초, 무대 안에만 표시되고 완전히 사라진다.
- [기본 보드](base-selection.png): 시드121의 실제 물리 배치.
- [폭탄 단계 갤러리](bombs-tiers.png)와 [직접·추가 대상 표시](bombs-selection.png): 명시적으로 고정 배치한 렌더링 시험 장면이며 물리 시드 보드가 아니다.
- [시드41 선택 예고](flow-seed41/connection-preview.png)와 [리필 정착](flow-seed41/refill-settled.png): 같은 실제 연속 실행의 원본 PNG. 같은 폴더의 JSON은 각 촬영 시점의 실제 기물 스냅샷이다.
- [파일별 해시·소스 기록](capture-manifest.json).

시드41에서 실제 선택한 ID는15,16,22,23,27,28,29이며, 정확히 한 번 생성한 새 ID43–49로42개를 복원했다. 정착 전후 실제 hull 면적은 보드의62.40%/61.43%, 상단 여백은66.35/92.89논리px, 최대 겹침 면적은9.03/2.25였다. 두 정착 상태 모두 경계·지지 조건을 통과했다. 제거 뒤 기존 이웃이 실제 충돌로 이동·회전하며, 정착 후 가짜 흔들림은 없다.

이 촬영의 리필 물리 시간은2.275시뮬레이션초다. 별도 네 시드·두 재사용 순서의 일반4·5·7개 제거는1.558–2.567초, 의도적으로 꾸민42개 전체 폭탄 리필 시험은최대4.925초였다. 일반 제거와 특수 시험은 서로 다른 측정이다. 녹화는 소프트웨어 렌더링·파일 저장 비용을 포함하므로 영상의 명목 시간이나 녹화 벽시계 시간을 실제 입력 잠금·기기 성능으로 해석하지 않는다. 실제 컨트롤러 잠금은 후속 검증 대상이다.

게임 소스는[03728c7](https://github.com/mjcj222-glitch/claude-workspace/commit/03728c7b9e8cfddad326e4cdb330670f8be4d0a0), 캡처 검사 도구 수정은[1746ab9](https://github.com/mjcj222-glitch/claude-workspace/commit/1746ab9210646d7fa4f9417ee36fb370834774ea)다. 도구 수정은 물리 크기에 맞춰 검사 픽셀 좌표를 계산하며 게임 코드·그림·규칙을 바꾸지 않는다.

`capture-manifest-interim.json`은 과거[c7b7fd0](https://github.com/mjcj222-glitch/claude-workspace/commit/c7b7fd0dfb394b48aca90a06bc0b48e8e0f6398f)의 중간 캡처에만 적용한다. `capture-manifest-density-interim.json`은99cc478의 두 파일 중간 전달 기록이다. 현재 전체 파일의 해시는 `capture-manifest.json`을 사용한다. 측정 범위는 기재한 시드와 실행 환경이다.
