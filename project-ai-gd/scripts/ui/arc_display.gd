extends Control

const ARC_RADIUS := 150.0
const ARC_THICKNESS := 20.0
const NEEDLE_LENGTH := 170.0
const ARC_START_ANGLE := PI
const ARC_END_ANGLE := 0.0

var _cooking_ui: Control

func _ready() -> void:
	_cooking_ui = get_parent().get_parent()

func _draw() -> void:
	var center = Vector2(size.x / 2.0, size.y - 20.0)
	var perfect_size = 0.25
	var needle_angle_deg = 0.0

	if _cooking_ui and _cooking_ui.has_method("get_perfect_zone_size"):
		perfect_size = _cooking_ui.get_perfect_zone_size()
	if _cooking_ui and _cooking_ui.has_method("get_needle_angle"):
		needle_angle_deg = _cooking_ui.get_needle_angle()

	var perfect_half = perfect_size / 2.0
	var good_half = perfect_half + 0.15
	var normal_half = good_half + 0.2

	_draw_arc_zone(center, normal_half, 1.0, Color(0.8, 0.2, 0.2, 0.6))
	_draw_arc_zone(center, good_half, normal_half, Color(0.5, 0.5, 0.5, 0.6))
	_draw_arc_zone(center, perfect_half, good_half, Color(0.9, 0.6, 0.1, 0.7))
	_draw_arc_zone(center, 0.0, perfect_half, Color(1.0, 0.85, 0.0, 0.9))

	_draw_arc_outline(center)

	var needle_rad = deg_to_rad(needle_angle_deg - 90.0)
	var needle_end = center + Vector2(cos(needle_rad), sin(needle_rad)) * NEEDLE_LENGTH
	draw_line(center, needle_end, Color.WHITE, 3.0, true)
	draw_circle(center, 6.0, Color.WHITE)

func _draw_arc_zone(center: Vector2, from_norm: float, to_norm: float, color: Color) -> void:
	var from_angle_left = PI / 2.0 + from_norm * (PI / 2.0)
	var to_angle_left = PI / 2.0 + to_norm * (PI / 2.0)
	var from_angle_right = PI / 2.0 - to_norm * (PI / 2.0)
	var to_angle_right = PI / 2.0 - from_norm * (PI / 2.0)

	_draw_thick_arc(center, ARC_RADIUS, PI - to_angle_left, PI - from_angle_left, color)
	_draw_thick_arc(center, ARC_RADIUS, PI - to_angle_right, PI - from_angle_right, color)

func _draw_thick_arc(center: Vector2, radius: float, start_angle: float, end_angle: float, color: Color) -> void:
	var point_count = 32
	if end_angle <= start_angle:
		return
	var inner_points := PackedVector2Array()
	var outer_points := PackedVector2Array()
	for i in range(point_count + 1):
		var t = float(i) / point_count
		var angle = start_angle + t * (end_angle - start_angle)
		var dir = Vector2(cos(angle), sin(angle))
		inner_points.append(center + dir * (radius - ARC_THICKNESS / 2.0))
		outer_points.append(center + dir * (radius + ARC_THICKNESS / 2.0))

	var polygon := PackedVector2Array()
	polygon.append_array(inner_points)
	var reversed_outer := PackedVector2Array()
	for i in range(outer_points.size() - 1, -1, -1):
		reversed_outer.append(outer_points[i])
	polygon.append_array(reversed_outer)

	if polygon.size() >= 3:
		draw_colored_polygon(polygon, color)

func _draw_arc_outline(center: Vector2) -> void:
	var point_count = 64
	var points := PackedVector2Array()
	for i in range(point_count + 1):
		var t = float(i) / point_count
		var angle = PI + t * (-PI)
		points.append(center + Vector2(cos(angle), sin(angle)) * (ARC_RADIUS + ARC_THICKNESS / 2.0))
	draw_polyline(points, Color(0.3, 0.3, 0.3, 0.8), 2.0, true)

	points.clear()
	for i in range(point_count + 1):
		var t = float(i) / point_count
		var angle = PI + t * (-PI)
		points.append(center + Vector2(cos(angle), sin(angle)) * (ARC_RADIUS - ARC_THICKNESS / 2.0))
	draw_polyline(points, Color(0.3, 0.3, 0.3, 0.8), 2.0, true)
