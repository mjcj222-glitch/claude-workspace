# 실제 환경 확인 · 2026-10-20 UTC

## 확인 결과

| 항목 | 실제 확인 |
|---|---|
| 엔진 | `/usr/local/bin/godot`, `/usr/local/bin/godot4`; **4.6.3.stable.official.7d41c59c4**, `/opt/godot/4.6.3/`에 기존 설치 |
| headless | GDScript를 실행해 오목 별 `CollisionPolygon2D`를 가진 `RigidBody2D`를 300 physics tick 동안 낙하시킴. y50→366.029, 최종 속도 약0, sleeping=true, **종료0** |
| GUI | X11/Compatibility 실제 실행 **종료1**. X11 display 없음, Wayland 초기화도 실패. DISPLAY/화면 소켓/Xvfb 없음. 정책 거부가 아니라 실행 환경에 화면 서버가 없는 상태 |
| 템플릿 | 통상 경로에 설치된 export template 없음. Godot가 임시 XDG 폴더에 만든 `export_templates` 디렉터리는 비어 있음 |
| Java | OpenJDK21 실행 환경 있음. `javac` 없음. JDK17 개발 도구 설치 미확인/미설치 |
| Android | `adb`, `sdkmanager`, `gradle`, ANDROID_HOME/ANDROID_SDK_ROOT 없음. Android SDK·기기·빌드 검증 없음 |
| 다운로드/설치 | 엔진이 이미 있어 이번 확인 중 설치·다운로드를 하지 않음 |

로그: `evidence/environment-headless.log`, `evidence/environment-gui.log`, `evidence/environment-inventory.json`. 버전 조회 시 Fontconfig의 쓰기 가능한 캐시 경로 경고가 있었다. 실행 probe는 프로세스별 XDG_DATA_HOME/XDG_CONFIG_HOME/XDG_CACHE_HOME을 `/tmp/resonance-godot-*`로 지정해 수행했다. 기존 HOME이나 시스템 보안 설정은 변경하지 않았다.

headless 성공은 GDScript와 엔진의 2D 충돌 실행 가능성을 뜻한다. 42기물의 자연스러운 쌓임, 실제 화면·입력, GPU 파티클, 프레임 속도, 모바일 품질은 아직 검증하지 않았다. 직접 GUI 영상은 현재 환경에서 미실행 상태이며, 그 상태에서 영상이나 APK를 약속하지 않는다. 이후 공식 export template을 활용한 브라우저 검수 경로 등은 별도 확인 후 진행한다.

## 기술 근거

2026-10-20 열람. [Godot CollisionPolygon2D 공식 문서](https://docs.godotengine.org/en/stable/classes/class_collisionpolygon2d.html)는 solids 모드에서 오목/볼록 폴리곤을 볼록 분해한 충돌체로 사용할 수 있다고 설명한다. 공통 폴리곤을 표시와 충돌 양쪽에 사용한다는 설계 근거이며, 아직 전투 보드 구현이 완료됐다는 뜻은 아니다.

[Android 내보내기 공식 문서](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_android.html)는 JDK17을 권장하고 Android SDK/빌드 도구의 설정을 요구한다. 더 높은 JDK도 지원하지만 현재는 개발 도구 및 SDK 자체가 없어 APK를 만들었다고 할 수 없다. 서명·배포·실기기 검증은 수행하지 않았다.

부모가 확인해 전달한 무료 VFX 후보는 Kenney Particle Pack, Splat Pack, Smoke Particles(CC0)다. 아직 다운로드·라이선스 파일 수령·효과 구현은 하지 않았다. 실제 사용할 소수 자산만 원문/라이선스를 확인해 프로젝트 안에 기록할 예정이다.

## 안전한 보존

웹판 코드·ZIP·기존 저장은 변경하지 않았다. 진단만 웹 브랜치의 `154a0a8`에 추가해 PR2로 보존했다. 새 프로젝트는 main `e2ebeb9` 기반 별도 `feat/resonance-godot`, 별도 worktree `/workspace/resonance-godot`이다. 현재 변경은 새 게임 폴더 안에만 있다.
