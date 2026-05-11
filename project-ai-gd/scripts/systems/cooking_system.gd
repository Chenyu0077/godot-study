extends Node
class_name CookingSystem

signal step_started(step_index: int, step_data: Dictionary)
signal step_completed(step_index: int, score: float, zone: String)
signal cooking_complete(total_score: float, grade: int)
signal time_warning(remaining: float)

enum Zone { PERFECT, GOOD, NORMAL, MISS }

const ZONE_SCORES := {
	Zone.PERFECT: 100.0,
	Zone.GOOD: 70.0,
	Zone.NORMAL: 40.0,
	Zone.MISS: 0.0,
}

const ZONE_NAMES := {
	Zone.PERFECT: "完美",
	Zone.GOOD: "良好",
	Zone.NORMAL: "一般",
	Zone.MISS: "失误",
}

var _recipe: Dictionary = {}
var _steps: Array = []
var _current_step_index: int = 0
var _step_scores: Array[float] = []

var _needle_angle: float = 0.0
var _needle_direction: float = 1.0
var _needle_speed: float = 1.5
var _perfect_zone_size: float = 0.25

var _time_remaining: float = 5.0
var _is_active: bool = false
var _step_in_progress: bool = false

const ARC_MIN_ANGLE := -90.0
const ARC_MAX_ANGLE := 90.0

func start_cooking(recipe: Dictionary) -> void:
	_recipe = recipe
	_steps = recipe.get("steps", [])
	_current_step_index = 0
	_step_scores.clear()
	_is_active = true
	_start_current_step()

func _start_current_step() -> void:
	if _current_step_index >= _steps.size():
		_finish_cooking()
		return

	var step = _steps[_current_step_index]
	_needle_speed = step.get("needle_speed", 1.5)
	_perfect_zone_size = step.get("perfect_zone_size", 0.25)
	_time_remaining = step.get("time_limit", 5.0)
	_needle_angle = ARC_MIN_ANGLE
	_needle_direction = 1.0
	_step_in_progress = true
	step_started.emit(_current_step_index, step)

func _process(delta: float) -> void:
	if not _is_active or not _step_in_progress:
		return

	var speed_degrees = _needle_speed * 180.0
	_needle_angle += _needle_direction * speed_degrees * delta
	if _needle_angle >= ARC_MAX_ANGLE:
		_needle_angle = ARC_MAX_ANGLE
		_needle_direction = -1.0
	elif _needle_angle <= ARC_MIN_ANGLE:
		_needle_angle = ARC_MIN_ANGLE
		_needle_direction = 1.0

	_time_remaining -= delta
	if _time_remaining <= 3.0 and _time_remaining > 0:
		time_warning.emit(_time_remaining)
	if _time_remaining <= 0:
		_on_timeout()

func hit() -> void:
	if not _is_active or not _step_in_progress:
		return
	_step_in_progress = false
	var zone = _get_zone_at_angle(_needle_angle)
	var score = ZONE_SCORES[zone]
	_step_scores.append(score)
	step_completed.emit(_current_step_index, score, ZONE_NAMES[zone])
	_current_step_index += 1

func proceed_to_next_step() -> void:
	_start_current_step()

func _on_timeout() -> void:
	_step_in_progress = false
	_step_scores.append(0.0)
	step_completed.emit(_current_step_index, 0.0, "超时")
	_current_step_index += 1
	_auto_proceed_after_delay()

func _auto_proceed_after_delay() -> void:
	await get_tree().create_timer(1.0).timeout
	if _is_active:
		_start_current_step()

func _get_zone_at_angle(angle: float) -> Zone:
	var normalized = abs(angle) / ARC_MAX_ANGLE

	var perfect_half = _perfect_zone_size / 2.0
	var good_half = perfect_half + 0.15
	var normal_half = good_half + 0.2

	if normalized <= perfect_half:
		return Zone.PERFECT
	elif normalized <= good_half:
		return Zone.GOOD
	elif normalized <= normal_half:
		return Zone.NORMAL
	else:
		return Zone.MISS

func _finish_cooking() -> void:
	_is_active = false
	var total = get_total_score()
	var grade = RatingSystem.get_grade_from_score(total)
	cooking_complete.emit(total, grade)

func get_total_score() -> float:
	if _step_scores.is_empty():
		return 0.0
	var sum := 0.0
	for s in _step_scores:
		sum += s
	return sum / _step_scores.size()

func get_needle_angle() -> float:
	return _needle_angle

func get_needle_normalized() -> float:
	return _needle_angle / ARC_MAX_ANGLE

func get_time_remaining() -> float:
	return _time_remaining

func is_active() -> bool:
	return _is_active

func get_current_step_name() -> String:
	if _current_step_index < _steps.size():
		return _steps[_current_step_index].get("step_name", "")
	return ""

func get_step_count() -> int:
	return _steps.size()

func get_current_step_index() -> int:
	return _current_step_index

func get_perfect_zone_size() -> float:
	return _perfect_zone_size
