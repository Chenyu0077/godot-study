extends Node

var _pass_count: int = 0
var _fail_count: int = 0
var _results: Array[String] = []

func _ready() -> void:
	print("===== 开始系统测试 =====")
	test_cooking_system()
	test_rating_system()
	test_save_system()
	test_recipe_manager()
	test_unlock_thresholds()
	print("===== 测试完成 =====")
	print("通过: %d | 失败: %d" % [_pass_count, _fail_count])
	for r in _results:
		print(r)

func assert_eq(actual, expected, desc: String) -> void:
	if actual == expected:
		_pass_count += 1
	else:
		_fail_count += 1
		_results.append("FAIL: %s (期望: %s, 实际: %s)" % [desc, str(expected), str(actual)])

func assert_true(condition: bool, desc: String) -> void:
	if condition:
		_pass_count += 1
	else:
		_fail_count += 1
		_results.append("FAIL: %s" % desc)

func assert_range(value: float, min_val: float, max_val: float, desc: String) -> void:
	if value >= min_val and value <= max_val:
		_pass_count += 1
	else:
		_fail_count += 1
		_results.append("FAIL: %s (值: %.2f, 范围: %.2f~%.2f)" % [desc, value, min_val, max_val])

# ===== 烹饪系统测试 =====
func test_cooking_system() -> void:
	print("--- 烹饪系统测试 ---")
	var cs = CookingSystem.new()
	add_child(cs)

	# 测试评级计算
	assert_eq(
		RatingSystem.get_grade_from_score(95.0),
		RatingSystem.CookingGrade.PERFECT,
		"95分应为完美"
	)
	assert_eq(
		RatingSystem.get_grade_from_score(75.0),
		RatingSystem.CookingGrade.SUCCESS,
		"75分应为成功"
	)
	assert_eq(
		RatingSystem.get_grade_from_score(50.0),
		RatingSystem.CookingGrade.NORMAL,
		"50分应为一般"
	)
	assert_eq(
		RatingSystem.get_grade_from_score(30.0),
		RatingSystem.CookingGrade.FAIL,
		"30分应为失败"
	)

	# 边界值测试
	assert_eq(
		RatingSystem.get_grade_from_score(90.0),
		RatingSystem.CookingGrade.PERFECT,
		"90分边界应为完美"
	)
	assert_eq(
		RatingSystem.get_grade_from_score(89.9),
		RatingSystem.CookingGrade.SUCCESS,
		"89.9分应为成功"
	)
	assert_eq(
		RatingSystem.get_grade_from_score(70.0),
		RatingSystem.CookingGrade.SUCCESS,
		"70分边界应为成功"
	)
	assert_eq(
		RatingSystem.get_grade_from_score(40.0),
		RatingSystem.CookingGrade.NORMAL,
		"40分边界应为一般"
	)
	assert_eq(
		RatingSystem.get_grade_from_score(39.9),
		RatingSystem.CookingGrade.FAIL,
		"39.9分应为失败"
	)

	# 区域判定测试
	var recipe = {
		"steps": [
			{"step_name": "test", "needle_speed": 1.5, "perfect_zone_size": 0.25, "time_limit": 5.0}
		]
	}
	cs.start_cooking(recipe)
	# 指针初始在 -90 度（最左），属于错误区
	cs.hit()
	assert_eq(cs._step_scores[0], 0.0, "最左边点击应为0分（错误区）")

	cs.remove_child(cs)
	cs.queue_free()

# ===== 评价系统测试 =====
func test_rating_system() -> void:
	print("--- 评价系统测试 ---")

	# 保存原始状态
	var orig_rating = GameManager.rating
	var orig_gold = GameManager.gold
	var orig_count = GameManager.customer_count

	# 测试完美评价
	GameManager.rating = 0
	GameManager.gold = 0
	GameManager.customer_count = 5
	var rewards = RatingSystem.apply_cooking_result(RatingSystem.CookingGrade.PERFECT, false)
	assert_eq(rewards["rating"], 5, "完美评价+5")
	assert_eq(rewards["gold"], 30, "完美金币+30")
	assert_eq(GameManager.rating, 5, "GameManager评价应为5")

	# 测试每日推荐加成
	GameManager.rating = 0
	var rewards2 = RatingSystem.apply_cooking_result(RatingSystem.CookingGrade.SUCCESS, true)
	assert_eq(rewards2["rating"], 3 + 5, "每日推荐成功应+8(3+5)")

	# 测试失败不加推荐加成
	GameManager.rating = 10
	var rewards3 = RatingSystem.apply_cooking_result(RatingSystem.CookingGrade.FAIL, true)
	assert_eq(rewards3["rating"], -2, "失败不应有推荐加成")
	assert_eq(GameManager.rating, 8, "评价10-2=8")

	# 测试评价不低于0
	GameManager.rating = 1
	RatingSystem.apply_cooking_result(RatingSystem.CookingGrade.FAIL, false)
	assert_true(GameManager.rating >= 0, "评价不应低于0")

	# 测试症状对症结果
	GameManager.rating = 0
	GameManager.gold = 0
	var sym_rewards = RatingSystem.apply_symptom_result(true)
	assert_eq(sym_rewards["rating"], 5, "对症成功评价+5")
	assert_eq(sym_rewards["gold"], 25, "对症成功金币+25")

	# 测试历史记录
	var history = RatingSystem.get_history()
	assert_true(history.size() > 0, "历史记录不应为空")

	# 恢复
	GameManager.rating = orig_rating
	GameManager.gold = orig_gold
	GameManager.customer_count = orig_count
	RatingSystem.clear_history()

