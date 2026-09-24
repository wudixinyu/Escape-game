## 「解脱」规则引擎 —— 纯逻辑，不碰任何节点。
##
## 一局的过程就是一句话：出一张牌 → 结算标记 → 反复推进状态 → 判定胜负。
## UI 只需要监听 changed / guide_moved / solved / deadlocked 四个信号。
##
class_name LiberationEngine
extends RefCounted

## 一张牌在一局里的四种处境。
enum State {
	SEALED,    ## 封印：条件未满足，点不动
	OPEN,      ## 可出：点击即出
	PLAYED,    ## 已出：留在桌上作记录，变灰
	LIBERATED, ## 解脱：满足条件，从桌上消失
}

## 任何一次状态变化后发出，UI 做一次全量同步即可。
signal changed()
## 迷途牌前进了一站。
signal guide_moved(index: int)
## 通关。order 是出牌顺序。
signal solved(order: Array)
## 死局：没有牌可出，或者接引步数耗尽。必须重来。
signal deadlocked(reason: String)

var level: LevelData

var play_order: Array[StringName] = []
var missteps: int = 0
var guide_index: int = 0

var _state: Dictionary = {}    ## StringName -> State
var _tags: Dictionary = {}     ## StringName -> int（计数，支持同一标记多次投放）
var _by_id: Dictionary = {}    ## StringName -> CardData


# ---------------------------------------------------------------- 生命周期

func setup(data: LevelData) -> void:
	level = data
	restart()


func restart() -> void:
	_state.clear()
	_tags.clear()
	_by_id.clear()
	play_order.clear()
	missteps = 0
	guide_index = 0

	for c: CardData in level.cards:
		_by_id[c.id] = c
		_state[c.id] = State.OPEN if c.starting else State.SEALED

	_settle()
	changed.emit()


# ---------------------------------------------------------------- 查询

func card(id: StringName) -> CardData:
	return _by_id.get(id, null) as CardData


func state_of(id: StringName) -> State:
	return _state.get(id, State.SEALED) as State


func playable_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for c: CardData in level.cards:
		if state_of(c.id) == State.OPEN:
			out.append(c.id)
	return out


## 当前在场的所有标记，用于 HUD 显示。
func tags() -> Array[StringName]:
	var out: Array[StringName] = []
	for k: StringName in _tags.keys():
		if int(_tags[k]) > 0:
			out.append(k)
	return out


func is_solved() -> bool:
	match level.goal:
		LevelData.Goal.RELEASE:
			for gid: StringName in level.goal_ids:
				if state_of(gid) != State.LIBERATED:
					return false
			return true

		LevelData.Goal.CLEAR:
			for c: CardData in level.cards:
				if c.id == level.guide_id:
					continue
				if state_of(c.id) != State.LIBERATED:
					return false
			return true

		LevelData.Goal.GUIDE:
			return guide_index >= level.guide_route.size()
	return false


# ---------------------------------------------------------------- 出牌

func can_play(id: StringName) -> bool:
	return state_of(id) == State.OPEN


func play(id: StringName) -> bool:
	if level == null or not can_play(id):
		return false

	var c := card(id)

	_state[id] = State.PLAYED
	play_order.append(id)

	# 投放标记：自身 id 自动成为一枚标记，这样 requires 里可以直接写卡 id。
	_add_tag(id)
	for t: StringName in c.grants:
		_add_tag(t)
	for t: StringName in c.clears:
		_remove_tag(t)

	_advance_guide(c)
	_settle()
	_judge()

	changed.emit()
	return true


# ---------------------------------------------------------------- 内部

func _add_tag(t: StringName) -> void:
	_tags[t] = int(_tags.get(t, 0)) + 1


func _remove_tag(t: StringName) -> void:
	_tags[t] = 0


## 这些标记是否全部在场。空数组视为成立。
func _met(list: Array[StringName]) -> bool:
	for t: StringName in list:
		if int(_tags.get(t, 0)) <= 0:
			return false
	return true


## 这些标记是否有任意一个在场。空数组视为不成立。
func _met_any(list: Array[StringName]) -> bool:
	for t: StringName in list:
		if int(_tags.get(t, 0)) > 0:
			return true
	return false


## 反复推进，直到没有牌的状态再发生变化为止。
## 因为是循环跑，所以「最后一张牌自己也散去」这种写法可以成立。
func _settle() -> void:
	var dirty := true
	while dirty:
		dirty = false
		for c: CardData in level.cards:
			var st := state_of(c.id)
			if st == State.LIBERATED:
				continue

			if st == State.SEALED and _met(c.requires):
				_state[c.id] = State.OPEN
				dirty = true

			if _can_liberate(c):
				_state[c.id] = State.LIBERATED
				dirty = true


func _can_liberate(c: CardData) -> bool:
	if c.liberated_by.is_empty():
		return false
	if _met_any(c.blocked_by):
		return false
	return _met(c.liberated_by)


func _advance_guide(c: CardData) -> void:
	if level.goal != LevelData.Goal.GUIDE:
		return
	if guide_index >= level.guide_route.size():
		return

	var need: StringName = level.guide_route[guide_index]
	if need == c.id or c.grants.has(need):
		guide_index += 1
		guide_moved.emit(guide_index)
	else:
		missteps += 1


func _judge() -> void:
	if is_solved():
		solved.emit(play_order.duplicate())
		return

	if level.goal == LevelData.Goal.GUIDE and missteps > level.max_missteps:
		deadlocked.emit("滞涩太深，迷魂散回了雾里。")
		return

	if playable_ids().is_empty():
		deadlocked.emit("再没有可以出的牌了。")
