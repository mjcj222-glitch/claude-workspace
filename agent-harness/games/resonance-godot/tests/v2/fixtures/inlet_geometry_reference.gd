extends RefCounted
## Finite translation geometry. Coordinates inherit Godot's float32 polygons;
## scalar envelope arithmetic is float64 and every returned birth is rechecked
## against the original actual hulls. No grid or predicted resting bodies.
const Geometry = preload("res://scripts/v2/geometry.gd")
static var _parts_cache: Dictionary = {}

static func _ccw(poly: PackedVector2Array) -> PackedVector2Array:
    var out := poly.duplicate()
    var signed_area := 0.0
    for i in range(out.size()): signed_area += out[i].cross(out[(i+1)%out.size()])
    if signed_area < 0: out.reverse()
    var first := 0
    for i in range(1,out.size()):
        if out[i].y < out[first].y or (out[i].y == out[first].y and out[i].x < out[first].x): first = i
    var ordered := PackedVector2Array()
    for i in range(out.size()): ordered.append(out[(first+i)%out.size()])
    return ordered

static func _parts(poly: PackedVector2Array) -> Array:
    var result: Array = []
    for part in Geometry2D.decompose_polygon_in_convex(_ccw(poly)):
        result.append(_ccw(part))
    return result

static func _sum(a: PackedVector2Array,b: PackedVector2Array) -> PackedVector2Array:
    # Both inputs convex/CCW, starting at their lowest-y then lowest-x vertex.
    # Merge the ordered edge directions; never convexify a concave whole hull.
    var result := PackedVector2Array()
    var i := 0
    var j := 0
    while i < a.size() or j < b.size():
        var point := a[i%a.size()]+b[j%b.size()]
        if result.is_empty() or result[-1] != point: result.append(point)
        if i == a.size(): j += 1; continue
        if j == b.size(): i += 1; continue
        var ea := a[(i+1)%a.size()]-a[i%a.size()]
        var eb := b[(j+1)%b.size()]-b[j%b.size()]
        var cross := ea.cross(eb)
        if cross >= 0: i += 1
        if cross <= 0: j += 1
    return _ccw(result)

static func _slice(poly: PackedVector2Array,y: float) -> Array:
    var low := INF
    var high := -INF
    for i in range(poly.size()):
        var a := poly[i]
        var b := poly[(i+1)%poly.size()]
        if a.y == y: low = minf(low,a.x); high = maxf(high,a.x)
        if (a.y < y and b.y > y) or (a.y > y and b.y < y):
            var x := float(a.x)+(y-float(a.y))*(float(b.x)-a.x)/(float(b.y)-a.y)
            low = minf(low,x); high = maxf(high,x)
    return [] if low == INF else [low,high]

static func _below(poly: PackedVector2Array,y: float) -> PackedVector2Array:
    # Clip to the downward ray half-plane; all obstacles above birth are ignored.
    var out := PackedVector2Array()
    for i in range(poly.size()):
        var a := poly[i]
        var b := poly[(i+1)%poly.size()]
        if a.y >= y: out.append(a)
        if (a.y < y and b.y > y) or (a.y > y and b.y < y):
            out.append(Vector2(float(a.x)+(y-float(a.y))*(float(b.x)-a.x)/(float(b.y)-a.y),y))
    return out

static func _line(x0: float,x1: float,y0: float,y1: float) -> Dictionary:
    var slope := (y1-y0)/(x1-x0)
    return {"x0":x0,"x1":x1,"y0":y0,"y1":y1,"slope":slope,"offset":y0-slope*x0}
static func _value(line: Dictionary,x: float) -> float:
    return line.slope*x+line.offset
static func _cut(line: Dictionary,lo: float,hi: float) -> Dictionary:
    var out := {"x0":lo,"x1":hi,"y0":_value(line,lo),"y1":_value(line,hi),"slope":line.slope,"offset":line.offset}
    if line.has("geometric_ymax"): out.geometric_ymax = line.geometric_ymax
    return out
static func _emit(lines: Array,line: Dictionary,lo: float,hi: float) -> void:
    if not lines.is_empty() and lines[-1].x1 == lo and lines[-1].slope == line.slope and lines[-1].offset == line.offset:
        lines[-1].x1 = hi
        lines[-1].y1 = _value(line,hi)
        if line.has("geometric_ymax"): lines[-1].geometric_ymax = maxf(lines[-1].get("geometric_ymax",line.geometric_ymax),line.geometric_ymax)
    else: lines.append(_cut(line,lo,hi))
