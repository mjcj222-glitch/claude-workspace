# 통합 AI 연구실 진행 검토 — 2026-10-23

- 회차: 2026-10-23 00:00 UTC / 09:00 KST.
- 실제 조회: 2026-10-23 00:00–00:02 UTC.
- 순서: 조사 → 검증 → 필요한 개발 작업 검토 → 보고.
- 범위: 공개 가능한 진행 기록인 이 새 파일만 추가. 기존 파일·운영 코드·계정·예약·병합·배포는 변경하지 않는다.

## 1. 조사: 읽은 자료와 변화

다음 저장소 자료를 직접 읽었다: agent-harness/README.md, agent-harness/AGENTS.md, topics.json, roles/research.md·verify.md·build.md·report.md, prompts/dot-start.md, Issue #1와 댓글 목록, 10/22 일일 보고서, 최신 원격의 SYSTEMS_STATUS.md·FULLBODY_CLIMAX_VALIDATION.md·ABILITY_FOLLOWUP.md·SAVE_RECOVERY.md와 하네스 워크플로.

루트 AGENTS.md는 404였으며 실제 지침은 agent-harness/AGENTS.md다. roles 디렉터리에는 위 네 파일이 있다. main 보고서 목록에는 10/19·10/20만 있지만, PR #3 브랜치에는 10/21·10/22가 존재한다. 기본 브랜치 404를 이전 보고서 유실로 해석하지 않았다.

