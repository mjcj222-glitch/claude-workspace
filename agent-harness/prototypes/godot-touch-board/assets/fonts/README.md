# Original bundled fonts

These files are unmodified original font binaries, bundled only for this prototype. They are not installed system-wide and are not subsets or conversions.

| Intended role | File | Published source/version |
| --- | --- | --- |
| Display titles (`font_display`) | `BlackHanSans-Regular.ttf` | Google Fonts official `ofl/blackhansans`; internal Version 1.001 |
| Body (`font`) | `Pretendard-Medium.otf` | Official Pretendard 1.3.9 release; internal Version 1.309 |
| Emphasis (`font_bold`) | `Pretendard-SemiBold.otf` | Same official release |

Black Han Sans font and complete OFL text were downloaded from the explicitly approved Google Fonts raw GitHub paths. Pretendard binaries and the complete `LICENSE.txt` were extracted unchanged from the explicitly approved official GitHub release archive. `SOURCES.json` records exact URLs, archive members, internal font names/version, copyright, byte lengths, SHA-256 and retrieval time. `SHA256SUMS` covers all three binaries and both full license files; the release ZIP checksum is retained in the manifest. The large ZIP remains outside the repository because the required original binaries and complete license are bundled here.

- Black Han Sans full license: `BlackHanSans-OFL.txt` (SIL OFL 1.1).
- Pretendard full license and reserved name notice: `Pretendard-LICENSE.txt` (SIL OFL 1.1; Reserved Font Name Pretendard).
- No DNF font, external font CDN or alternate download route was used. Both approved official downloads succeeded without permission escalation.

## Godot validation

`tests/test_quality_fonts.gd` verifies actual FontFile import, binary magic, glyph data, source/version records, exact original checksums, required Korean glyphs and critical 22px text widths against a 628px budget. Evidence: `evidence/quality/fonts-red.log`, `fonts-import.log`, `fonts-green.log`. Initial missing-file checks failed 3/3; after adding/importing the assets all39 checks passed.

At22px the critical text samples measured at most434px in Pretendard Medium and433px in SemiBold. Pretendard ascent21/descent6 gives a27px font line box, so a24px baseline interval needs actual rendering review for vertical overlap. Black Han Sans is intended for Korean display titles; use Pretendard for UI text/symbols. These headless metrics validate font loading and nominal layout, not subjective small-device readability or the final UI's clipping. Main/UI loading is deliberately owned by the coordinator and was not changed in this font task.
