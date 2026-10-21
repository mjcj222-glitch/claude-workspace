# 통합 AI 연구실 진행 검토 — 2026-10-21 / harness-bootstrap

- 회차 표시: 2026-10-21 00:00:00 UTC / 09:00:00 KST.
- 실제 요청 수신 및 검토 시작: 2026-10-20 23:55 UTC / 2026-10-21 08:55 KST. 예정 표시보다 먼저 수신되었으며 정확한 09:00 기동으로 보정하지 않는다.
- 순서: 조사 → 출처·실행 근거 검증 → 필요한 개발 작업 검토 → 보고.
- 범위: 공개 프로젝트 진행만 기록. 운영 코드 변경, 기존 파일 덮어쓰기, 병합, 수동 배포 없음.
- 비교 기준: 전날 일일 보고서와 PR #3 최종 개발 보고서. 새 기능을 이번 예약 작업에서 구현한 것으로 세지 않는다.

## 1. 조사와 새로 확인한 내용

### 연구실 운영

지정된 README, agent-harness/AGENTS.md, topics.json, roles의 research/verify/build/report 네 문서, prompts/dot-start.md, 보고서 양식, Issue #1과 최신 보고서를 실제 조회했다. 루트 AGENTS.md는 404였고 실제 규칙 파일은 agent-harness/AGENTS.md였다.

게시된 claude-workspace Codex Cloud 저장 환경을 실제 목록에서 확인했다. 이 확인 뒤에만 같은 저장 환경에 읽기 전용 하네스 검사를 위임했다. 집 PC나 로컬 앱은 사용하지 않았다. 환경 존재, 작업 생성, 명령 실행, 보고서 저장은 별도 증거로 구분한다.

README의 연결 대기 문구, topics.json의 환경 게시 단계, Issue #1의 체크박스는 현재 실행 증거를 모두 반영하지 못한다. 기존 문서를 수정하지 않고 이 보고서에 차이를 누적한다. Issue #1은 open 상태이며 PC 전원 OFF 실증 등 남은 항목 때문에 닫지 않았다.

### 게임 진행

