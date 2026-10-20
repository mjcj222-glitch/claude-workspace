extends Node2D
const Geometry = preload("res://scripts/v2/geometry.gd")
var direct_ids: Array = []
var extra_ids: Array = []
var direct_contours: Array = []
var extra_contours: Array = []
var direct_color := Color("d7fffa")
var extra_color := Color("ffbe69")
var blast_circles: Array = []
var bursts: Array = []
var burst_time := 0.0
var compression_time := -1.0
var compression_contours: Array = []
func show_selection(snapshot: Dictionary, plan: Dictionary) -> void:
    direct_ids = plan.get("direct_ids",[]).duplicate()
    extra_ids = plan.get("extra_ids",[]).duplicate()
    direct_contours = _contours(snapshot, direct_ids)
    extra_contours = _contours(snapshot, extra_ids)
    blast_circles = plan.get("blast_circles",[]).duplicate(true)
    queue_redraw()
func reset_transients() -> void:
    show_selection({}, {})
    compression_contours.clear()
    compression_time = -1.0
    bursts.clear()
    burst_time = 0.0
    queue_redraw()

func _contours(snapshot: Dictionary, ids: Array) -> Array:
    var contours: Array = []
    for piece in snapshot.get("pieces",[]):
        if not ids.has(int(piece.id)): continue
        var hull := Geometry.transformed(Geometry.polygon(int(piece.hull_id),float(piece.size)), Vector2(piece.x,piece.y),float(piece.angle))
        # Offset beyond the contact silhouette, then merge connected halos so
        # the group reads outside the finger without lines crossing its center.
        for expanded in Geometry2D.offset_polygon(hull,4.0,Geometry2D.JOIN_ROUND):
            contours.append(expanded)
    var merged := true
    while merged:
        merged = false
        for i in range(contours.size()):
            if merged: break
            for j in range(i+1,contours.size()):
                var union := Geometry2D.merge_polygons(contours[i],contours[j])
                if union.size() == 1:
                    contours[i] = union[0]
                    contours.remove_at(j)
                    merged = true
                    break
    return contours
func play_blast(circles: Array, reduced: bool = false) -> void:
    bursts = [] if reduced else circles.duplicate(true)
    burst_time = 0.0
    queue_redraw()
func play_compression(snapshot: Dictionary, plan: Dictionary, reduced: bool = false) -> void:
    compression_contours = [] if reduced else _contours(snapshot,plan.removed_ids)
    compression_time = -1.0 if reduced else 0.0
    queue_redraw()
func _process(delta: float) -> void:
    if compression_time >= 0:
        compression_time += delta
        if compression_time >= 0.12:
            compression_time = -1
            compression_contours.clear()
        queue_redraw()
    if bursts.is_empty(): return
    burst_time += delta
    if burst_time >= 0.4: bursts.clear()
    queue_redraw()
func _outline(contour: PackedVector2Array, color: Color, dashed: bool) -> void:
    var closed := contour.duplicate()
    closed.append(closed[0])
    draw_polyline(closed,Color(0,0,0,0.8),9.0,true)
    if not dashed:
        draw_polyline(closed,color,4.0,true)
    else:
        for i in range(closed.size()-1):
            draw_dashed_line(closed[i],closed[i+1],color,3.5,7.0,true,true)
func _draw() -> void:
    for contour in compression_contours:
        var center := Vector2.ZERO
        for point in contour: center += point
        center /= contour.size()
        var compressed := PackedVector2Array()
        for point in contour: compressed.append(center+(point-center)*(1.0-0.12*clampf(compression_time/0.12,0,1)))
        _outline(compressed,Color("ffffff"),false)
    for circle in blast_circles:
        draw_arc(Vector2(circle.x,circle.y),float(circle.radius),0,TAU,96,Color(1,0.72,0.3,0.35),1.5,true)
    for contour in extra_contours: _outline(contour,extra_color,true)
    for contour in direct_contours: _outline(contour,direct_color,false)
    for circle in bursts:
        var progress := clampf(burst_time/0.4,0,1)
        var center := Vector2(circle.x,circle.y)
        var radius := float(circle.radius)
        draw_circle(center,radius,Color(1,0.7,0.3,(1-progress)*0.15))
        draw_arc(center,radius * (0.75+0.25*progress),0,TAU,96,Color(1,0.83,0.5,1-progress),9*(1-progress)+1,true)
