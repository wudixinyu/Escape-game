extends SceneTree

## 无头自检： Godot --headless --script res://tests/TestEngine.gd
##
## 跑两类东西：
##   逻辑 —— 每关有牌开局、参考解能通关、错序真的会死局；
##   UI   —— 立起来 Main.tscn，沿 _on_card_clicked 把三关各点一遍。
##
## 两个坑记在这里，下次别再踩：
##   1. GDScript 的 lambda 按值捕获，闭包里 solved = true 外面读不到，信号要用成员方法接。
##   2. add_child 只同步派 ENTER_TREE，READY 会塞进消息队列等下一帧。
##      无头下不跑帧就断言，「桌上没牌」。UI 那段必须 挂载 → 等一帧 → 再动手。

var _fail := 0
var _pass := 0
var _solved := false
var _dead := ""

## 用正常的成员方法接信号，别用 lambda。
func _on_solved(_order: Array) -> void:
	_solved = true


func _on_deadlocked(reason: String) -> void:
	_dead = reason


func _bind(e: LiberationEngine) -> void:
	e.solved.connect(_on_solved)
	e.deadlocked.connect(_on_deadlocked)


func _initialize() -> void:
	_run_async()


func _run_async() -> void:
	_run_logic()
	await process_frame
	## 一定要 await 住 _run_ui：它自己也会 await，
	## 而 GDScript 在 await 时会把控制权还给调用者，不接住就提前跑到总结去了。
	await _run_ui()
	print("\n---- 通过 %d 项，失败 %d 项 ----" % [_pass, _fail])
	quit(_fail)


# ---------------------------------------------------------------- 逻辑

func _run_logic() -> void:
	var library: Array[LevelData] = LevelLibrary.build()
	print("关卡数：%d" % library.size())

	for lv: LevelData in library:
		_check_opens_with_a_move(lv)
		_check_solution(lv)

	_check_release_recovers()
	_check_release_two_goals()
	_check_clear_deadlocks()
	_check_clear_untouchable()
	_check_guide_deadlocks()
	_check_guide_forgetful()


func _check_opens_with_a_move(lv: LevelData) -> void:
	var e := LiberationEngine.new()
	e.setup(lv)
	_expect(e.playable_ids().size() > 0, "%s｜开局无牌可出" % lv.title)


func _check_solution(lv: LevelData) -> void:
	_solved = false
	_dead = ""
	var e := LiberationEngine.new()
	_bind(e)
	e.setup(lv)

	for id: StringName in lv.solution:
		if not e.can_play(id):
			_expect(false, "%s｜参考解中途卡住：%s 不可用" % [lv.title, id])
			return
		e.play(id)

	_expect(_solved and _dead.is_empty(), "%s｜参考解没能通关（%s）" % [lv.title, _dead])


## 第一关：撕符之后再走正路，只要还有净露，就该能救回来。
func _check_release_recovers() -> void:
	_solved = false
	_dead = ""
	var e := LiberationEngine.new()
	_bind(e)
	e.setup(LevelLibrary._level_01())
	for id in ["talisman", "key", "chain", "oil", "light", "water"]:
		e.play(StringName(id))
	_expect(_solved, "释放型｜撕符后没有净露之外的补救路径（%s）" % _dead)


## 第四关：单向门。熄灯之前没把「形」送走，就再也送不走了。
func _check_release_two_goals() -> void:
	# 一上来先熄灯：「影」倒是走了，可超度的那条链子从此打不开。
	_solved = false
	_dead = ""
	var e := LiberationEngine.new()
	_bind(e)
	e.setup(LevelLibrary._level_04())
	for id in ["douse", "feel"]:
		e.play(StringName(id))
	_exhaust(e)
	_expect(_dead != "", "释放型·单向门｜先熄灯之后没有判出死局")
	_expect(not _solved, "释放型·单向门｜顺序反了居然也通关了")
	_expect(e.state_of(&"form") != LiberationEngine.State.LIBERATED,
		"释放型·单向门｜没来得及超度，「形」却解脱了")
	_expect(e.state_of(&"shadow") == LiberationEngine.State.LIBERATED,
		"释放型·单向门｜熄了灯却没能摸到「影」")

	# 照见了但还没超度就熄灯，一样救不回来。
	_solved = false
	_dead = ""
	var e2 := LiberationEngine.new()
	_bind(e2)
	e2.setup(LevelLibrary._level_04())
	for id in ["wax", "see", "douse", "rite", "feel"]:
		if e2.can_play(StringName(id)):
			e2.play(StringName(id))
	_exhaust(e2)
	_expect(_dead != "", "释放型·单向门｜超度一半就熄灯，却没判死局")
	_expect(not _solved, "释放型·单向门｜半途熄灯居然通关了")


