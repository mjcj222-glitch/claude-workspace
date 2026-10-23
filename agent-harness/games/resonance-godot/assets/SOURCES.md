# 자산 출처

기존 배경·적 이미지는 독자 웹판 `feat/resonance-circuit`의 로컬 파일을 복사했다. 2026-10-20 로컬 통합에서 아래 주인공 원본 3장과 Kenney CC0 텍스처 6개를 추가했다. 참고 게임의 자산을 복제하지 않았다.

| 이 폴더 | 기존 프로젝트 원본 | SHA-256 |
|---|---|---|
| background.webp | resonance-circuit/assets/storybook-battle.webp | 069241d0806ebd4cff3e4b0751ee3c7b12a1250e8d647c50c961ad54bc3e4843 |
| enemy-sheet.png | resonance-circuit/assets/enemy-foreground-sheet.png | f30890993fad04445bd381b10dc6f1d5ba07cda224a512683ac8c59eba6cf3b7 |
| portraits.webp | resonance-circuit/assets/portraits-cute.webp | 2b185439928ab1e53f268a74a21387ec765fbd01a67774e411f3092fdd2c88ac |

`portraits.webp`는 보존용으로 복사했으나 현재 장면에는 사용하지 않는다.

`NotoSansCJK-Regular.ttc`는 실행 환경에 이미 설치된 `/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc`를 복사했다. SHA-256은 `b76b0433203017ca80401b2ee0dd69350349871c4b19d504c34dbdd80541690a`다. 배포 패키지의 저작권 및 SIL Open Font License는 함께 제공한 `Noto-COPYRIGHT.txt`를 따른다. 폰트를 수정하지 않았다.

## 새 주인공 원본

`heroine/`의 1254×1254 RGBA PNG 세 장은 프로젝트 소유자가 제공하고 공개 저장을 승인한 원본이다.
원본 픽셀을 변경하지 않고 로컬로 복사했다. 원본의 alpha 1~3 및 반투명
픽셀도 보존했다. Godot Sprite2D의 크기와 오프셋으로 발 접점만 정렬한다.

이 이미지를 CC0로 재분류하지 않는다. 원본 SHA-256과 로컬 경로는
`integration-sources.json`에 보존했다.

## Kenney Particle Pack 1.1

- 제작자: Kenney Vleugels / Kenney.nl
- 공식 페이지: https://kenney.nl/assets/particle-pack
- 공식 배포본: https://kenney.nl/media/pages/assets/particle-pack/f8fe0f8cb8-1677578741/kenney_particle-pack.zip
- 다운로드 검증일: 2026-10-20 UTC
- ZIP SHA-256: `b631d4b07f7002549fdcf155f01141ad482f79f3440e4e301eed49ce5f1d8958`
- 라이선스: 배포본 동봉 CC0 원문을 `kenney-particles/License.txt`에 바이트 그대로 보존.
- 사용 파일: `PNG (Transparent)/`의 light_01, star_01, circle_03,
  spark_01, slash_02, magic_01 PNG. 각각 예고·소거·큰폭탄 링·파열·피격·스킬.
- PNG 원본 크기는 512×512. 파일 자체를 편집하지 않고 엔진에서 축소·색조 적용.
- 결제·계정 생성 없음.

기물의 베벨·상단 음영·사선 광택·특수 심벌은 Godot draw 코드로 생성했다.
판정 폴리곤은 기존 기하와 동일하다. 비교용 참고 이미지 두 장은 이번 개발
환경에서 직접 수신하지 못했으며 프로젝트에 포함하지 않았다.
