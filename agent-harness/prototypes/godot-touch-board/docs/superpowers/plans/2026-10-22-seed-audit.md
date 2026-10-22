# 다중 시드 탐험 감사 계획

Goal: cd1944f의 합법 입력 탐험에서 재현되는 진행/예고/미리보기 결함을 찾는다.
Architecture: 기존 play_lifecycle harness를 상속한 관찰 전용 감사. 프로덕션 상태를 주입하지 않으며 runtime 변경은 재현 결함이 있을 때만 한다.
Tech: Godot4.6.3, Python 표준 라이브러리. 승인된 기존 클라우드에서 순차 수행.
Spec: 사용자 요청 — 두 캐릭터, safe/risk/shop, varied boards, 정상 입력, 자동 정책과 결함 구분.

## 제약과 검토

- prototype만 변경. 기존 후보/게임 규칙/physics/art/audio 보존. draft PR3만 푸시.
- 실제 시드 1,42,314159,20261021 × rio/noa × safe/safe-shop/risk =24회. 통계 표본이 아닌 재현 가능한 의도적 범위.
- 경감 조건은 예고 시점 첫 안정 보드에서 모든 패널의 합법 소거를 열거한다. 이후 스킬/소거가 기회를 바꾸면 이를 불공정 예고로 오인하지 않는다.
- 빈 합법 수, stalled refill, 비정상 스킬 상태, route lock, preview/commit 및 HP 피해/회복 차이, 종료/restart를 실패 기준으로 삼는다.
- 경로별 도달 적/HP/공격수/경감기회 수를 기록. 패배는 결함이 아니며 다른 정책 대조는 의심 사례에 한정한다. 자동 정책은 즉시 피해와 경감을 선호하며 인간 전략/재미를 모델링하지 않는다.

## 작업

- [x] tests/audit_seeds.gd: 기존 실제 press/release driver 재사용. best_clear 관찰에서 turn intent와 실제 가능한 mitigation을 기록. gesture에서 예상 HP/적HP와 실제 정산 비교. 압축된 이벤트 출력, 원본 보드 주입 없음.
- [x] tests/run_seed_audit.py:24개 격리 save-dir, 각120초 제한, seed/hero/path/policy/outcome/criteria JSON·표 기록.
- [x] 오류는 원본 로그와 정확한 seed로 최소 재현 후에만 targeted regression과 수정. 결함이 없으면 runtime 무변경.
- [x] 보고서에 도달 범위/정책 한계/초기 실패/미검증을 명시. 검증된 문서·harness·증거만 커밋/푸시하고 exact HEAD와 하네스 CI 확인. runtime 무변경이면 새 ZIP 없음.

추가 범위: 기존 safe-shop 정책은 구매를 생략하므로 시드1/42 × 두 캐릭터의 4개 대조 실행에서 합법 구매를 수행한다. 24회 기본 표본과 별도 집계하며 runtime는 변경하지 않는다.

결과: runtime 결함 없음. 28회/463소거/186예고 보드 검증. 상세 SEED_AUDIT.md와 evidence/seed-audit/analysis.json. 결함 수정 단계는 조건 미충족으로 실행하지 않음.
