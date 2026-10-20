# 잔향 회로 · Godot 전투 프로토타입

**현재 상태: 플레이 가능한 Godot 한 전투 프로토타입, Draft PR. 캐릭터 파일 전송 차단 해결을 우선하며 아트 통합은 미완료다.** 웹판은 보존했다. APK나 최종 게임이 아니다.

Godot 4.6.3에서 `project.godot`을 열고 F6/F5로 실행하거나 다음 명령을 사용한다.

```sh
godot --path agent-harness/games/resonance-godot
```

기물을 누르면 실제 제거 예정 범위와 피해/회복을 보여 주고, 같은 위치에서 떼면 확정한다. 드래그·취소·다중 입력은 정산하지 않는다. 방향키로 선택하고 Enter/Space로 확정할 수 있다. 세 스킬은 탭을 쓰지 않으며 첫 턴부터 사용 가능하다. 3번 선택 후 회복·공격·적 반격을 정산한다. 8개 직접 연결은 대형 폭탄을 남긴다. 과충전은 게이지55 이상이고 턴 첫 선택 전에 사용할 수 있다. 기본 무음이며 움직임 줄이기를 지원한다.

저장은 Godot `user://resonance_godot_v1.json`에 별도로 기록한다. 웹 저장 호환을 제공하지 않으며 `-- --no-save`로 저장 없이 실행할 수 있다.

- [현재 검증 및 남은 한계](VALIDATION.md)
- [전송 차단 진단과 최소 다음 작업](TRANSFER-DIAGNOSIS.md)
- [실제 네이티브 첫 턴 영상](evidence/godot-battle.mp4)

- [최소 전투 설계](DESIGN.md)
- [캐릭터/효과 제작 사양](ART-CONTRACT.md)
- [실제 환경 검사](ENVIRONMENT.md)

자동 검사는 다음과 같다.

```sh
cd agent-harness/games/resonance-godot
godot --headless --script tools/environment_probe.gd
godot --headless --fixed-fps 120 --script tests/rules_test.gd -- --no-save
godot --headless --fixed-fps 120 --script tests/battle_test.gd -- --no-save
godot --headless --fixed-fps 120 --script tests/full_battle.gd -- --no-save
```

쓰기가 제한된 환경에서는 Godot의 프로세스별 XDG 데이터/캐시 경로를 쓰기 가능한 임시 폴더로 지정했다. 계정·보안·네트워크 설정은 변경하지 않았다. 추가 결제·main 병합·배포는 하지 않는다.
