# Codex Cloud 첫 테스트 — 전체 복사

전제: `mjcj222-glitch/claude-workspace` 저장소 연결 후 개인용 Cloud 환경을 만들고 게시한 상태.

---

이 저장소의 `agent-harness/` 폴더에서만 작업해 줘. 먼저 `README.md`, `AGENTS.md`, `topics.json`을 읽어라.

다음 작업을 **읽기 및 테스트 중심으로** 수행:
1. `agent-harness/` 파일 구조와 각 역할을 1문장씩 설명.
2. `python agent-harness/harness.py check` 실행.
3. `python -m unittest discover -s agent-harness/tests -v` 실행.
4. `python agent-harness/harness.py brief --topic harness-bootstrap --role research` 실행.
5. 실패 항목과 원인을 보고해라.

승인 전에는 기존 저장소의 다른 디렉터리 변경, 공개 게시, API 호출·과금, 외부 서비스 로그인·배포를 하지 마라. 테스트를 실제로 실행하지 못했다면 그 사실을 밝혀라.

---
