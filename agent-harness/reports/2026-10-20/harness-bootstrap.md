# 일일 연구 보고서 — 2026-10-20 / harness-bootstrap

- 작성 시각(KST): 2026-10-20 09:22
- 검토 대상: 첫 09:00 KST 예약 실행과 연구·검증·개발·보고 연결 상태
- 역할: 조사 → 반론·증거 검증 → 개발 필요성 검토 → 보고
- 이번 결과: 연구 검토 완료. PC 전원 OFF 상태의 무인 연속 실행은 미확인.
- 공개 범위: 프로젝트 진행 결과와 공개 출처만 기록. 계정·기기 식별자와 비공개 작업 링크는 제외.

## 1. 오늘 새로 확인한 내용

1. **첫 예약 호출 수신 확인.** 2026-10-20 00:00:00 UTC, 즉 09:00 KST 실행으로 표시된 예약 요청이 도착했다. 이는 예약 생성만 확인했던 [전날 최초 보고서](../2026-10-19/harness-bootstrap.md)에서 진전된 부분이다. 근거는 이번 실행 요청과 수신 기록이며 공개 URL은 없다. 현재 예약의 enabled 상태와 다음 실행 시각을 다시 조회한 것은 아니다. 첫 호출 수신과 중단 없는 무인 완료를 같은 의미로 보지 않는다.
2. **게시된 Cloud 환경은 계속 조회된다.** 09:20 KST 환경 목록에서 이 저장소의 main을 사용하는 claude-workspace 저장 환경을 확인했다. 환경 목록에 나타난다는 사실과 새 작업 실행 성공은 별개다. 이번 점검에서는 새 개발 작업을 생성하지 않았다. 실제 Cloud 개발·테스트가 수행됐다는 전날의 [실행 결과](../2026-10-19/cloud-execution-result.md)는 아래 공개 코드·로그로 보완 확인했다.
3. **게임 검증 기준이 전날 첫 결과보다 발전했다.** [Draft PR #2](https://github.com/mjcj222-glitch/claude-workspace/pull/2)는 open, draft=true, merged=false이고 head는 `1c5e273237c1c89e25f2b52045fbb3c227854532`이다. 전날 초기 보고의 25개 테스트·초기 head를 최신 결과로 재사용하지 않았다. 현재 head에 기록된 게임 단위 테스트는 108/108이며 브라우저 완주 로그도 존재한다. 이번에는 기존 로그를 읽어 검증했고 테스트를 새로 실행하지 않았다.
4. **GitHub CI와 게임 검수의 범위를 구분했다.** head에 연결된 [Actions run 39286143536](https://github.com/mjcj222-glitch/claude-workspace/actions/runs/39286143536)은 completed/success다. 이 CI는 harness 구성 검사, Python 테스트 5개, verify 프롬프트 생성만 수행한다. 게임 108개 테스트와 Chromium 완주 성공의 근거는 별도 Cloud 실행 로그다.
5. **새 고전 판타지 아트/UI 적용 완료는 아직 아니다.** 후속 작업의 UI 초안·자산 교체 지점 준비와 실제 새 그림 통합을 구분한다. 이번 조회 시 PR head는 위 커밋으로 유지되고 있다. 따라서 기존 테스트 통과를 새 아트 적용·재패키징·최종 화면 승인으로 확대 해석하지 않는다.

## 2. 공식 출처 조사와 주장별 검증

아래 문서는 2026-10-20 KST 원문을 열어 확인했다. 조회된 본문에 명시적인 발행·갱신 날짜가 없으므로 확인일만 기록하며, 검색 엔진의 수집일을 문서 발행일로 간주하지 않는다.

| 주장 | 근거 | 상태와 남은 불확실성 |
|---|---|---|
| dot의 클라우드 작업은 사용자 PC가 꺼져도 가능하고, 미리 구성한 Codex Cloud 환경을 사용할 수 있다. | OpenAI [Computers and apps](https://learn.chatgpt.com/docs/dots/computers-and-apps), [Cloud environments](https://learn.chatgpt.com/docs/environments/cloud-environments) | **확인됨: 제품 기능.** 이번 첫 예약 실행 당시 실제 PC 전원 상태까지 입증하지는 않는다. |
| 정해진 시간 반복 작업에는 저장된 일정이 필요하고, 시간대·작업 내용·알림 기준·전달 위치를 구분해야 한다. | OpenAI [Tasks and memory](https://learn.chatgpt.com/docs/dots/tasks-and-memory) | **확인됨: 제품 기능.** 이번 호출 수신은 확인했지만 현재 예약 설정의 지속 활성 상태와 다음 회차는 별도 확인 대상이다. |
| Pro 포함 사용량을 활용하더라도 사용량 무제한·추가 비용 0원이 자동 보장되지는 않는다. | OpenAI [Pricing](https://learn.chatgpt.com/docs/pricing) | **확인됨: 일반 정책.** 모델·추론·도구 사용에 따라 사용량이 달라지고 cloud/local 사용량은 요금제 한도를 공유한다. 계정 잔여량·추가 크레딧·청구 내역은 미조회다. |
| 현재 저장소를 읽고 날짜별 공개 보고서를 누적할 수 있는 연결 경로가 있다. | 이 저장소의 README·AGENTS·topics·roles·Issue #1 및 전날 보고서 실제 조회 | **읽기 확인됨.** 이번 새 보고서의 저장 성공은 파일 생성 응답만으로 판정하지 않고, 생성 후 GitHub 재조회와 내용 일치로 확인한다. |
| PC OFF 상태의 첫 무인 연구가 끝까지 성공했다. | 예약 호출은 수신했지만 당시 PC 전원 상태와 무인 연속 완료를 대조한 증거 없음 | **미확인.** 연결 상태 표시를 실제 전원 OFF의 증거로 바꾸지 않는다. |

### 이전 문서와의 차이

- [README](../../README.md)의 계정 연동 대기 문구와 미완료 체크박스, [topics.json](../../topics.json)의 환경 게시 단계는 이전 상태를 담고 있다. 현재 환경 조회와 [전날 후속 결과](../2026-10-19/cloud-execution-result.md)를 함께 읽어야 한다.
- [Issue #1](https://github.com/mjcj222-glitch/claude-workspace/issues/1)은 여전히 open이다. PC OFF 실증 등 남은 조건이 있어 이번에 닫지 않았다.
- 기존 문서·체크박스를 덮어쓰지 않고 이 날짜 보고서에 새 증거를 추가한다.

## 3. 개발·도구 실행 내역

### 이번에 실제 수행한 작업

- `agent-harness/README.md`, `AGENTS.md`, `topics.json`, `roles/*.md`, `prompts/dot-start.md`, 보고서 양식, Issue #1과 댓글 조회.
- 전날 보고서 4개, 현재 공개 저장소 메타데이터, 게시된 저장 환경 목록 조회.
- PR #2의 draft·병합 여부·head 확인.
- CI run·job·원문 로그와 워크플로 파일 확인.
- 같은 head의 게임 보고서·단위 테스트·레이아웃·연습/탐험 완주 로그를 읽어 대조.
- 날짜별 reports 목록에서 2026-10-20 보고서가 아직 없음을 확인하고 이번 새 파일만 생성하도록 준비.

### 기존 실행 결과를 재검증한 항목

검사 시점은 2026-10-20 KST이다. 아래는 이번에 다시 실행한 테스트가 아니라 기존 실행의 공개 증거다.

| 실행 주체·대상 | 기존 결과와 정확한 범위 | 공개 근거 |
|---|---|---|
| GitHub Actions, 현재 PR head에 연결된 run | harness check 성공, Python unittest 5/5, verify 프롬프트 생성 성공. job 로그는 PR의 시험용 merge ref를 checkout했으며 실제 main 병합을 뜻하지 않는다. | [run](https://github.com/mjcj222-glitch/claude-workspace/actions/runs/39286143536), [워크플로](https://github.com/mjcj222-glitch/claude-workspace/blob/1c5e273237c1c89e25f2b52045fbb3c227854532/.github/workflows/agent-harness-check.yml) |
| 기존 Cloud 게임 단위 검사 | `node --test` 108개 통과, 실패·취소·skip 0 | [presentation-unit.log](https://github.com/mjcj222-glitch/claude-workspace/blob/1c5e273237c1c89e25f2b52045fbb3c227854532/agent-harness/games/resonance-circuit/presentation-unit.log) |
| 기존 Cloud Chromium 화면 검사 | 360×640, 360×800, 390×844, 1280×900 × 일반/축소 모션 8조합 PASS | [presentation-layout.log](https://github.com/mjcj222-glitch/claude-workspace/blob/1c5e273237c1c89e25f2b52045fbb3c227854532/agent-harness/games/resonance-circuit/presentation-layout.log) |
| 기존 Cloud Chromium 연습·탐험 | 연습 3전투 2조합, 탐험 6조합, 추가 360×640 탐험 완주 PASS | [연습](https://github.com/mjcj222-glitch/claude-workspace/blob/1c5e273237c1c89e25f2b52045fbb3c227854532/agent-harness/games/resonance-circuit/presentation-campaign.log), [탐험](https://github.com/mjcj222-glitch/claude-workspace/blob/1c5e273237c1c89e25f2b52045fbb3c227854532/agent-harness/games/resonance-circuit/presentation-expedition.log), [짧은 화면 추가 검수](https://github.com/mjcj222-glitch/claude-workspace/blob/1c5e273237c1c89e25f2b52045fbb3c227854532/agent-harness/games/resonance-circuit/presentation-short-run.log) |

상세 구현·실패 후 수정·검수 한계는 해당 head의 [PRESENTATION-REPORT.md](https://github.com/mjcj222-glitch/claude-workspace/blob/1c5e273237c1c89e25f2b52045fbb3c227854532/agent-harness/games/resonance-circuit/PRESENTATION-REPORT.md)에 기록돼 있다. 이 문서의 이전 기준 head와 새 head CI 확인 전 문구는 작성 시점의 상태이며, 이번 보고서가 위 run의 최종 success를 보완한다.

### 개발 필요성 판단과 미실행 항목

- 연구 상태 확인과 공개 보고서 작성에는 코드 변경이 필요하지 않아 새 개발 작업을 만들지 않았다.
- harness/Python/게임/브라우저 테스트 재실행은 하지 않았다. 새 아트의 통합·패키징·시각 검수도 수행하지 않았다.
- 실물 모바일, Safari/Firefox, 스크린리더, `file://` 직접 실행, 사람의 재미·난이도 평가는 여전히 미검증이다. 관리형 Chromium 내부 응답 검수는 이 항목들을 대신하지 않는다.
- 기존 CI 로그의 checkout 동작은 Node.js 20 대상 action을 Node.js 24로 실행한다는 경고를 남겼으나 이번 run은 성공했다. 워크플로 변경은 하지 않았다.

## 4. 비용·보안·승인 대기

- 이번 검토에서 별도 API 호출용 키, 유료 서버, 추가 크레딧 구매, 자동 충전, 계정·권한 변경을 사용하거나 실행하지 않았다.
- 계정 청구 내역은 확인하지 않았으므로 전체 운영 비용 0원을 실증했다고 표현하지 않는다. 일반 API 키를 쓰는 사용량은 별도 API 가격 체계이므로 이 연구의 대체 실행 수단으로 도입하지 않았다.
- 공개 보고서는 공개 프로젝트 증거와 필요한 진행 상태만 포함한다. 비밀번호·토큰·쿠키·개인 기기 정보·비공개 작업 링크·참고 이미지 원본은 게시하지 않는다.
- 이번 변경 범위는 `agent-harness/reports/2026-10-20/harness-bootstrap.md` 새 파일 1개다. 기존 파일·운영 코드 수정, PR 병합, 배포는 범위 밖이다.
- 새 아트 통합과 그 이후 코드 변경은 해당 작업의 승인 상태를 확인한 뒤 이어갈 사항이며, 이번 연구 보고가 그 승인을 대신하지 않는다.

## 5. 남은 질문과 다음 점검 — 최대 3개

1. **PC OFF 실증:** 사용자가 실제 전원 OFF 기간을 확인할 수 있을 때, 다음 예약 호출·보고서 저장·전달 시각과 대조할 수 있는가? 전원 상태 증거가 없으면 계속 미확인으로 둔다.
2. **반복 연구의 완료 증거:** 다음 회차에도 중복 파일을 먼저 확인하고 새 보고서 생성 후 재조회까지 이어지는가? 현재 일정 상태·실행 성공·저장 성공·사용자 전달을 각각 구분한다.
3. **게임 후속 작업의 기준:** 새 아트가 실제 반영된 새 head가 생기면 그 커밋에서 108개 회귀 검사·모바일 가독성·축소 모션·독립 HTML/ZIP 재패키징 결과를 다시 확인할 수 있는가? 기존 head의 통과 결과를 새 아트 결과로 재사용하지 않는다.
