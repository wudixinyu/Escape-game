## 主界面：牌桌 + HUD + 结算层。
##
## 它只做三件事：把 LevelData 铺成牌桌、把 LiberationEngine 的状态画出来、
## 把玩家的点击喂给引擎。规则全在 core/ 里，这里一行判定都没有。
##
extends Control

const CardScene := preload("res://ui/CardView.tscn")

## 排布只依赖两个东西：卡尺寸（ui/CardView.gd 里的 SIZE）和桌子的实际大小。
## 列数、行距、居中全在 _relayout() 里现算，改视口尺寸不用碰这些常量。
const GAP_X := 24.0
const GAP_Y := 32.0
## 引导行和手牌行之间多留一段，视觉上分成两条通道。
const ROW_GAP := 64.0
## 桌面内容离左右边缘的最小留白。
const INSET := 24.0

@onready var _level_label: Label = $"Shell/TopBar/LevelLabel"
@onready var _tags_label: Label = $"Shell/TopBar/Tags"
@onready var _stats: Label = $"Shell/TopBar/Stats"
@onready var _hint: Label = $"Shell/HintBar/Hint"
@onready var _table: Control = $"Shell/Table"
@onready var _restart: Button = $"Shell/BottomBar/Restart"
@onready var _home: Button = $"Shell/BottomBar/Home"
@onready var _prev: Button = $"Shell/BottomBar/Prev"
@onready var _next: Button = $"Shell/BottomBar/Next"
@onready var _levels: HBoxContainer = $"Shell/BottomBar/Levels"

var _engine: LiberationEngine
var _views: Dictionary = {}
var _guide_view: CardView = null
var _finished := false
var _result: PanelContainer = null
## 引导行当前的 y，_stops() 要用它，存在这里省得到处传参。
var _guide_y := 0.0


func _ready() -> void:
	_apply_theme()
	_build_level_buttons()

	_restart.pressed.connect(func() -> void: load_level(Game.index))
	_home.pressed.connect(func() -> void:
		get_tree().change_scene_to_file("res://Title.tscn")
	)
	_prev.pressed.connect(func() -> void: Game.goto(Game.index - 1))
	_next.pressed.connect(func() -> void: Game.goto(Game.index + 1))
	Game.level_changed.connect(load_level)
	_table.resized.connect(func() -> void: _relayout())

	load_level(Game.index)


# ---------------------------------------------------------------- 关卡装载

func load_level(_idx: int = 0) -> void:
	_clear_result()
	for c in _table.get_children():
		c.queue_free()
	_views.clear()
	_guide_view = null
	_finished = false

	var lv: LevelData = Game.current_level()
	if lv == null:
		return

	_engine = LiberationEngine.new()
	_engine.changed.connect(_sync)
	_engine.guide_moved.connect(_on_guide_moved)
	_engine.solved.connect(_on_solved)
	_engine.deadlocked.connect(_on_deadlocked)
	_engine.setup(lv)

	for c: CardData in lv.cards:
		var v := CardScene.instantiate() as CardView
		v.card_id = c.id
		v.display_name = c.display_name
		v.description = c.description
		v.role = c.kind
		_table.add_child(v)
		v.set_art(CardArt.for_card(c.id, c.art))
		v.clicked.connect(_on_card_clicked)
		_views[c.id] = v
		if c.id == lv.guide_id:
			_guide_view = v

	_relayout()
	_update_hud_labels(lv)
	_sync()


## 把牌铺成「引导行（可选）+ 手牌若干行」，整块内容在桌子里居中。
## 只认 CardView.SIZE，所以换视口、换卡尺寸都不用改这里。
func _relayout() -> void:
	var lv: LevelData = Game.current_level()
	if lv == null or _engine == null:
		return
	var csize := CardView.SIZE
	var cw := csize.x
	var ch := csize.y

	var guide: CardView = null
	var hand: Array[CardView] = []
	for c: CardData in lv.cards:
		var v: CardView = _views.get(c.id, null)
		if v == null:
			continue
		if c.id == lv.guide_id:
			guide = v
		else:
			hand.append(v)

	var cols := _columns(hand.size(), cw)
	var rows := maxi(1, ceili(float(hand.size()) / float(cols)))

	# 先算整块内容有多高，再决定第一行的 y，这样上下留白均匀。
	var head := (ch + ROW_GAP) if guide != null else 0.0
	var total := head + rows * ch + (rows - 1) * GAP_Y
	var top := maxf((_table.size.y - total) * 0.5, 0.0)

	_guide_y = top
	if guide != null:
		var stops := _stops(lv)
		guide.set_home(Vector2(stops[0].x, top), false)
		top += head

	for i in hand.size():
		var row := i / cols
		var n := mini(cols, hand.size() - row * cols)
		var row_w := n * cw + maxf(n - 1, 0) * GAP_X
		var x0 := (_table.size.x - row_w) * 0.5
		hand[i].set_home(Vector2(
			x0 + (i % cols) * (cw + GAP_X),
			top + row * (ch + GAP_Y)
		), false)


## 桌宽能放下几列就放几列，放不下才换行；至少一列，最多不超过牌数。
func _columns(count: int, card_w: float) -> int:
	if count <= 0:
		return 1
	var room := _table.size.x - 2.0 * INSET + GAP_X
	var fit := int(floorf(room / (card_w + GAP_X)))
	return clampi(maxi(fit, 1), 1, count)


