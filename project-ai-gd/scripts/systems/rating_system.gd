extends Node
class_name RatingSystem

enum CookingGrade { PERFECT, SUCCESS, NORMAL, FAIL }

const RATING_TABLE := {
	CookingGrade.PERFECT: {"rating": 5, "customer": 3, "gold": 30},
	CookingGrade.SUCCESS: {"rating": 3, "customer": 2, "gold": 20},
	CookingGrade.NORMAL: {"rating": 1, "customer": 1, "gold": 10},
	CookingGrade.FAIL: {"rating": -2, "customer": -1, "gold": 0},
}

const SYMPTOM_SUCCESS_BONUS := {"rating": 5, "customer": 3, "gold": 25}
const SYMPTOM_FAIL_PENALTY := {"rating": -3, "customer": -2, "gold": 0}
const TIMEOUT_PENALTY := {"rating": -1, "customer": -1, "gold": 0}
const DAILY_RECOMMENDATION_BONUS := 5

static var _history: Array[Dictionary] = []

static func get_grade_from_score(score: float) -> CookingGrade:
	if score >= 90.0:
		return CookingGrade.PERFECT
	elif score >= 70.0:
		return CookingGrade.SUCCESS
	elif score >= 40.0:
		return CookingGrade.NORMAL
	else:
		return CookingGrade.FAIL

static func get_grade_stars(grade: CookingGrade) -> int:
	match grade:
		CookingGrade.PERFECT: return 3
		CookingGrade.SUCCESS: return 2
		CookingGrade.NORMAL: return 1
		_: return 0

static func get_grade_name(grade: CookingGrade) -> String:
	match grade:
		CookingGrade.PERFECT: return "完美"
		CookingGrade.SUCCESS: return "成功"
		CookingGrade.NORMAL: return "一般"
		_: return "失败"

static func apply_cooking_result(grade: CookingGrade, is_daily_recommendation: bool = false) -> Dictionary:
	var rewards = RATING_TABLE[grade].duplicate()
	if is_daily_recommendation and grade != CookingGrade.FAIL:
		rewards["rating"] += DAILY_RECOMMENDATION_BONUS

	GameManager.add_rating(rewards["rating"])
	GameManager.customer_count += rewards["customer"]
	GameManager.add_gold(rewards["gold"])

	_history.append({
		"day": GameManager.day,
		"type": "cooking",
		"grade": grade,
		"rating_change": rewards["rating"],
		"gold_earned": rewards["gold"],
	})
	return rewards

static func apply_symptom_result(success: bool) -> Dictionary:
	var rewards: Dictionary
	if success:
		rewards = SYMPTOM_SUCCESS_BONUS.duplicate()
	else:
		rewards = SYMPTOM_FAIL_PENALTY.duplicate()

	GameManager.add_rating(rewards["rating"])
	GameManager.customer_count += rewards["customer"]
	GameManager.add_gold(rewards["gold"])

	_history.append({
		"day": GameManager.day,
		"type": "symptom",
		"success": success,
		"rating_change": rewards["rating"],
	})
	return rewards

static func apply_timeout_penalty() -> void:
	GameManager.add_rating(TIMEOUT_PENALTY["rating"])
	GameManager.customer_count += TIMEOUT_PENALTY["customer"]
	_history.append({
		"day": GameManager.day,
		"type": "timeout",
		"rating_change": TIMEOUT_PENALTY["rating"],
	})

static func get_history() -> Array[Dictionary]:
	return _history

static func get_history_for_day(day: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry in _history:
		if entry.get("day", 0) == day:
			result.append(entry)
	return result

static func clear_history() -> void:
	_history.clear()