- [10/22 보고서](https://github.com/mjcj222-glitch/claude-workspace/blob/aa9d3b8f95addfde6a6f4ba91e0c9e18d958df4d/agent-harness/reports/2026-10-22/harness-bootstrap-0900-review.md)
- [Issue #1](https://github.com/mjcj222-glitch/claude-workspace/issues/1): open, 댓글 0, 마지막 갱신 2026-10-19. 초기 체크박스는 현재 실행 상태의 실시간 지표가 아니다.
- [PR #3](https://github.com/mjcj222-glitch/claude-workspace/pull/3): open / Draft / 미병합.
- 이번 보고서 추가 전 head: **deb647104bb6254563d19c1838a4ac07a21cec81**.
- main: **e2ebeb9783c98f3cc5f232652e026ee407c32c03**.
- 직전 일일 보고의 02356c2 이후 원격에는 전신 캐릭터, 3회 소거 축적 후 단일 공격, 저장 복구 관련 기록이 추가됐다. 그러나 최근 대화에서 보고된 로컬 통합본 5498e40을 원격 head로 오표기하지 않는다.
- 마지막 확인된 deb6471 이후 **원격 게임 코드 변화 없음**. 진행 중인 교정의 수정 완료나 새 게임 커밋은 이번 조회에서 확인되지 않았다.

## 2. 검증: 주장·출처·확실성

### 공식 제품 출처

확인일: 2026-10-23. 아래 상대 갱신 표시는 조회 당시 표시이며 정확한 발행일로 환산하지 않았다.

| 주장 | 공식 출처 | 상태와 한계 |
| --- | --- | --- |
| Codex Cloud는 관리형 컴퓨터와 게시된 환경을 사용한다. 기존 작업을 계속하는 것과 새 작업의 별도 작업 공간은 다르다. | [Using Codex Cloud](https://help.openai.com/en/articles/20001545-using-codex-cloud), Updated 18 days ago | 확인됨. 환경 목록에 있다는 사실만으로 현재 실행기 준비 완료를 증명하지 않는다. |
| Cloud 작업은 사용자 컴퓨터가 잠든 동안 계속될 수 있다. | 같은 공식 문서 | 제품 기능 확인됨. 특정 사용자의 PC가 실제 꺼져 있었는지는 별도 증거가 필요하다. |
| Pro 등 계정의 Cloud 제공 여부는 제공 범위·워크스페이스 설정과 사용량 한도 영향을 받는다. | [Using Codex with your ChatGPT plan](https://help.openai.com/en/articles/11369540-using-codex-with-your-chatgpt-plan), Updated 17 hours ago | 일반 정책 확인됨. 이번에 계정 잔여 사용량·청구액을 조회하지 않았으며 무제한·추가비용 0원을 보장하지 않는다. |
| 환경 접근과 GitHub 저장소 접근 및 작업 내부 Git 설정은 별개다. | Using Codex Cloud FAQ | 확인됨. 재시작 대기와 GitHub 쓰기 실패를 동일 원인으로 단정하지 않는다. |

### 실제 실행과 기존 보고의 구분

- **확인됨:** 이번 목록 조회에서 해당 저장소를 포함하는 게시된 저장 Cloud 환경과 버전이 실제 반환됐다. 집 PC나 로컬 앱은 사용하지 않았다.
- **부분 확인:** 기존 교정 작업은 현재 inProgress다. 00:01 UTC에 읽은 최신 기록은 “선택된 환경이 재시작 중”이며, 생성 경로·물리 반경·표시 크기를 비교하겠다는 상태다. 요청 접수는 확인했지만 새 수정·영상·테스트 성공은 아직 아니다.
- **미실행:** 이번 정기 검토에서는 새 Cloud 작업, 하네스 명령, Godot 테스트, 긴 회귀 검사, 패키징을 실행하지 않았다. 현재 승인된 교정 작업을 중복 실행하지 않았다.
- **확인됨:** deb6471의 기존 GitHub validate 두 건은 completed/success다: [run 39750230124](https://github.com/mjcj222-glitch/claude-workspace/actions/runs/39750230124), [run 39750245968](https://github.com/mjcj222-glitch/claude-workspace/actions/runs/39750245968). [워크플로](https://github.com/mjcj222-glitch/claude-workspace/blob/deb647104bb6254563d19c1838a4ac07a21cec81/.github/workflows/agent-harness-check.yml)는 하네스 구성·표준 라이브러리 검사·프롬프트 생성 범위다. 게임 전체·Windows·새 통합본 검증이 아니다.
- **기존 실행 기록:** [FULLBODY_CLIMAX_VALIDATION.md](https://github.com/mjcj222-glitch/claude-workspace/blob/deb647104bb6254563d19c1838a4ac07a21cec81/agent-harness/prototypes/godot-touch-board/docs/FULLBODY_CLIMAX_VALIDATION.md)는 53개 명령 통과와 마지막 한 줄 수정 후 영향 검사·정상 완주 재실행을 구분한다. 이를 마지막 수정 뒤 전체 묶음을 다시 통과했다는 뜻으로 바꾸지 않는다. 이번 검토는 기록 열람이지 재실행이 아니다.
- **문서 시차:** SYSTEMS_STATUS의 오래된 “저장·재개 없음”과 후속 [SAVE_RECOVERY.md](https://github.com/mjcj222-glitch/claude-workspace/blob/deb647104bb6254563d19c1838a4ac07a21cec81/agent-harness/prototypes/godot-touch-board/docs/SAVE_RECOVERY.md)의 저장 구현 기록은 시점이 다르다. 기존 Godot 저장 구현이 새 브라우저 퍼즐/Godot 연결본에서도 연결·검증됐다고 추론하지 않는다.
- **부분 확인:** 최근 개발 보고에서 원본 퍼즐 모듈 재사용과 CHROMA 진행 연결, 로컬 5498e40 및 시연 전달이 기록됐다. 본 회차는 그 소스·영상 전체를 독립 재실행하지 않았다. 특히 파일 동일성은 최종 화면·자연스러운 생성·부피·손맛 일치의 증거가 아니다.

## 3. 필요한 개발 작업 검토: 최신 방향 반영

사용자 최신 피드백은 “모두 균일한 패널”, “큰 패널과 캐릭터 패널의 자연스러운 생성 부족”, “기존 타일 외형 변경”이다. 따라서 단순 연결 성공을 완성으로 판단하지 않는다.

현재 기준:
- 일반 타일은 불·물·번개·회복 하트 네 종류. 캐릭터 패널과 큰 특수 패널은 일반 속성 종류와 구별한다.
- CHROMA의 기존 타일 모양·광택·입체감과 자체 그림·음악은 보존한다.
- 참조 저장소 [blanccurieux/crash-test](https://github.com/blanccurieux/crash-test)의 동작을 실제 비교하되, 타일 아트를 획일적인 도형으로 바꾸지 않는다.
- 큰 패널은 단순 확대 그림이 아니라 공간 점유·충돌 반경·주변 낙하 반응이 함께 맞아야 한다.
- 캐릭터 패널은 정상 플레이의 생성 조건과 전환·발동 과정이 보여야 한다. 임의 배치된 화면만으로 입증하지 않는다.
- 기존 시작 캐릭터 선택, 로그라이크 진행·유물·적 패턴을 보존한다.
- 현재 사용자 우선순위는 긴 테스트와 재패키징이 아니라 수정된 실제 화면·생성 순간부터의 영상이다. 정기 검토가 임의로 테스트를 재개하지 않는다.

최소 검토 지점은 통합 어댑터/설정이 원본 생성 경로를 덮는지, 표시 크기와 물리 반경을 동일 값으로 고정하는지, 아트 치환이 잘못됐는지다. 이는 **원인 후보**이며 아직 발견된 결함이나 수정 완료가 아니다. 원본에 없는 수치나 조건을 추측해 추가하지 않는다. 정확한 원작 Crash Fever 전체 규칙을 복제했다는 주장도 하지 않는다.

## 4. 예약·현재 실행·저장·PC OFF 구분

| 항목 | 이번 상태 |
| --- | --- |
| 예약 생성 | 이번에 생성·수정·중단하지 않음. 현재 회차 요청 수신은 확인. 예약 목록의 enabled/다음 회차는 이번에 재조회하지 않음. |
| 현재 연구 실행 | 저장소·Issue·보고서·Cloud 목록·작업 상태·공식 자료를 실제 읽고 검토함. |
| 새 개발/테스트 | 이번 정기 검토에서는 미실행. 별도 승인된 교정 작업은 inProgress / 환경 재시작 기록, 완료 미확인. |
| 공개 보고서 | PR #3의 기존 브랜치에 이 새 경로만 생성. 생성 응답 후 원격 파일을 재조회해 실제 저장을 확인한다. |
| PC 전원 OFF | 미검증. 로컬 PC 비의존 실행과 실제 전원 OFF 증거는 다르다. |
| 변화 없음 | 마지막 deb6471 이후 원격 게임 코드 변화 없음. 다만 최신 사용자 수용 기준과 교정 요청은 새로 반영됨. |

README/topics/Issue의 초기 상태를 무단 갱신하거나 이슈를 닫지 않았다. 보고서 추가로 기존 하네스 CI가 자동 시작될 수 있으나 수동 실행·워크플로 변경·배포를 요청하지 않는다.

## 5. 비용·권한·남은 질문

추가 API 키, 유료 서버, 크레딧 구매, 자동 충전, 배포, 계정·보안 설정 변경을 하지 않았다. 사용자 개인정보·계정 식별자·비공개 작업 링크·첨부 이미지 원본은 공개 보고서에서 제외했다. 재사용 허가에 관한 대화 확인을 별도 공개 라이선스 문서가 존재한다는 증거로 바꾸지 않는다.

남은 질문과 다음 과제는 최대 3개다.
1. 같은 Cloud 작업의 재시작이 끝나 실제 비교·수정·촬영이 실행되는가? 시작/접수와 완료를 구분한다.
2. 기존 CHROMA 타일 외형을 보존하면서 큰 패널 공간 점유와 캐릭터 패널의 정상 생성·발동을 실제 영상으로 확인할 수 있는가?
3. 해당 교정 확인 뒤에만 사용자가 원하는 다음 단계(저장 연결·실행본·검증 범위)를 이어가며, 별도로 PC OFF 시간과 예약 실행 증거를 대조할 수 있는가?

이번 보고는 상용화 완성, 최신 Windows 실행 성공, 사용자 만족, 실제 음향 청취나 기기 성능을 주장하지 않는다.
