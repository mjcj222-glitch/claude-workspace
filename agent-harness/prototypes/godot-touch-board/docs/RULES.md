# Snapshot rule decisions

New implementation; no old game sources/assets consulted or copied.

- API: `contact_graph(panels, tolerance=1.5)`, `plan(panels,start_id,hp,max_hp)`, `skill_plan(panels,start_id,target_color)` are static pure functions in `scripts/board_rules.gd`. Panel IDs must be unique. Invalid ID/duplicate IDs produce invalid plans. Caller owns input locks, action/turn counters, HP application, skill charge, spawn ID allocation and one refill after execution.
- Geometry: center distance <= radius sum + 1.5 logical pixels. Physics/rendering integration must keep the tiny tolerance visually honest; no destination/future coordinates are read.
- Direct grouping includes same-color existing cores and normals. Hearts group only with hearts. A normal needs a connected group of at least two; a core may activate alone. Only direct normal count produces a core (6..11 normal, 12+ strong).
- Frozen contact edges persist for the whole plan, including already removed positions as connectivity anchors. These positions are never recolored or credited twice. There is no refill or newly spawned ID in this graph.
- Pending specials are processed by shortest graph distance from initial touched panel, then ascending ID. Each is activated once. Radius uses the complete contact graph: hearts cannot convert/clear from a core, but can be intermediate geometric nodes in a radius-two neighborhood. This differs deliberately from the skill, whose targets AND paths exclude hearts/specials as explicitly requested.
- First processed core claims each not-yet-removed normal in its radius, including normals already of its color. Later cores cannot overwrite that claim. Existing specials retain their own colors. A converted normal not connected to that core's color can survive. Cost of this tie-break: simultaneous competing paint may look less intuitive; preview must expose the exact final conversion and removal set.
- `converted` in clear plans reports actual color changes; in skill plans it reports all selected targets, even ones already of the selected color. `removed` and `sequence` are unique and sorted by start distance then ID. `activated` is actual ordered activation; `direct` is original snapshot group. Damage is one per removed normal only; specials do not add damage. Heart heal is two with effective/overflow split.
- Spawn description contains position/color/kind only, not ID. Created after all old specials and direct clear; it cannot appear in removed/activated arrays. Refill cannot auto-clear because rules only act on an explicit start ID.
- Skill targets at most four reachable normals, shortest normal-only graph distance then ID. `connected` predicts the full resulting same-color component (may include an existing same-color core), but performs no activation/removal or action consumption.

## TDD evidence
`tests/test_rules.gd`: 44 checks. Initial callable no-op implementation: 27 expected failures (`evidence/rules-red.log`). First implemented run exposed one fixture bug: a supposed overlap was actually separated by a different-color core. Corrected the fixture to a geometric triangle to exercise competing cores on the same connected normal; production logic unchanged. Final run: 44 checks / 0 failures (`evidence/rules-green.log`).

Run: `XDG_DATA_HOME=/tmp/chroma-data XDG_CONFIG_HOME=/tmp/chroma-config XDG_CACHE_HOME=/tmp/chroma-cache godot --headless --path . --script tests/test_rules.gd`.