static func _at(lines: Array,x: float) -> Dictionary:
    var low := 0
    var high := lines.size()
    while low < high:
        var mid := (low+high)/2
        if lines[mid].x0 <= x: low = mid+1
        else: high = mid
    var best := {}
    var index := low-1
    if index >= 0 and lines[index].x0 <= x and lines[index].x1 >= x: best = lines[index]
    index -= 1
    if index >= 0 and lines[index].x0 <= x and lines[index].x1 >= x:
        if best.is_empty() or _value(lines[index],x) < _value(best,x): best = lines[index]
    return best
static func _depth(lines: Array,x: float,points: Dictionary = {}) -> float:
    var line := _at(lines,x)
    return minf(INF if line.is_empty() else _value(line,x),points.get(x,INF))
static func _events(values: Array) -> Array:
    values.sort()
    var result: Array = []
    for x in values:
        if result.is_empty() or x != result[-1]: result.append(x)
    return result

static func _merge(a: Array,b: Array,work: Dictionary = {}) -> Array:
    # Ordered endpoint streams, monotone active branches, original arithmetic.
    var ea := 0
    var eb := 0
    var ia := 0
    var ib := 0
    var lo := INF
    var result: Array = []
    var cells := 0
    var emissions := 0
    while ea < a.size()*2 or eb < b.size()*2:
        var xa: float = (a[ea/2].x0 if ea%2 == 0 else a[ea/2].x1) if ea < a.size()*2 else INF
        var xb: float = (b[eb/2].x0 if eb%2 == 0 else b[eb/2].x1) if eb < b.size()*2 else INF
        var hi := minf(xa,xb)
        while ea < a.size()*2 and (a[ea/2].x0 if ea%2 == 0 else a[ea/2].x1) == hi: ea += 1
        while eb < b.size()*2 and (b[eb/2].x0 if eb%2 == 0 else b[eb/2].x1) == hi: eb += 1
        if lo == INF: lo = hi; continue
        if hi <= lo: continue
        while ia < a.size() and a[ia].x1 <= lo: ia += 1
        while ib < b.size() and b[ib].x1 <= lo: ib += 1
        var left: Dictionary = a[ia] if ia < a.size() and a[ia].x0 <= lo and a[ia].x1 >= hi else {}
        var right: Dictionary = b[ib] if ib < b.size() and b[ib].x0 <= lo and b[ib].x1 >= hi else {}
        var middle := (lo+hi)/2
        if middle == lo or middle == hi:
            left = _at(a,middle)
            right = _at(b,middle)
        cells += 1
        if left.is_empty() and right.is_empty(): lo = hi; continue
        if left.is_empty(): _emit(result,right,lo,hi); emissions += 1; lo = hi; continue
        if right.is_empty(): _emit(result,left,lo,hi); emissions += 1; lo = hi; continue
        var d0 := _value(left,lo)-_value(right,lo)
        var d1 := _value(left,hi)-_value(right,hi)
        if (d0 < 0 and d1 > 0) or (d0 > 0 and d1 < 0):
            var cross := lo+(hi-lo)*d0/(d0-d1)
            var first: Dictionary = left if d0 < 0 else right
            var last: Dictionary = right if d0 < 0 else left
            _emit(result,first,lo,cross)
            _emit(result,last,cross,hi)
            emissions += 2
        else:
            var best: Dictionary = left if d0+d1 <= 0 else right
            _emit(result,best,lo,hi)
            emissions += 1
        lo = hi
    work["merge_cells"] = work.get("merge_cells",0)+cells
    work["merge_emissions"] = work.get("merge_emissions",0)+emissions
    work["merge_input_segments"] = work.get("merge_input_segments",0)+a.size()+b.size()
    return result

static func _bounds(poly: PackedVector2Array) -> Array:
    var out: Array = [INF,INF,-INF,-INF]
    for p in poly:
        out[0] = minf(out[0],p.x); out[1] = minf(out[1],p.y)
        out[2] = maxf(out[2],p.x); out[3] = maxf(out[3],p.y)
    return out
static func _cached(poly: PackedVector2Array,next_cache: Dictionary,work: Dictionary) -> Array:
    var key: int = hash(poly)
    for entry in _parts_cache.get(key,[]):
        if entry.polygon == poly:
            if not next_cache.has(key): next_cache[key] = []
            if not next_cache[key].has(entry): next_cache[key].append(entry)
            work["decomposition_cache_hits"] = work.get("decomposition_cache_hits",0)+1
            return entry.parts
    var parts := _parts(poly)
    if not next_cache.has(key): next_cache[key] = []
    next_cache[key].append({"polygon":poly.duplicate(),"parts":parts})
    return parts
static func _covered_below(envelope: Array,lo: float,hi: float,lower: float) -> bool:
    # A deliberately loose REAL geometric certificate: each winning original
    # affine edge lies below its source-vertex maximum. No slope-rounding
    # comparison, center heuristic, or equality/epsilon pruning is used.
    var cursor := lo
    for line in envelope:
        if line.x1 < lo: continue
        if line.x0 > hi: break
        if line.x0 > cursor or not line.has("geometric_ymax") or line.geometric_ymax >= lower: return false
        cursor = maxf(cursor,line.x1)
    return cursor >= hi
