# 자산 출처

이미지는 기존 독자 웹판 `feat/resonance-circuit`의 로컬 파일을 복사했다. 이번 Godot 작업에서 외부 이미지나 원작 게임 자산을 다운로드하지 않았다.

| 이 폴더 | 기존 프로젝트 원본 | SHA-256 |
|---|---|---|
| background.webp | resonance-circuit/assets/storybook-battle.webp | 069241d0806ebd4cff3e4b0751ee3c7b12a1250e8d647c50c961ad54bc3e4843 |
| enemy-sheet.png | resonance-circuit/assets/enemy-foreground-sheet.png | f30890993fad04445bd381b10dc6f1d5ba07cda224a512683ac8c59eba6cf3b7 |
| portraits.webp | resonance-circuit/assets/portraits-cute.webp | 2b185439928ab1e53f268a74a21387ec765fbd01a67774e411f3092fdd2c88ac |

`portraits.webp`는 보존용으로 복사했으나 현재 장면에는 사용하지 않는다. 새 주인공 전신·공격 프레임은 미수신 상태다.

`NotoSansCJK-Regular.ttc`는 실행 환경에 이미 설치된 `/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc`를 복사했다. SHA-256은 `b76b0433203017ca80401b2ee0dd69350349871c4b19d504c34dbdd80541690a`다. 배포 패키지의 저작권 및 SIL Open Font License는 함께 제공한 `Noto-COPYRIGHT.txt`를 따른다. 폰트를 수정하지 않았다.

Kenney VFX는 연결 차단으로 수신하지 않아 이 프로젝트에 포함돼 있지 않다. 기물과 입자 텍스처·링은 코드에서 직접 생성한다.
