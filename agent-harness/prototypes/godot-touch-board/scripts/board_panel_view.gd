extends RefCounted
## Shared presentation envelope and visible-owner hit order.
static func visual_radius(panel: Dictionary) -> float:
 return float(panel.get("radius",37.0))
static func draw_order(panels: Array) -> Array:
 var ordered: Array = panels.duplicate()
 ordered.sort_custom(func(a,b):
  if (a.kind == "big_bomb") != (b.kind == "big_bomb"): return a.kind == "big_bomb"
  return int(a.id) < int(b.id))
 return ordered
static func hit_test(panels: Array, point: Vector2) -> int:
 # Front ordinary bodies retain nearest-body ownership; both bomb casings
 # match their physical envelopes so colored contacts have no hidden padding.
 var nearest := INF
 var front := -1
 var large := -1
 for panel in panels:
  var distance: float = point.distance_to(panel.pos)
  if distance > visual_radius(panel): continue
  if panel.kind == "big_bomb": large = maxi(large, int(panel.id))
  elif distance < nearest:
   nearest = distance
   front = int(panel.id)
 return front if front >= 0 else large
