# Original panel atlas

`pigment-atlas.png` is the newly generated, user-approved original atlas for this prototype. It is stored unchanged (1254 × 1254 RGBA). No old game asset or user reference image is included. Hero and target are original immediate-mode vector drawings in `scripts/board_art.gd`.

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
