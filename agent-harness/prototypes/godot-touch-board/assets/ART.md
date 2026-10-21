# Original panel atlas

`pigment-atlas.png` is the newly generated, user-approved original atlas for this prototype. It is stored unchanged (1254 × 1254 RGBA). No old game asset or user reference image is included. Hero and target now use the supplied original PNGs described below; previous vector placeholders were replaced.

Godot draws source regions directly; it does not stretch a grid cell with a large transparent margin. The alpha ≥ 220 body bounds below are mapped to the physical circle diameter. The small translucent fringe is decorative. Contact graph and hit testing still use panel position and radius, never image alpha or glyph bounds. Source x/y/width/height:

| Element | Source region | Relative opaque body bounds |
|---|---|---|
| Red / flame | 37,36,360,360 | 5,5,350,350 |
| Green / leaf | 446,35,360,360 | 4,5,352,350 |
| Yellow / bolt | 854,36,361,359 | 5,4,351,351 |
| Blue / drop | 36,438,368,369 | 5,4,358,361 |
| Heart | 446,438,366,369 | 4,4,357,361 |
| Core | 855,438,368,369 | 5,4,358,361 |
| Strong core | 36,827,384,382 | 5,4,375,374 |

A core's attribute is communicated by a colored inset collar and an element glyph badge, in addition to the purple/rainbow special art. Direct selection uses a continuous white inset ring, chain uses broken gold arcs, and conversion uses moving mint arcs. Ring radii and stroke widths stay within the collision envelope at normal play size.

Actual-render check: Godot 4.6.3 Compatibility / OpenGL on llvmpipe; art preview 15 variants and real board screenshots visually inspected. This does not establish performance or legibility on a physical phone.

## Original character and passive target — quality pass

Both original files are stored unchanged as 1254×1254 RGBA PNGs, supplied and approved by the parent for this public prototype. They were materialized in this execution environment and visually inspected. No user reference file was included.

- `alchemist-portrait-v1.png`: face-led source region `(130,0,780,672)` shown inside a framed130×112 logical-pixel portrait. The intentional portrait crop does not pretend to show the full supplied bust. The skill highlights this frame; no extra character was generated.
- `training-jelly-golem-v1.png`: transparent-margin crop `(68,136,1131,974)` shown at approximately193×166 logical pixels with preserved aspect. Hit response is a small offset, tint and sparks, not an attack pattern.
- At360-pixel window width the portrait is65×56 and target approximately96×83 displayed pixels. Four skill colors have60×44-pixel targets. At390 width they scale proportionally. Small-window OS captures and pointer checks are under `evidence/polish/`.
- Mipmaps and linear mipmap filtering improve minification; originals were not repainted or destructively resized.
