# 개인 AI 에이전트 하네스 — 0원 추가 인프라 MVP

> 2026-10-19 · **준비 상태: 저장소 구성 완료 / 계정 연동 대기**
>
> 이미 구독 중인 ChatGPT Pro를 활용하는 **dot + Codex Cloud** 운영안. **API 키 없이**, **별도 VPS 없이** 시작한다.

## 무엇이 되는가?

- **dot:** 일정에 따라 연구하고, 조사 → 반론 검증 → 보고를 관리하는 총괄 에이전트. 자체 클라우드 컴퓨터에서 집 PC 없이 실행 가능.
- **Codex Cloud:** dot이 위임하는 코드 작업과 테스트를 OpenAI 관리 컴퓨터에서 실행. 먼저 사용자 계정으로 환경 생성·게시 필요.
- **GitHub:** 연구 주제, 역할 지침, 보고서, 코드 변경 이력 저장.
- **이 폴더의 `harness.py`:** 사용료가 없는 로컬 도우미. 주제·역할별 작업 지시문 생성, 구성 검증, 보고서 양식 초기화. **AI 모델을 직접 호출하지 않음**.

**한계:** 이 저장소만으로 24시간 AI 추론이나 자동 클라우드 작업이 시작되는 것은 아니다. **dot에 프로젝트 목표·예약 작업을 실제 등록**하고 **Codex Cloud 환경을 사용자 계정으로 연결**해야 한다. 초기 '4개 에이전트'는 역할 분담이지 별도 프로세스 4개가 상주하는 구조가 아니다.

## 집에서 남은 계정 연결 (필수 작업 3개)

1. [Codex](https://chatgpt.com/codex) → ChatGPT Pro로 로그인 → GitHub `mjcj222-glitch/claude-workspace` 연결 → **새 Codex Cloud 환경 생성 후 게시**. 다른 프로젝트를 건드리지 않도록 작업 범위를 `agent-harness/`로 제한.
2. 생성한 환경에 [첫 테스트 작업](prompts/codex-first-task.md)의 내용을 보내기. 파일 목록 조사와 `python agent-harness/harness.py check` 실행을 시키고 **변경사항은 승인 전 반영 금지**.
3. [dot](https://chatgpt.com/dots) → [시작 프롬프트](prompts/dot-start.md) 복사해서 전달 → 방금 만든 Codex Cloud 환경을 쓰라고 지시 → dot의 **Scheduled/예약됨**에서 반복 연구를 실제 등록·확인.

dot이나 Codex에서 GitHub 쓰기 요청이 나오면 최소한의 저장소 권한을 부여한다. 연동·접근 승인, 로그인, 결제는 사용자만 할 수 있다.

## 역할 구성

| 역할 | 역할 명세 | 주요 산출물 |
|---|---|---|
| 총괄(dot) | [AGENTS.md](AGENTS.md) | 연구 우선순위/다음 실행 |
| 조사 | [roles/research.md](roles/research.md) | 출처 있는 사실 |
| 검증 | [roles/verify.md](roles/verify.md) | 반론·불확실성 |
| 개발(Codex) | [roles/build.md](roles/build.md) | 테스트된 코드/PR |
| 보고 | [roles/report.md](roles/report.md) | 날짜별 Markdown 보고서 |

첫 연구 과제는 [topics.json](topics.json)의 `harness-bootstrap`: **에이전트 하네스 자체의 안정적 구축·개선**. 나중에 여기에 다른 주제를 추가하면 된다.

## 로컬 검증과 프롬프트 생성 (선택)

Python 3.10 이상. 외부 패키지 불필요.

```bash
python agent-harness/harness.py check
python agent-harness/harness.py status
python agent-harness/harness.py brief --topic harness-bootstrap --role research
python agent-harness/harness.py brief --topic harness-bootstrap --role verify
python agent-harness/harness.py report-template --topic harness-bootstrap --date 2026-10-19
python -m unittest discover -s agent-harness/tests -v
```

`brief`는 각 역할의 **복사 가능한 프롬프트를 출력**하며 실제 LLM 호출·과금을 하지 않는다. `report-template`은 빈 보고서 파일만 생성한다. 자동 연구·보고 실행은 dot에서 별도로 예약해야 한다.

## 안전·비용

- 이미 결제 중인 Pro 요금제에 **포함된 dot / Codex 사용량**을 먼저 이용한다. 기본 Codex Cloud VM에는 별도 요금이 없다고 안내되어 있지만, 기능/사용량 한도·추가 크레딧은 계정별 확인이 필요하다.
- **ChatGPT 구독으로 OpenAI 일반 API가 무료가 되는 것은 아니다.** 자체 SDK와 API 키 기반 자동 연구는 별도 과금 가능.
- 자동 크레딧 충전은 켜지 않는다. 사용량 설정에서 상한·알림·추가 구매 여부를 확인한다.
- 공개 저장소임: 비밀번호, 쿠키, 토큰, 개인자료, 사적인 연구 내용, 계정 정보 절대 저장 금지. 비공개 연구는 비공개 저장소로 분리.
- 공개 게시, 대량 파일 변경/삭제, 외부 전송, 유료 리소스 생성은 사전 승인. 최대 하루 1회 연구 + 요청 시 추가 실행부터 시작.
- Codex가 연구 결과를 직접 커밋할 권한이 없다면 **저장 성공이라 표현하지 않고** 결과 초안을 보여준다.
- 집 PC가 꺼져도 클라우드 연구 가능하지만 **PC 로컬 파일/앱 접근은 불가**.

## 운영 현황

- [x] GitHub에 역할 지침, 연구 주제, 작업 브리프 생성기, 검증용 테스트 준비
- [ ] Codex Cloud 환경 실제 연결·게시 (계정 로그인 필요)
- [ ] dot에 이 저장소 및 역할 지침 전달 (계정 UI 필요)
- [ ] dot 정기 실행 작업 실제 예약 (계정 UI 필요)
- [ ] PC 전원 꺼진 상태로 첫 연구 보고서 생성·검증
- [ ] 필요 시 완전 독립 멀티에이전트/DB/로컬 PC 실행으로 확장

공식 정보:
- https://help.openai.com/en/articles/20001530-getting-started-with-your-dot
- https://help.openai.com/en/articles/11369540-using-codex-with-your-chatgpt-plan
- https://help.openai.com/en/articles/20001545-using-codex-cloud