static func _separated(a: Array,b: Array,margin: float) -> bool:
    return b[0]-a[2] > margin or a[0]-b[2] > margin or b[1]-a[3] > margin or a[1]-b[3] > margin

static func _open_union(spans: Array) -> Array:
    var ordered:=spans.duplicate()
    ordered.sort_custom(func(a,b):return a[0]<b[0] if a[0]!=b[0] else a[1]<b[1])
    var union: Array=[]
    for span in ordered:
        if span[0]>=span[1]:continue # zero-length OPEN interval has no interior
        if union.is_empty() or span[0]>=union[-1][1]:union.append(span.duplicate())
        else:union[-1][1]=maxf(union[-1][1],span[1])
    return union

static func choose(incoming: PackedVector2Array,obstacles: Array,sample_x: float,width: float,height: float,spawn_y: float,margin: float,audit: Dictionary = {}) -> Dictionary:
    var start := Time.get_ticks_usec()
    var min_x := INF
    var max_x := -INF
    var min_y := INF
    var max_y := -INF
    for p in incoming:
        min_x = minf(min_x,p.x); max_x = maxf(max_x,p.x)
        min_y = minf(min_y,p.y); max_y = maxf(max_y,p.y)
    var lo := margin-min_x
    var hi := width-margin-max_x
    var birth_y := minf(spawn_y,-max_y-margin)
    var floor_line := _line(lo,hi,height-max_y,height-max_y)
    floor_line.geometric_ymax = height-max_y
    var envelope: Array = [floor_line]
    var blocked: Array = []
    var opposite := PackedVector2Array()
    for p in incoming: opposite.append(-p)
    var work := {}
    var next_cache := {}
    var head_parts := _cached(opposite,next_cache,work)
    var square := PackedVector2Array([Vector2(-margin,-margin),Vector2(margin,-margin),Vector2(margin,margin),Vector2(-margin,margin)])
    var component_count := 0
    var input_segments := 1
    var point_hits := {}
    var depth_pruned := 0
    var slice_pruned := 0
    var constructed := 0
    var envelope_usec := 0
    var construction_begin := Time.get_ticks_usec()
    var ordered: Array = []
    for index in range(obstacles.size()): ordered.append({"polygon":obstacles[index],"bounds":_bounds(obstacles[index]),"index":index})
    ordered.sort_custom(func(a,b): return a.bounds[1] < b.bounds[1] if a.bounds[1] != b.bounds[1] else a.index < b.index)
    for obstacle in ordered:
        for part in _cached(obstacle.polygon,next_cache,work):
            var pb := _bounds(part)
            for head in head_parts:
                var hb := _bounds(head)
                # Same packed addition as Minkowski vertices, monotone in each
                # input coordinate. These extrema bound the constructed polygon.
                var lower := Vector2(0,pb[1])+Vector2(0,hb[1])
                var upper := Vector2(0,pb[3])+Vector2(0,hb[3])
                var left := Vector2(pb[0],0)+Vector2(hb[0],0)
                var right := Vector2(pb[2],0)+Vector2(hb[2],0)
                var expanded_low := lower+Vector2(0,-margin)
                var expanded_high := upper+Vector2(0,margin)
                var slice_empty := birth_y < expanded_low.y or birth_y > expanded_high.y
                var x0 := maxf(lo,left.x)
                var x1 := minf(hi,right.x)
                component_count += 1
                # Strictly below birth, no occupancy slice, positive domain:
                # no isolated clip/wall point key can be lost by this prune.
                if slice_empty and lower.y > birth_y and x0 < x1 and _covered_below(envelope,x0,x1,lower.y):
                    depth_pruned += 1
                    slice_pruned += 1
                    continue
                var forbidden := _sum(part,head)
                constructed += 1
                if slice_empty: slice_pruned += 1
                else:
                    var span := _slice(_sum(forbidden,square),birth_y)
                    if not span.is_empty(): blocked.append(span)
                if upper.y < birth_y: continue
                var clipped := forbidden if lower.y >= birth_y else _below(forbidden,birth_y)
                var lines: Array = []
                for i in range(clipped.size()):
                    var a := clipped[i]
                    var b := clipped[(i+1)%clipped.size()]
                    if b.x <= a.x: continue
                    var xstart := maxf(lo,a.x)
                    var xend := minf(hi,b.x)
                    if xstart > xend: continue
                    var edge := _line(a.x,b.x,a.y,b.y)
                    edge.geometric_ymax = maxf(a.y,b.y)
                    if xstart == xend:
                        point_hits[xstart] = minf(point_hits.get(xstart,INF),_value(edge,xstart))
                        continue
                    lines.append(_cut(edge,xstart,xend))
                    input_segments += 1
                lines.sort_custom(func(a,b): return a.x0 < b.x0)
                if not lines.is_empty():
                    var merge_begin := Time.get_ticks_usec()
                    envelope = _merge(envelope,lines,work)
                    envelope_usec += Time.get_ticks_usec()-merge_begin
    var construction_usec := Time.get_ticks_usec()-construction_begin-envelope_usec
    _parts_cache = next_cache
    var candidate_begin := Time.get_ticks_usec()
    var union:=_open_union(blocked)
    var event_xs: Array = [lo,hi]
    for span in blocked:
        if span[0]==span[1]:event_xs.append(span[0])
    event_xs.append_array(point_hits.keys())
    for span in union: event_xs.append(clampf(span[0],lo,hi)); event_xs.append(clampf(span[1],lo,hi))
    for line in envelope:
        event_xs.append(line.x0); event_xs.append(line.x1)
        if line.y0 != line.y1:
            var x: float = line.x0+(-min_y-line.y0)*(line.x1-line.x0)/(line.y1-line.y0)
            if x > line.x0 and x < line.x1: event_xs.append(x)
    event_xs = _events(event_xs)
    var representatives: Array = event_xs.duplicate()
    for i in range(event_xs.size()-1):
        var x0: float = event_xs[i]
        var x1: float = event_xs[i+1]
        representatives.append((x0+x1)/2) # explicit open-cell convention
        if sample_x > x0 and sample_x < x1: representatives.append(sample_x)
        # Flat closed-cell optimum nearest the sampled x is its projection.
        if _depth(envelope,(x0+x1)/2,point_hits) == _depth(envelope,x0,point_hits) and _depth(envelope,x0,point_hits) == _depth(envelope,x1,point_hits): representatives.append(clampf(sample_x,x0,x1))
    var ranked: Array = []
    for x in _events(representatives):
        if x < lo or x > hi: continue
        var denied := false
        for span in union:
            if x > span[0] and x < span[1]: denied = true; break
        if denied: continue
        var depth := _depth(envelope,x,point_hits)
        if depth+min_y >= 0 and depth != INF: ranked.append({"x":x,"depth":depth})
    ranked.sort_custom(func(a,b):
        if a.depth != b.depth: return a.depth > b.depth
        if absf(a.x-sample_x) != absf(b.x-sample_x): return absf(a.x-sample_x) < absf(b.x-sample_x)
        return a.x < b.x)
    var candidate_usec := Time.get_ticks_usec()-candidate_begin
    var clearance_begin := Time.get_ticks_usec()
    var chosen := {}
    var clearance_pruned := 0
    var actual_distance_checks := 0
    for candidate in ranked:
        var center := Vector2(candidate.x,birth_y) # actual engine coordinate precision
        if center.x < lo or center.x > hi or center.y+max_y > -margin: continue
        if _depth(envelope,center.x,point_hits)+min_y < 0: continue
        var actual := Geometry.transformed(incoming,center,0)
        var clear := true
        var actual_bounds := _bounds(actual)
        for obstacle in ordered:
            if _separated(actual_bounds,obstacle.bounds,margin): clearance_pruned += 1; continue
            actual_distance_checks += 1
            if Geometry.distance(actual,obstacle.polygon) < margin: clear = false; break
        if clear:
            chosen = {"x":float(center.x),"y":float(center.y),"depth":_depth(envelope,center.x,point_hits)}
            break
    var cache_entries := 0
    for bucket in _parts_cache.values(): cache_entries += bucket.size()
    audit.merge(work,true)
    audit.merge({"components":component_count,"constructed_components":constructed,"depth_pruned":depth_pruned,"slice_pruned":slice_pruned,"clearance_pruned":clearance_pruned,"actual_distance_checks":actual_distance_checks,"decomposition_cache_entries":cache_entries,"input_segments":input_segments,"isolated_points":point_hits.size(),"construction_elapsed_usec":construction_usec,"envelope_elapsed_usec":envelope_usec,"candidate_elapsed_usec":candidate_usec,"actual_clearance_elapsed_usec":Time.get_ticks_usec()-clearance_begin,"envelope_segments":envelope.size(),"events":event_xs.size(),"representatives":representatives.size(),"candidates":ranked.size(),"elapsed_usec":Time.get_ticks_usec()-start},true)
    if audit.get("details",false):
        audit.merge({"envelope":envelope.duplicate(true),"blocked":union.duplicate(true),"point_hits":point_hits.duplicate(true),"event_xs":event_xs.duplicate(),"representative_xs":_events(representatives),"ranked":ranked.duplicate(true)},true)
    return chosen