[PR #3](https://github.com/mjcj222-glitch/claude-workspace/pull/3)을 다시 읽었을 때 open / Draft / 미병합 / mergeable이었다. 검토 전 head는 `46d48647b20e15e2a40517f1407a9f03a192200f`, base main은 `e2ebeb9783c98f3cc5f232652e026ee407c32c03`이다.

전날 오전의 [일일 보고서](https://github.com/mjcj222-glitch/claude-workspace/blob/main/agent-harness/reports/2026-10-20/harness-bootstrap.md)는 웹 게임 PR #2 기준이었다. 이후 Godot v2의 탐험·모집·세 전투·저장/재개·접촉 및 예고 표시 개선이 PR #3에 누적됐다. 이는 이전 일일 회차 대비 진전이다. 그러나 마지막 v2 결과 전달 이후 이번 조회까지 게임 코드의 추가 변화는 없다.

최신 방향은 어두운 배경과 읽기 쉬운 UI, 입체감 있는 기물, 보이는 접촉과 일치하는 선택, 누르는 동안 제거 범위 표시, 긴 연결 보상, 하단 주인공과 탐험 중 동료 영입, 캐릭터 스킬에 의한 색 변환·폭탄 생성이다. 추가 속성 피해는 제안 단계이며 이번 회차에서 구현하지 않았다. 약점 배율과 내성 규칙은 후속 방향 확정이 필요하고, 단순 격려나 다른 작업 승인으로 대체하지 않는다.

[최종 개발 보고서](https://github.com/mjcj222-glitch/claude-workspace/blob/46d48647b20e15e2a40517f1407a9f03a192200f/agent-harness/reports/2026-10-20/resonance-v2-final.md)와 [구현 판단 기록](https://github.com/mjcj222-glitch/claude-workspace/blob/46d48647b20e15e2a40517f1407a9f03a192200f/agent-harness/reports/2026-10-20/resonance-v2-rulings.md)을 확인했다. 전체 회귀 기준 9c56c8f와 후속 표시 수정 ce146c9의 검사 범위는 다르다. 여섯 탐험 완주·물리 전체 검사를 최신 UI에서 모두 재실행했다고 표현하지 않는다.

## 2. 공식 출처와 검증 상태

다음 원문은 2026-10-21 KST(2026-10-20 UTC)에 확인했다. 본문에 명시적 발행·갱신 날짜를 확보하지 못해 확인 날짜만 기록한다.

| 주장 | 공식 근거 | 확실성·한계 |
| --- | --- | --- |
| 미리 설정한 Cloud 환경에서 새 코딩 작업을 만들 수 있으며 사용자 PC는 오프라인이어도 된다. | [OpenAI Tasks and memory](https://learn.chatgpt.com/docs/dots/tasks-and-memory) | 제품 기능은 확인됨. 이번 실제 PC 전원 상태를 입증하지는 않는다. |
| 저장과 게시가 다르고 새 작업은 게시된 환경을 사용한다. 기존 작업은 자체 상태를 유지한다. | [OpenAI Cloud environments](https://learn.chatgpt.com/docs/environments/cloud-environments) | 확인됨. 이번 환경 목록 조회와 새 작업 생성으로 해당 연결도 확인했다. |
| 반복 고정시간 작업은 저장된 일정이 필요하고, 완료 상태만으로 산출물 성공·전달을 보장하지 않는다. | [OpenAI Tasks and memory](https://learn.chatgpt.com/docs/dots/tasks-and-memory) | 확인됨. 이번 회차 요청은 수신했으나 현재 일정의 enabled/다음 실행 시각은 재조회하지 않았다. |
| 로컬 컴퓨터 이용에는 온라인·앱 실행 등 별도 연결 조건이 있다. | [OpenAI Computers and apps](https://learn.chatgpt.com/docs/dots/computers-and-apps) | 확인됨. 이번 작업은 로컬 컴퓨터를 사용하지 않았다. |
| 로컬·클라우드 작업이 요금제 사용량을 공유하며 실제 사용량은 작업·모델 등에 따라 다르다. | [OpenAI Pricing](https://learn.chatgpt.com/docs/pricing) | 일반 정책 확인됨. 계정 잔여량·청구는 미조회이므로 금액 0원이나 무제한을 보장하지 않는다. |

공식 문서의 Markdown 주소는 브라우징 도구가 content-type을 지원하지 않아 실패했다. 같은 공식 HTML 본문을 직접 찾아 확인했으며 실패를 문서 부재로 해석하지 않았다.

## 3. 검증: 기존 실행과 이번 실행 분리

### 기존 게임·CI 증거의 재확인

- PR #3의 검토 전 head에 연결된 [Actions run 39450863786](https://github.com/mjcj222-glitch/claude-workspace/actions/runs/39450863786)은 completed/success였다.
- validate job의 구성 검사·표준 라이브러리 검사·프롬프트 생성 단계가 success임을 재조회했다.
- [워크플로](https://github.com/mjcj222-glitch/claude-workspace/blob/46d48647b20e15e2a40517f1407a9f03a192200f/.github/workflows/agent-harness-check.yml)는 하네스 검사이지 Godot 전체 게임 검사나 실물 모바일 검사 아니다.
- 게임 최종 보고서의 여섯 탐험, 실패·재시작, 입력·저장 검사 결과는 이번에 읽은 이전 실행 근거다. 이번 자동화에서 게임을 다시 실행하지 않았다.
- 데스크톱 개발 미리보기 한계는 그대로다. 일부 놓기→READY 약 2.66–5.31초, seed121 초기 위쪽 약 98.85 논리px 빈 공간, 실물 폰 성능·사람의 재미·모든 합법 보드 정착은 미검증이다.
- 긴 전체 영상은 9c56 기준이고 짧은 UI 보강 영상은 최신 표시 수정의 통제된 기능 시험이다. 영상 명목 프레임 시간과 실제 입력 지연을 혼동하지 않는다.

### 이번 회차의 실제 Cloud 검사

확인 시각: 2026-10-20 23:59 UTC / 2026-10-21 08:59 KST. 새 Cloud 작업의 완료 응답과 실제 출력을 회수했다.

- Python 3.12.14, 체크아웃 커밋 `e2ebeb9783c98f3cc5f232652e026ee407c32c03`.
- 환경의 체크아웃 브랜치 이름은 `work`였지만 원격 main 커밋과 같음을 읽기 전용 조회로 확인했다. main으로 체크아웃하거나 브랜치를 변경하지 않았다.
- `PYTHONDONTWRITEBYTECODE=1 python agent-harness/harness.py check`: 종료 0. 출력 `OK: 1 research topic(s), 4 role(s), templates present.`
- `PYTHONDONTWRITEBYTECODE=1 python -m unittest discover -s agent-harness/tests -v`: 종료 0, 5개 검사 모두 통과, 실패 없음. unittest 출력의 실행 시간은 0.001초다.
- 통과 항목: brief의 목표·규칙 포함, 기본 활성 주제, 경로 순회 ID 거부, 주제 ID 유일성, 작업 공간 구성 검증.
- 실행 전후 `git status --porcelain=v1`은 빈 출력이고 최종 diff, 커밋, 브랜치도 변하지 않았다.
- 최초 저장소 밖 디렉터리에서 Git 조회가 종료 128로 실패했다. 올바른 저장소 경로에서 다시 조회하여 해결했다. 이 실패를 검사 실패나 성공으로 덮지 않는다.
- 게임 실행·전체 Godot 검사·실물 모바일 검사·추가 다운로드는 미실행이다. 이번 성공은 하네스 기본 검사와 실제 클라우드 위임·결과 회수의 증거다.

## 4. 필요한 개발 작업 검토와 권한

이번 진도 검토는 기존 코드 변경이 필요하지 않으므로 하네스 검증과 새 보고서만 수행한다. README/Issue의 상태 갱신, 게임 입력 대기·빈 공간 개선, 새로운 속성 피해 규칙은 필요성만 검토했으며 이번 자동화로 구현·수정하지 않는다.

보고서는 기존 PR #3의 `feat/resonance-godot` 브랜치에 `agent-harness/reports/2026-10-21/harness-bootstrap-0900-review.md` 새 파일 하나로 누적한다. 기존 보고서·운영 코드·main은 변경하지 않으며 PR은 Draft로 유지한다. 생성 후 파일 재조회와 내용 일치, 새 커밋의 변경 파일 범위로 저장 여부를 확인한다. 보고서 추가가 기존 저장소 자동 CI를 일으킬 수 있지만 수동 워크플로 실행이나 배포 요청을 하지 않는다. 이전 CI 성공을 이 새 보고서 커밋의 성공으로 바꿔 말하지 않는다.

Pro 포함 사용량을 우선했고 별도 API 키, 유료 서버, 크레딧 구매, 자동 충전, 계정·권한 변경, 민감 정보 게시를 하지 않았다. 계정 사용량·청구는 조회하지 않아 추가 청구액 0원을 실증한 것은 아니다. 이번 확인된 검사에는 한도·권한 차단이 없었다.

## 5. 예약·실제 실행·PC OFF 검증의 구분

| 항목 | 이번 판단 |
| --- | --- |
| 예약 생성 | 이전 보고서에 생성 응답과 활성 상태 기록이 있다. 이번에는 새 예약을 만들거나 변경하지 않았다. |
| 이번 회차 호출 | 2026-10-21 09:00 KST 회차로 표시된 요청 수신 확인. 실제 수신은 08:55 KST였으므로 정각 실행 보장은 미확인이다. |
| 이번 실제 실행 | GitHub·공식 출처 조사, 게시 환경 확인, Cloud 검사 두 명령의 종료 0 및 결과 회수 확인. |
| 보고서 저장 | 생성 후 원격 파일 재조회로 별도 확인하여 사용자에게 링크를 전달한다. 본문 자체가 전달 성공을 증명하지는 않는다. |
| 집 PC 전원 OFF | 미확인. 로컬 PC를 사용하지 않은 것과 실제 PC가 꺼져 있던 것을 구분한다. 연결 표시나 모바일 접속을 전원 OFF의 증거로 삼지 않는다. |
| 변화 없음 | 마지막 게임 최종 결과 전달 이후 새 게임 코드 변화 없음. 전날 일일 보고 대비 PR #3 개발 진전과 이번 Cloud 기본 검사 재실행은 새 확인 사항이다. |

## 6. 남은 질문·다음 점검 — 최대 3개

1. 실제 PC 전원 OFF 기간과 예약 실행·저장 시각을 대조할 수 있는가? 증거가 없으면 미확인으로 유지한다.
2. 속성 피해의 약점·내성 규칙과 후속 게임 개선 범위가 확정되면, 별도 명세·검사 기준을 정하고 승인 범위에서만 개발할 수 있는가?
3. 다음 회차에도 최신 커밋·CI·기존 보고서를 구분하고 중복 없는 새 보고서를 검증하여 누적할 수 있는가?

이번 보고서에는 개인정보, 계정 비밀, 기기 식별자, 비공개 작업 주소, 참고 이미지 원본을 포함하지 않았다.
