# Original relic icons

Three original hand-authored SVG illustrations, created directly in this workspace
for the approved Chroma presentation pass. No external image, user reference,
old game asset, or generated image was traced or incorporated.

- `pigment.svg`: green pigment bottle with brass cap and droplet seal.
- `lens.svg`: gold-framed blue lens with dark diagonal handle and focused ray.
- `ash.svg`: faceted gray crystal, warm ember and gold mounting claws.

All source canvases are 320×320 with transparent backgrounds. The consistent
brass highlights, dark outlines and broad silhouettes are intended for96 logical
pixel reward icons and72 logical pixel owned icons (48/36 physical pixels at
360-wide rendering). Scale down with linear filtering; do not add a circular
mask that removes the bottle neck, lens handle or crystal tips.

License: CC0-1.0; see `LICENSE.txt`. Public redistribution and modification are
permitted. Attribution is optional; suggested credit: “Chroma original relic
icons.” This license is specific to these SVG files.

Modification record:
- 2026-10-21: original SVG geometry, gradients, facets and highlights authored.
- 2026-10-21: Godot draw helper added with source-SVG loading before import,
  imported-resource fallback for exported builds, and a cached texture per icon.

The helper adds only an optional rounded highlight behind the icon; no rules,
input handling, character art, sound or reward state is contained here.
