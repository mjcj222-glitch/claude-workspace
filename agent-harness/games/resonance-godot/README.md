# 잔향 회로 · Godot 전투 프로토타입

**현재 상태: 환경 확인과 설계 체크포인트. 아직 플레이 가능한 전투나 APK가 아니다.** 웹판은 보존하고 이 폴더에서 Godot 전투 한 화면을 별도로 구현한다.

- [최소 전투 설계](DESIGN.md)
- [캐릭터/효과 제작 사양](ART-CONTRACT.md)
- [실제 환경 검사](ENVIRONMENT.md)

설치된 Godot 4.6.3으로 실행한 물리 환경 검사는 다음과 같다.

```sh
cd agent-harness/games/resonance-godot
godot --headless --script tools/environment_probe.gd
```

쓰기가 제한된 환경에서는 Godot의 프로세스별 XDG 데이터/캐시 경로를 쓰기 가능한 임시 폴더로 지정했다. 계정·보안·네트워크 설정은 변경하지 않았다. 추가 결제·main 병합·배포는 하지 않는다.