## 迷途牌的落点。关卡里给了 guide_stops 就照它排（只取 x，y 交给布局），
## 没给就按桌宽自动均分铺一条横线，省得关卡数据里手写坐标。
func _stops(lv: LevelData) -> Array[Vector2]:
	var need := lv.guide_route.size() + 1
	if lv.guide_stops.size() >= need:
		var given: Array[Vector2] = []
		for p: Vector2 in lv.guide_stops:
			given.append(Vector2(p.x, _guide_y))
		return given
	var out: Array[Vector2] = []
	var span := maxf(_table.size.x - 2.0 * INSET - CardView.SIZE.x, 80.0)
	var step := span / float(maxi(need - 1, 1))
	var x0 := (_table.size.x - (span + CardView.SIZE.x)) * 0.5
	for k in range(need):
		out.append(Vector2(x0 + step * float(k), _guide_y))
	return out


# ---------------------------------------------------------------- 出牌

func _on_card_clicked(id: StringName) -> void:
	if _finished or _engine == null:
		return
	_engine.play(id)


func _on_guide_moved(index: int) -> void:
	var lv: LevelData = Game.current_level()
	var stops := _stops(lv)
	if _guide_view != null:
		_guide_view.set_home(stops[mini(index, stops.size() - 1)], true)


# ---------------------------------------------------------------- 状态同步

func _sync() -> void:
	var lv: LevelData = Game.current_level()
	if lv == null or _engine == null:
		return

	for c: CardData in lv.cards:
		var v: CardView = _views.get(c.id, null)
		if v == null:
			continue
		v.apply_state(_engine.state_of(c.id))

	if lv.goal == LevelData.Goal.GUIDE and _guide_view != null:
		_guide_view.set_progress(_engine.guide_index, lv.guide_route.size())

	_update_hud_labels(lv)


func _update_hud_labels(lv: LevelData) -> void:
	_level_label.text = "%s · %s" % [_goal_label(lv.goal), lv.title]
	_hint.text = lv.intro

	_stats.text = "步 0"
	_tags_label.text = ""
	if _engine == null:
		return

	var steps := "步 %d" % _engine.play_order.size()
	if lv.goal == LevelData.Goal.GUIDE:
		steps += " · 滞涩 %d / %d" % [_engine.missteps, lv.max_missteps]
	_stats.text = steps

	var t := _engine.tags()
	_tags_label.text = "在场：%s" % "、".join(PackedStringArray(t)) if not t.is_empty() else ""


func _goal_label(goal: LevelData.Goal) -> String:
	return AppTheme.goal_label(goal)


# ---------------------------------------------------------------- 收尾

func _on_solved(order: Array) -> void:
	_finished = true
	Game.mark_cleared(Game.index)

	var names: PackedStringArray = []
	for id: StringName in order:
		var c: CardData = _engine.card(id)
		names.append(c.display_name if c else String(id))

	_show_result(
		"解  脱",
		"出牌顺序：%s\n共 %d 步。" % [" → ".join(names), order.size()],
		true
	)


func _on_deadlocked(reason: String) -> void:
	_finished = true
	_show_result("卡  住  了", reason + "\n这一局走不通了，按顺序重来一次试试。", false)


# ---------------------------------------------------------------- 界面杂项

func _apply_theme() -> void:
	theme = AppTheme.base()


func _build_level_buttons() -> void:
	for c in _levels.get_children():
		c.queue_free()
	for i in Game.levels.size():
		var b := Button.new()
		b.text = str(i + 1)
		b.custom_minimum_size = Vector2(46, 0)
		var idx := i
		b.pressed.connect(func() -> void: Game.goto(idx))
		_levels.add_child(b)


func _clear_result() -> void:
	if _result != null:
		_result.queue_free()
		_result = null


func _show_result(title: String, body: String, ok: bool) -> void:
	_clear_result()

	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(
		Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE, 0
	)
	panel.custom_minimum_size = Vector2(640, 0)

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.10, 0.12, 0.17, 0.97)
	sb.set_corner_radius_all(20)
	sb.set_border_width_all(2)
	sb.border_color = Color(0.55, 0.72, 0.85, 0.8) if ok else Color(0.75, 0.45, 0.45, 0.8)
	sb.content_margin_left = 34
	sb.content_margin_right = 34
	sb.content_margin_top = 28
	sb.content_margin_bottom = 28
	panel.add_theme_stylebox_override("panel", sb)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	panel.add_child(box)

	var t := Label.new()
	t.text = title
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_size_override("font_size", 42)
	t.add_theme_color_override(
		"font_color",
		Color(0.72, 0.88, 0.95, 1) if ok else Color(0.92, 0.66, 0.66, 1)
	)
	box.add_child(t)

	var b := Label.new()
	b.text = body
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.add_theme_font_size_override("font_size", 19)
	box.add_child(b)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	box.add_child(row)

	var again := Button.new()
	again.text = "再来一次"
	again.pressed.connect(func() -> void: Game.goto(Game.index))
	row.add_child(again)

	if ok and Game.index + 1 < Game.levels.size():
		var nxt := Button.new()
		nxt.text = "下一关"
		nxt.pressed.connect(func() -> void: Game.goto(Game.index + 1))
		row.add_child(nxt)

	add_child(panel)
	_result = panel
