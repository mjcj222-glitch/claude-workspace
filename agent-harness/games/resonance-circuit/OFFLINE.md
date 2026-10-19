# 잔향 회로 — 다운로드 실행판

ZIP을 풀고 `resonance-circuit/standalone.html`을 브라우저로 열면 됩니다. 인터넷·서버·설치·API 키 없이 실행합니다. 원본 HTML/CSS/ES modules도 함께 포함되어 있습니다.

`standalone.html`은 검증된 원본을 `package_game.py`로 결합한 파일입니다. 코드 변경은 기존 모듈에서 검토하고 다시 생성하는 방식으로 관리합니다. 원본 `index.html`은 ES modules용 HTTP 환경이 필요하지만 `standalone.html`은 `file://`로 실행됩니다.

조작: 같은 색·모양을 눌러 미리 보고 같은 자리에서 떼면 확정. 방향키 이동, Enter/Space 확정. 3탭마다 전투 정산. 공격색 5개 이상을 연결하면 이웃에 잔향(◌)이 생깁니다. 다음 탭의 연결이 표식에 닿으면 이전 잔향 전체가 발동합니다. 스킬과 과충전을 활용하세요. 기본 무음이며 시스템의 reduced-motion을 따릅니다.

검증 한계: 이 클라우드 Chromium의 관리 정책이 `file://` 탐색을 ERR_BLOCKED_BY_ADMINISTRATOR로 차단했습니다. 따라서 직접 파일 열기 성공은 검증하지 못했습니다. 별도 서버 없이 브라우저 내부 응답으로 독립 HTML의 게임 흐름을 검사합니다. 최초 차단 기록은 `offline-validation.log`, 대체 검사는 `standalone-validation.log`에 있습니다. 실물 모바일 파일 열기 방식은 운영체제별 차이가 있으며 Safari/Firefox와 사람의 재미 평가는 미검수입니다.

배포하거나 main에 병합하지 않은 시제품입니다. Draft PR: https://github.com/mjcj222-glitch/claude-workspace/pull/2