# ===== 存档系统测试 =====
func test_save_system() -> void:
	print("--- 存档系统测试 ---")

	# 保存原始状态
	var orig_data = GameManager.get_save_data()

	# 设置测试数据
	GameManager.rating = 42
	GameManager.gold = 100
	GameManager.day = 7
	GameManager.unlocked_recipes = ["goji_porridge", "chrysanthemum_tea"]
	GameManager.inventory = {"goji_berry": 3, "rice": 5}

	# 存档
	SaveManager.save_game()
	assert_true(SaveManager.has_save(), "存档文件应存在")

	# 修改状态
	GameManager.rating = 0
	GameManager.gold = 0
	GameManager.day = 1
	GameManager.unlocked_recipes = []
	GameManager.inventory = {}

	# 读档
	var loaded = SaveManager.load_game()
	assert_true(loaded, "读档应成功")
	assert_eq(GameManager.rating, 42, "读档后评价应为42")
	assert_eq(GameManager.gold, 100, "读档后金币应为100")
	assert_eq(GameManager.day, 7, "读档后天数应为7")
	assert_true(GameManager.unlocked_recipes.size() == 2, "读档后解锁食谱应为2个")
	assert_eq(GameManager.inventory.get("goji_berry", 0), 3, "读档后枸杞应为3")

	# 恢复
	GameManager.load_save_data(orig_data)

# ===== 食谱管理器测试 =====
func test_recipe_manager() -> void:
	print("--- 食谱管理器测试 ---")

	var all = RecipeManager.get_all_recipes()
	assert_true(all.size() >= 9, "应有至少9道菜谱")

	var goji = RecipeManager.get_recipe("goji_porridge")
	assert_eq(goji["name"], "枸杞粥", "枸杞粥名称正确")
	assert_true(goji.has("steps"), "菜谱应有steps字段")
	assert_true(goji["steps"].size() >= 2, "枸杞粥应有至少2步")

	var empty = RecipeManager.get_recipe("nonexistent")
	assert_true(empty.is_empty(), "不存在的菜谱应返回空字典")

	var symptoms = RecipeManager.get_all_symptoms()
	assert_eq(symptoms.size(), 6, "应有6种症状")

	var headache_recipes = RecipeManager.get_recipes_for_symptom("headache")
	assert_true(headache_recipes.size() > 0, "头痛应有推荐菜谱")

	var is_match = RecipeManager.is_recipe_for_symptom("chrysanthemum_tea", "headache")
	assert_true(is_match, "菊花茶应对症头痛")

	var not_match = RecipeManager.is_recipe_for_symptom("goji_porridge", "headache")
	assert_true(not not_match, "枸杞粥不应对症头痛")

# ===== 解锁阈值测试 =====
func test_unlock_thresholds() -> void:
	print("--- 解锁阈值测试 ---")

	var orig_rating = GameManager.rating
	var orig_recipes = GameManager.unlocked_recipes.duplicate()

	# 重置
	GameManager.rating = 0
	GameManager._init_default_unlocks()
	var default_count = GameManager.unlocked_recipes.size()

	# 评价达到20应解锁 rating_20 菜谱
	GameManager.rating = 0
	GameManager.add_rating(20)
	assert_true(
		GameManager.unlocked_recipes.size() > default_count,
		"评价达到20应解锁新菜谱"
	)

	# 评价达到19不应解锁
	GameManager._init_default_unlocks()
	GameManager.rating = 0
	GameManager.add_rating(19)
	assert_eq(
		GameManager.unlocked_recipes.size(), default_count,
		"评价19不应解锁新菜谱"
	)

	# 恢复
	GameManager.rating = orig_rating
	GameManager.unlocked_recipes = orig_recipes