## 把还能出的牌一路出到底，用来引出迟到的死局判定。
## 死局要等到「没有牌可出」那一刻才判，中途就断言会假阴性。
func _exhaust(e: LiberationEngine) -> void:
	for _i in range(64):
		var ids := e.playable_ids()
		if ids.is_empty():
			return
		e.play(ids[0])


## 第五关：那张点不到的牌，全程没被打出也应该自己散去；搅过一下也要救得回来。
func _check_clear_untouchable() -> void:
	_solved = false
	_dead = ""
	var e := LiberationEngine.new()
	_bind(e)
	e.setup(LevelLibrary._level_05())
	for id in ["brush", "pour", "cloth", "sit"]:
		if e.can_play(StringName(id)):
			e.play(StringName(id))
	_expect(_solved, "清除型·不可触碰｜参考解没通关（%s）" % _dead)
	_expect(not e.play_order.has(&"curse"), "清除型·不可触碰｜妄念居然被打出去了")
	_expect(e.state_of(&"curse") == LiberationEngine.State.LIBERATED,
		"清除型·不可触碰｜妄念没有被自动解脱")

	_solved = false
	_dead = ""
	var e2 := LiberationEngine.new()
	_bind(e2)
	e2.setup(LevelLibrary._level_05())
	for id in ["stir", "brush", "pour", "cloth", "settle", "sit"]:
		if e2.can_play(StringName(id)):
			e2.play(StringName(id))
	_expect(_solved, "清除型·不可触碰｜搅过之后没能补救回来（%s）" % _dead)


## 第六关：喝过忘川还能认回来，但两步滞涩正好把容错用光。
func _check_guide_forgetful() -> void:
	_solved = false
	_dead = ""
	var e := LiberationEngine.new()
	_bind(e)
	e.setup(LevelLibrary._level_06())
	for id in ["call", "know", "forget", "fare", "recall", "ferry"]:
		if e.can_play(StringName(id)):
			e.play(StringName(id))
	_expect(_solved, "接引型·忘川｜重新相认之后没能通关（%s）" % _dead)
	_expect(e.missteps == 2, "接引型·忘川｜补救路线的滞涩数不对：%d" % e.missteps)


## 第二关：净露被白白用掉，再点上怒火，就该走进死局。
func _check_clear_deadlocks() -> void:
	_solved = false
	_dead = ""
	var e := LiberationEngine.new()
	_bind(e)
	e.setup(LevelLibrary._level_02())
	for id in ["still", "anger", "watch", "regret", "forgive", "letgo", "grasp"]:
		e.play(StringName(id))
	_expect(not _dead.is_empty(), "清除型｜错序之后没有判出死局")
	_expect(not _solved, "清除型｜错序居然也通关了")


## 第三关：连着三张不相干的牌，滞涩超过上限就该失败。
func _check_guide_deadlocks() -> void:
	_solved = false
	_dead = ""
	var e := LiberationEngine.new()
	_bind(e)
	e.setup(LevelLibrary._level_03())
	for id in ["coin", "mirror", "flame"]:
		e.play(StringName(id))
	_expect(not _dead.is_empty(), "接引型｜滞涩过多没有判出死局")
	_expect(e.guide_index == 0, "接引型｜不相干的牌居然推进了迷魂")


# ---------------------------------------------------------------- UI

func _run_ui() -> void:
	if root == null or not root.has_node("Game"):
		print("[SKIP] autoLoad 没挂上，跳过 UI 检查")
		return

	var game := root.get_node("Game")
	var packed := load("res://Main.tscn") as PackedScene
	_expect(packed != null, "Main.tscn 没能加载")
	if packed == null:
		return

	var main := packed.instantiate()
	root.add_child(main)
	await process_frame

	_expect(main.get_node("Shell/Table").get_child_count() > 0, "Main 起来之后桌上是空的")

	for i in game.levels.size():
		game.goto(i)
		var lv: LevelData = game.levels[i]
		for id: StringName in lv.solution:
			main._on_card_clicked(id)
		_expect(bool(main._finished), "%s｜沿 UI 点完参考解没有收尾" % lv.title)

	main.free()


# ----------------------------------------------------------------

func _expect(ok: bool, message: String) -> void:
	if ok:
		_pass += 1
		return
	_fail += 1
	print("[FAIL] %s" % message)
