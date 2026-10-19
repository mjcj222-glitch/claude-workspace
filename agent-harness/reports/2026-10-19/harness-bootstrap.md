# 일일 연구 보고서 — 2026-10-19 / harness-bootstrap

- 작성 시각(KST): 2026-10-19 19:26
- 목표: PC 전원과 독립적인 dot 연구 → Codex Cloud 개발 → GitHub 보고 루프 검증
- 역할: 조사 → 검증 → 개발 가능성 점검 → 보고
- 상태: 일부 완료. 전체 자동 개발 파이프라인 완료 아님.

## 확인 결과
1. 저장소 지침과 Issue #1 읽기 성공. README, AGENTS, topics.json, dot-start 및 역할 지침을 확인했다.
2. 공식 문서는 dot 반복 점검과 사전 생성된 Codex Cloud 환경 위임을 지원한다. 기능 지원과 계정별 준비 상태는 별개다.
3. 실제 환경 조회에서 선택 가능한 저장된 codingEnvironments는 빈 목록이었다. 현재 dot에서 사용할 환경이 확인되지 않았다는 뜻이며, 다른 계정/작업공간이나 Legacy 환경의 존재까지 부정하지 않는다.
4. 일일 연구 예약 생성 성공: 제목 ‘통합 AI 연구실 진행 검토’, enabled=true, Asia/Seoul, DTSTART 2026-10-20 09:00, DAILY 09:00. 생성 응답으로 활성 상태와 저장된 일정을 확인했다. 첫 실행 기록 및 실제 Scheduled 화면 렌더링은 아직 검증하지 않았다. 반환된 next_run_time/last_run_time은 null이다.
5. 새 제작 목표로 퍼즐 게임이 요청되었다. 참고 게임은 Crash Fever이며, 핵심 재미 조사 후 독자적인 자산과 규칙으로 작은 시제품을 설계한다. 기존 세계관이나 자산을 복사하지 않는다.

## 주장과 근거
- 확인됨: dot은 자체 클라우드 컴퓨터와 반복 점검을 지원하며 미리 생성한 Codex Cloud 환경을 사용할 수 있다. [dot 시작 안내](https://help.openai.com/en/articles/20001530-getting-started-with-your-dot), 확인 2026-10-19, 페이지 표시 갱신 4일 전.
- 확인됨: Codex Cloud 환경은 웹/데스크톱에서 생성·게시하며 클라우드 작업은 사용자 컴퓨터가 잠들어도 계속될 수 있다. [Codex Cloud](https://help.openai.com/en/articles/20001545-using-codex-cloud), 확인 2026-10-19, 페이지 표시 갱신 17일 전.
- 확인됨: 표준 Cloud VM은 출시 시점 별도 VM 요금이 없으나 모델 작업은 포함 사용량과 적용 가능한 크레딧/청구에 반영된다. [Codex 요금제와 사용량](https://help.openai.com/en/articles/11369540-using-codex-with-your-chatgpt-plan), 확인 2026-10-19. 계정 잔여 사용량과 자동 충전 설정은 조회하지 않았다.
- 부분 확인: PC OFF 자동 연구의 구조는 공식 지원되지만 이번 계정에서 PC OFF 상태와 예약 실행 결과를 대조한 실증은 아직 없다.

## 개발·테스트
- 실제 수행: GitHub 파일/Issue 읽기, 환경 목록 조회, 기존 예약 목록 조회(0개), 새 예약 생성.
- 미실행: `python agent-harness/harness.py check`.
- 미실행: `python -m unittest discover -s agent-harness/tests -v`.
- 이유: 사용자가 지정한 Codex Cloud 환경을 선택할 수 없었다. 다른 컴퓨터나 자체 실행 환경에서 대신 돌린 결과를 Codex Cloud 테스트라고 보고하지 않았다.
- 코드 변경/배포/병합: 없음. 이번 변경은 이 보고서 파일 추가뿐이다.

## 비용·보안
- 추가 크레딧 구매, API 키 발급, 유료 서버, 자동 충전, 계정 보안 변경을 수행하지 않았다.
- 포함 사용량 우선이라는 운영 제약을 예약 지침에 반영했다. 과금 대시보드 미조회이므로 총 비용 0원을 실증한 것은 아니다.
- 공개 보고서에는 비밀키, 쿠키, 개인 자료나 연결된 개인 기기 식별자를 포함하지 않았다.

## 다음 과제 (최대 3개)
1. 같은 계정/작업공간의 Settings → Codex Cloud → Environments에서 해당 저장소 환경을 생성·게시한 뒤 dot 목록에 나타나는지 재확인한다. [환경 생성 안내](https://learn.chatgpt.com/docs/environments/cloud-environments).
2. 확인된 환경에서 위 두 테스트를 실행하고 실제 로그·종료 상태를 보고한다.
3. 첫 예약 실행 후 보고서 누적과 결과 전달을 확인한다. PC 전원 OFF 여부는 사용자 확인과 함께 별도 검증한다.

## 남은 질문
- 게시된 새 Cloud 환경을 dot에서 선택할 수 있는가?
- 첫 예약 실행이 실제로 이루어지고 GitHub 보고서가 생성되는가?
- Crash Fever의 어떤 핵심 루프를 첫 퍼즐 시제품에 담을 것인가?
